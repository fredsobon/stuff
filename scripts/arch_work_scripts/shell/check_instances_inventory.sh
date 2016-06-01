#!/bin/bash

# vim: set sw=4 et ts=4

#######
# File          : check_instances_inventory.sh
# Author        : David Larquey
# Created       : 31/12/2014
# Last modified : 31/12/2014, dlarquey
# Usage         : check_instances_inventory.sh
#
# DATA
#   Input: /etc/oratab
#               
#       Output: Status of all oracle instances for this server
#
# Description   :   Monitor instances from the inventory
#           Check the concordance : ORATAB <-> Inventory <-> PMON
#
# Example       :   check_instances_inventory
#
###################################################################

#set -x
#exec 2>&-

###
# Check all oracle instances from the inventory file on this server:
# - Check if the instance from the inventory is declared into the oratab file
# - Check if the instance from the inventory is UP (PMON)
#
# The inventory is a local file:
# INPUT_INVENTORY_FILE=/opt/oracle/admin/orawork/inventory/orainv_instances.csv
# Expected (regexp) line format of the inventory file: ";" is the field separator
#
# ^{HOSTNAME};{instance};.*;Monitoring_enabled$
#
# HOSTNAME: the hostname of the server
# instance: the oracle instance to monitor
# Monitoring_enabled: boolean to enable/disable the monitoring of the instance
###


usage() {
cat <<EOS

Usage:

    This script is used to answer to an SNMP request

    $(basename $0) [-g|-n OID] [-d|-l]
    
        -g OID  Get the OID
        -n OID  Get the next OID
        -d      Enable the debug mode
        -l      Allow the output message to be printed in several lines. The default is to output the message in one single line
        -h      This help

EOS
    exit 1
}


######################
### SNMP Functions ###
######################

debug() {
    [ $DEBUG -eq 1 ] && echo "DEBUG: $*"
}

snmp_get() {
    case "$1" in
        0) 
            echo -e "$BASEOID.$1\nINTEGER\n$CHECK_STATUS"
        ;;
        1) 
            echo -e "$BASEOID.$1\nSTRING\n$CHECK_MSG"
        ;;
    esac
}
    
Init() {
    debug "Init"
    CHECK_STATUS=0
    CHECK_MSG=""
    CHECK_ERROR_MSG=""
    CHECK_WARN_MSG=""

    debug "- Hostname: $FULL_HOSTNAME"
    debug "- Inventory file: $INPUT_INVENTORY_FILE"
    debug "- Listening on OID: $BASEOID"
}

docheck() {
    main_check

    if [ $CHECK_STATUS -eq 0 ]; then
        CHECK_MSG='OK'
    else
        if [ -n "${CHECK_ERROR_MSG}" ]; then
            CHECK_MSG="${CHECK_ERROR_MSG}\n${CHECK_WARN_MSG}"
        elif  [ -n "${CHECK_WARN_MSG}" ]; then
            CHECK_MSG="${CHECK_WARN_MSG}"
    fi
    fi

    [ $OUTPUT_IN_ONE_ROW -eq 1 ] && CHECK_MSG=$(echo -e "${CHECK_MSG}"|sed ':a;N;s/\n/ | /;ba')
    if [ $DEBUG -eq 1 ]; then
        debug "--------- OUTPUT ---------"
        echo -e "${CHECK_STATUS} - ${CHECK_MSG}"
        exit $CHECK_STATUS
    fi
}


#################
### Functions ###
#################

