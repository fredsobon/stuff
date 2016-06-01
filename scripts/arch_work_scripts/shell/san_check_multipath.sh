#!/bin/sh
# vim: sw=4 ts=4
#
# Authors: David Larquey <d.larquey@pixmania-group.com>
#      and Maxime Guillet <m.guillet@pixmania-group.com>
#
# Last Updated by:
#      Maxime Guillet - Mon, 26 Nov 2012 16:02:33 +0100

#multipathd show maps format "%n %w %N %F %t %0 %1"
#name          uuid                              paths failback  dm-st  path_faults switch_grp
#orappl1p_fra  3600144f0c9ae9088000050a9fdb40078 2     immediate active 0           0         
#orappl1p_ctl  3600144f0c9ae9088000050a9fdb30077 2     immediate active 0           0   

#multipathd show maps format "%n %w %N %F %t %0 %1"
#name          uuid                              paths failback  dm-st  path_faults switch_grp
#orappl1p_fra  3600144f0c9ae9088000050a9fdb40078 2     immediate active 0           0         
#orappl1p_ctl  3600144f0c9ae9088000050a9fdb30077 2     immediate active 0           0    


# Revisions
# 2012-11-26    dlarquey/mguillet   Initial build
# 2012-12-10    dlarquey        Add the check of the iscsi sessions state (Must be in LOGGED_IN state, else an error occurs)
# 2012-12-17    dlarquey        Fix bug : for each map, nr_paths is compared to the number of iscsi sessions per target instead of the total number of active iscsi sessions
# 2012-12-19    dlarquey        Add the check for the number of HBAs and the number of expected iscsi sessions per target (See parameters -H hba,-S sessions_per_target_per_hba)
# 2013-09-30	dlarquey	Change the test for detecting HBAs. Add the variable SAN_VLANS


# Used to count the number of HBAs by filtering with the SAN VLAN. Adapt to your needs.
SAN_VLANS='10\.[1|3]\.115\.'


# Functions
myexit() {
    [ -f $mp_temp_file ] && rm -f $mp_temp_file
}


usage() {
    cat <<EOS
$(basename $0) - Check device multipaths

SYNTAX

$(basename $0) [-f] [-h] [{-g|-n|-s} [-H H] [-S S] OID [VALUE]]

    -f  Print only maps that have at least one path on failure
    -h  This help
    -g  get SNMP value
    -n  get next SNMP value
    -s  set SNMP value
    -H  Number of expected HBA
    -S  Number of expected iSCSI sessions per target per HBA

The total number of expected iscsi sessions per target is: H*S

EOS
}

###### SNMP functions ######

snmp_get() {
    case "$1" in
        0)
            echo "$BASEOID.$1"
            echo 'INTEGER'
            echo "$CHECK_STATUS"
            ;;
        1)
            echo "$BASEOID.$1"
            echo 'STRING'
            echo "$CHECK_MSG"
            ;;
    esac
}

######


###### Check functions ######

# Return check functions
set_return() {
    CHECK_STATUS=$1
    CHECK_MSG="$2"
}

check_nr_path() {
    local paths=$1
    if [ "${paths}" -lt "${nr_sessions_expected}" ]; then
        [ "${paths}" -le 1 ] && return 2
        return 1
    fi
    return 0
}

check_aggr_return() {
    check_status=$1
    check_msg="$2"
    if [ ${check_status} -ge $CHECK_STATUS ]; then
        [ -n "$CHECK_MSG" ] && CHECK_MSG="${check_msg} - ${CHECK_MSG}" || CHECK_MSG="${check_msg}"
        CHECK_STATUS=${check_status}
    else
        [ -n "$CHECK_MSG" ] && CHECK_MSG="${CHECK_MSG} - ${check_msg}" || CHECK_MSG="${check_msg}"
    fi
}