# --- functions to get instances from the oratab or inventory files or from the PMON processes
get_oratab_instances() {
    unset tab_oratab_instances
    local oratabfile=/etc/oratab
    for instance in $(cat $oratabfile|egrep -v '^#|^oracle'|egrep '^[[:blank:]]*ora|^[[:blank:]]*\+'|cut -d':' -f1|tr '[A-Z]' '[a-z]'); do
        [ "${instance:0:4}" == "+asm" ] && continue
        tab_oratab_instances[${#tab_oratab_instances[@]}]=$instance
    done
}

get_pmon_instances() {
    unset tab_pmon_instances
    local instance
    for instance in $(pgrep -fl pmon|awk '{split($2,tab,"_"); print tab[length(tab)]}'|tr '[A-Z]' '[a-z]'); do
        [ "${instance:0:4}" == "+asm" ] && continue
        tab_pmon_instances[${#tab_pmon_instances[@]}]=$instance
    done
}

get_inv_instances() {
    unset tab_inv_instances
    local instance
    for instance in $(cat $INPUT_INVENTORY_FILE|grep -i "^${FULL_HOSTNAME};.*;true$"|awk -F";" '{print $2}'|tr '[A-Z]' '[a-z]'); do
        [ "${instance:0:4}" == "+asm" ] && continue
        tab_inv_instances[${#tab_inv_instances[@]}]=$instance
    done
}

get_inv_blacklisted_instances() {
    unset tab_inv_blacklisted_instances
    local instance
    for instance in $(cat $INPUT_INVENTORY_FILE|grep -i "^${FULL_HOSTNAME};.*;false$"|awk -F";" '{print $2}'|tr '[A-Z]' '[a-z]'); do
        [ "${instance:0:4}" == "+asm" ] && continue
        tab_inv_blacklisted_instances[${#tab_inv_blacklisted_instances[@]}]=$instance
    done
}

get_inv_blacklisted_host() {
    cat $INPUT_INVENTORY_FILE|grep -qi "^${FULL_HOSTNAME};.*;DISABLE_HOST$" && host_is_blacklisted=1
}

# --- function to test an instance
test_instance_for_tab() {
    local tab
    local instance="$1"
    shift
    local tab=($@)
    typeset -i i
    local i_test_instance_for_tab

    # test if the instance is blacklisted
    test_blacklisted_instance "${instance}" && { debug "[test_instance][${instance}] - BLACKLIST - The instance ${instance} is blacklisted into the inventory. Try next." ; return 0; }

    debug "[test_instance][${instance}] Test if the instance ${instance} exists into the target tab: [ ${tab[@]} ]"
    for i_test_instance_for_tab in $(seq 0 $((${#tab[@]} - 1))); do
        [ "$instance" == "${tab[$i_test_instance_for_tab]}" ] && { debug "[test_instance][${instance}] The instance ${instance} exists into the target tab"; return 0; }
    done
    debug "[test_instance][${instance}] ERROR: Can't find the instance: ${instance} into the target tab: [ ${tab[@]} ]"
    return 1
}

# --- function to test if an instance is blacklisted
test_blacklisted_instance() {
    local instance="${1}"
    shift
    typeset -i i
    local i_test_blacklisted_instance
    debug "[blacklist_test] Test if the instance ${instance} is blacklisted into the inventory"

    for i_test_blacklisted_instance in $(seq 0 $((${#tab_inv_blacklisted_instances[@]} - 1))); do
        [ "$instance" == "${tab_inv_blacklisted_instances[$i_test_blacklisted_instance]}" ] && return 0;
    done
    return 1
}

# --- function used for the output
add_output_warning_message() {
    [ $CHECK_STATUS -lt 1 ] && CHECK_STATUS=1
    if [ -n "${CHECK_WARN_MSG}" ]; then
        CHECK_WARN_MSG="${CHECK_WARN_MSG}\nWARNING: $*"
    else
        CHECK_WARN_MSG="WARNING: $*"
    fi
}

add_output_error_message() {
    CHECK_STATUS=2
    if [ -n "${CHECK_ERROR_MSG}" ]; then
        CHECK_ERROR_MSG="${CHECK_ERROR_MSG}\nERROR: $*"
    else
        CHECK_ERROR_MSG="ERROR: $*"
    fi
}


main_check() {

    if [ ! -f $INPUT_INVENTORY_FILE ]; then
        add_output_warning_message "Can't find local instance inventory file: $INPUT_INVENTORY_FILE"
        return
    fi

    get_oratab_instances
    debug "# List of all instances from ORATAB"
    debug ${tab_oratab_instances[@]}

    get_pmon_instances
    debug "# List of all instances from PMON"
    debug ${tab_pmon_instances[@]}
    
    get_inv_instances
    debug "# List of all instances into the inventory for this host"
    debug ${tab_inv_instances[@]}
    
    get_inv_blacklisted_instances
    debug "# List of all blacklisted instances into the inventory for this host"
    debug ${tab_inv_blacklisted_instances[@]}

    host_is_blacklisted=0
    debug "# Test if this host is blacklisted"
    get_inv_blacklisted_host
    [ $host_is_blacklisted -eq 1 ] && { debug "This host is blacklisted. Nothing to do."; return; }

    [ ${#tab_inv_instances[@]} -eq 0 ] && [ ${#tab_inv_blacklisted_instances[@]} -eq 0 ] && add_output_warning_message "No instances found into the inventory for the host: <$FULL_HOSTNAME>"
    
    #tab_oratab_instances[${#tab_oratab_instances[@]}]='toto'
    #tab_pmon_instances[${#tab_pmon_instances[@]}]='tata'
    #tab_inv_instances[${#tab_inv_instances[@]}]='titi'


    # tests: inventory <-> PMON
    debug "######### inventory <-> PMON #########"
    
#    debug "--------- inventory -> PMON --- For all <INVENTORY> instances, check if it exists an <PMON> instance"
#    debug "Nr INVENTORY instances to check: ${#tab_inv_instances[@]}"
#    for i in $(seq 0 $((${#tab_inv_instances[@]} - 1))); do
#        t_instance="${tab_inv_instances[$i]}"
#        debug "* [INVENTORY->PMON] --- Test PMON instances for the INVENTORY instance: ${t_instance}"
#        test_instance_for_tab "${t_instance}" "${tab_pmon_instances[@]}" || add_output_error_message "instance \"${t_instance}\" is defined into the inventory file but has no associated PMON process"
#    done
#
#    debug "--------- PMON -> inventory --- For all <PMON> instances, check if it exists an <INVENTORY> instance"
#    debug "Nr PMON instances to check: ${#tab_pmon_instances[@]}"
#    debug "PMON instances to check: ${tab_pmon_instances[@]}"
#    for i in $(seq 0 $((${#tab_pmon_instances[@]} - 1))); do
#        t_instance="${tab_pmon_instances[$i]}"
#        debug "* [INVENTORY<-PMON] --- Test INVENTORY instances for the PMON instance: ${t_instance}"
#        test_instance_for_tab "${t_instance}" "${tab_inventory_instances[@]}" || add_output_warning_message "instance \"${t_instance}\" is started (PMON) but not defined into the inventory file"
#    done
    
    # tests: inventory <-> oratab
    debug "######### inventory <-> oratab #########"

    debug "--- inventory -> oratab --- For all <INVENTORY> instances, check if it exists an <ORATAB> instance"
    debug "Nr INVENTORY instances to check: ${#tab_inv_instances[@]}"
    for i in $(seq 0 $((${#tab_inv_instances[@]} - 1))); do
        t_instance="${tab_inv_instances[$i]}"
        debug "* [INV->ORATAB] --- Test ORATAB instances for INVENTORY instance: ${t_instance}"
        test_instance_for_tab "${t_instance}" "${tab_oratab_instances[@]}" || add_output_warning_message "instance \"${t_instance}\" is enabled into the inventory but not into the oratab file"
    done
    
    debug "--- oratab -> inventory --- For all <ORATAB> instances, check if it exists an <INVENTORY> instance"
    debug "Nr ORATAB instances to check: ${#tab_oratab_instances[@]}"
    for i in $(seq 0 $((${#tab_oratab_instances[@]} - 1))); do
        t_instance="${tab_oratab_instances[$i]}"
        debug "* [INV<-ORATAB] --- Test INVENTORY instances for the ORATAB instance: ${t_instance}"
        test_instance_for_tab "${t_instance}" "${tab_inv_instances[@]}" || add_output_warning_message "instance \"${t_instance}\" is defined into the oratab file but not into the inventory"
    done
    
    # tests: oratab <-> PMON
    debug "######### oratab <-> PMON #########"

    debug "--------- oratab -> PMON --- For all <ORATAB> instances, check if it exists an <PMON> instance"
    debug "Nr ORATAB instances to check: ${#tab_oratab_instances[@]}"
    for i in $(seq 0 $((${#tab_oratab_instances[@]} - 1))); do
        t_instance="${tab_oratab_instances[$i]}"
        debug "* [ORATAB->PMON] --- Test PMON instances for the ORATAB instance: ${t_instance}"
        test_instance_for_tab "${t_instance}" "${tab_pmon_instances[@]}" || add_output_error_message "instance \"${t_instance}\" is defined into the oratab file but has no associated PMON process"
    done
    
    debug "--------- PMON -> oratab --- For all <PMON> instances, check if it exists an <ORATAB> instance"
    debug "Nr PMON instances to check: ${#tab_pmon_instances[@]}"
    debug "PMON instances to check: ${tab_pmon_instances[@]}"
    for i in $(seq 0 $((${#tab_pmon_instances[@]} - 1))); do
        t_instance="${tab_pmon_instances[$i]}"
        debug "* [ORATAB<-PMON] --- Test ORATAB instances for the PMON instance: ${t_instance}"
        test_instance_for_tab "${t_instance}" "${tab_oratab_instances[@]}" || add_output_warning_message "instance \"${t_instance}\" is started (PMON) but not defined into the oratab file"
    done
}




########
# Init #
########

export LANG=en_US.utf8
INPUT_INVENTORY_FILE=/opt/oracle/admin/orawork/inventory/orainv_instances.csv

BASEOID='.1.3.6.1.4.1.38673.1.34'
OUTPUT_IN_ONE_ROW=1


#############
### START ###
#############

FULL_HOSTNAME=$(hostname -f)
MODE=
DEBUG=0

while getopts 'g:n:shdl' option; do
    case "$option" in
        # snmp
        g) MODE='get'; OID=$OPTARG ;;
        n) MODE='next'; OID=$OPTARG ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;
        d) DEBUG=1 ;;
        l) OUTPUT_IN_ONE_ROW=0 ;;
        # others
        h) usage ;;
    esac
done

# Init
Init

# Do the check
if [ -z "$MODE" ] && [ $DEBUG -eq 0 ]; then
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

exit