# Main check function
function docheck() {
    CHECK_STATUS=0
    [ -d /sys/class/iscsi_session ] || { set_return 0 "OK" && return; }

#    nr_hbas=$(lspci|grep -i iscsi|wc -l)
    nr_hbas=$(ip addr|grep $SAN_VLANS|wc -l)
    nr_sessions=$(ls -ld /sys/class/iscsi_session/session*/device/target* 2>/dev/null|wc -l)
    nr_active_sessions=$(cat /sys/class/iscsi_session/session*/state|grep "LOGGED_IN"|wc -l)
    nr_targets=$(cat /sys/class/iscsi_session/session*/targetname|sort|uniq|wc -l)
    nr_sessions_per_target=${nr_active_sessions}

    [ ${nr_targets} -gt 0 ] && nr_sessions_per_target=$((${nr_active_sessions}/${nr_targets}))

    # Fix the expected number of iscsi sessions
    nr_sessions_expected=${nr_sessions_per_target}
    [ $NR_SESSIONS_PER_TARGET_PER_HBA -gt 0 -a $NR_HBAS -gt 0 ] && nr_sessions_expected=$(($NR_SESSIONS_PER_TARGET_PER_HBA*$NR_HBAS))

    [ ${nr_hbas} -eq 0 ] && { set_return 2 "No available iSCSI HBAs" && return; }
    [ ${nr_active_sessions} -eq 0 ] && { set_return 2 "No available iSCSI sessions" && return; }
    [ ${nr_targets} -eq 0 ] && { set_return 2 "No available iSCSI targets" && return; }
    
    [ ${nr_sessions} -gt ${nr_active_sessions} ] && check_aggr_return 1 "It seems to have inactive iSCSI sessions ($(($nr_sessions - $nr_active_sessions)) inactives sessions)"
    
    # Check the number of HBAs
    [ $NR_HBAS -gt 0  ] && [ ${nr_hbas} -lt $NR_HBAS ] && check_aggr_return 1 "Only ${nr_hbas} HBAs are present while it's expected to have $NR_HBAS"
    
    # Check the number of iscsi sessions per target per hba

    [ $NR_SESSIONS_PER_TARGET_PER_HBA -gt 0 -a $NR_HBAS -gt 0 ] && [ ${nr_sessions_per_target} -ne $(($NR_SESSIONS_PER_TARGET_PER_HBA*$NR_HBAS)) ] && check_aggr_return 1 "Wrong number of iSCSI sessions per target : ${nr_sessions_per_target} while it's expected to have $(($NR_SESSIONS_PER_TARGET_PER_HBA*$NR_HBAS))"
    
    # Get the number of paths for each SAN volume using multipathd
    pgrep -x multipathd >/dev/null || { set_return 2 "multipathd daemon is not started" && return; }
    [ "$(id -u)" -ne 0 ] && MULTIPATHD_CMD='sudo multipathd' || MULTIPATHD_CMD='multipathd'
    $MULTIPATHD_CMD show maps format "%n %w %N %F %t %0 %1" | tail -n +2 | sort >$mp_temp_file
    
#    # Check the number of iscsi paths for each SAN volume
#    if [ -z "$MODE" ]; then
#        echo "nr_hbas=$nr_hbas"
#        echo "nr_active_sessions=$nr_active_sessions"
#        echo "nr_targets=$nr_targets"
#        echo "nr_sessions_per_target=$nr_sessions_per_target"
#    fi

    [ -z "$MODE" ] && echo "Name #ActivePaths/#Paths"
    while read name wwid nr_paths others; do
            check_nr_path ${nr_paths}
            check_path=$?
            [ $check_path -gt 0 ] && check_aggr_return $check_path "Missing path for: $name ($nr_paths active paths/${nr_sessions_expected})"
            [ -z "$MODE" ] && ([ $check_path -gt 0 ] || ([ $check_path -eq 0 -a $ARG_PRINT_ONLY_FAILED_PATH -eq 0 ])) && echo "$name $nr_paths/${nr_sessions_expected}"
    done < $mp_temp_file
    
    # check iscsi sessions state
    for session in $(ls -1d /sys/class/iscsi_session/session*/device/target*|egrep -o '/sys/class/iscsi_session/session[0-9]+'); do
            id_session=$(basename $session)
            if [ -f $session/state ]; then
                    state=$(cat $session/state)
                    [ "$state" != "LOGGED_IN" ] && check_aggr_return 1 "iSCSI session (${id_session}) is not connected. Invalid iscsi session state: $state"
            fi
    done
    
    [ -z "$CHECK_MSG" ] && CHECK_MSG='OK'
    set_return ${CHECK_STATUS} "${CHECK_MSG}"
}



######



########
# MAIN #
########

# Close STDERR
exec 2>/dev/null

ARG_PRINT_ONLY_FAILED_PATH=0
MODE=
BASEOID='.1.3.6.1.4.1.38673.1.15'
NR_HBAS=0
NR_SESSIONS_PER_TARGET_PER_HBA=0

while getopts 'g:n:shfH:S:' option; do
    case "$option" in
        # snmp
        g) MODE='get' ; OID=$OPTARG ;;
        n) MODE='next' ; OID=$OPTARG ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;

        # others
        h) { usage; exit 0; } ;;
        f) ARG_PRINT_ONLY_FAILED_PATH=1 ;;
        H) NR_HBAS=$OPTARG ;;
        S) NR_SESSIONS_PER_TARGET_PER_HBA=$OPTARG ;;
    esac
done

#shift $(($OPTIND-1))

mp_temp_file=$(mktemp)
trap myexit EXIT

# Check for requested OID
#OID=$1

# Do the check
if [ -z "$MODE" ]; then
    docheck | column -t
    exit 0
else
    docheck
fi

if [ -n "$MODE" ] && ! (echo $OID | grep -qE "^$BASEOID"); then
    echo "Error: base OID must begin with $BASEOID" >&2
    exit 1
fi

case ${OID#$BASEOID} in
    '')
        if [ "$MODE" = 'next' ]; then
            snmp_get 0
        fi
        ;;
    .0)
        if [ "$MODE" = 'get' ]; then
            snmp_get 0
        else
            snmp_get 1
        fi
        ;;
    .1)
        if [ "$MODE" = 'get' ]; then
            snmp_get 1
        fi
        ;;
esac

exit 0
