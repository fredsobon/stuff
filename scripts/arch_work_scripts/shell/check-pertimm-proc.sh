#!/bin/bash
#
BASEOID='.1.3.6.1.4.1.38673.1.30.1'

MODE=''

print_usage() {
    cat <<EOF
Usage: $(basename $0) [-h] {-g|-n|-s} OID [VALUE]

Options:
   -g  get value
   -h  display this help and exit
   -n  get next value
   -s  set value
EOF
}

check_pertimm() {
    STATE_OK=0
    STATE_WARNING=1
    STATE_CRITICAL=2

    CRIT=0;
    WARN=0;
    ERROR=0;

    HOST=`/bin/hostname -f`

    P6=`ps --no-heading -C httpd -o pid,command |wc -l`
    if [ "$P6" != "0" ] ; then  S6=" OK."; st6=1 ; else S6="  KO." ; st6=0; fi
    if [ "$st6" == "0" ]; then  K6=" KO"; else K6="" ; fi

    echo "APACHE $S6 " > /tmp/output
    echo "APACHE $S6 " > /tmp/outputbis

    P7=`ps --no-heading -C ruby -o pid,command |grep delayed_job|wc -l`
    if [ "$P7" != "0" ] ; then  S7=" OK ./."; st7=1 ; else S7=" KO./." ; st7=0; fi
    if [ "$st7" == "0" ]; then  K7=" KO ./."; else K7="" ; fi

    case $HOST in
        index*)
            echo "RUBY_delayed_job $S7 " >> /tmp/output
            echo "RUBY_delayed_job $S7 " >> /tmp/outputbis
            ;;

        query*)
            ;;
    esac

    for pjt in $(ls /opt/pertimm/projects/ |grep -Ev "celio|monnier" 2> /dev/null); do
        message=""
        K=""

        P1=`ps --no-heading -C ogadmin -o pid,command |grep $pjt |wc -l`

        if [ "$P1" == "1" ] ; then
            S1=" ogadmin OK, "
            st1=1
        else
            S1=" ogadmin KO, "
            st1=0
        fi

        message=$message$S1
        [ "$st1" == "0" ] && K=$K"ogadmin KO, "

        P2=`ps --no-heading -C ogcirclog -o pid,command |grep $pjt |wc -l`

        if [ "$P2" == "1" ] ; then
            S2=" ogcirclog OK, "
            st2=1
        else
            S2=" ogcirclog KO, "
            st2=0
        fi

        message=$message$S2
        [ "$st2" == "0" ] && K=$K"ogcirclog KO, "

        P3=`ps --no-heading -C pdk_server -o pid,command |grep $pjt |wc -l`

        if [ "$P3" == "2" ]; then
            S3="pdk_server OK, "
            st3=1
        else
            S3="pdk_server KO, "
            st3=0
        fi

        message=$message$S3
        [ "$st3" == "0" ] && K=$K"pdk_server KO, "

        P4=`ps --no-heading -C ogm_ssrv -o pid,command |grep $pjt |wc -l`

        if [ "$P4" == "3" ]; then
            S4="ogm_ssrv OK, "
            st4=1
        else
            msg="ogm_ssrv: "
            st4=0

            for service in search suggest rules; do
                val=`ps --no-heading -C ogm_ssrv -o pid,command |grep $pjt |awk -F "/" '{print$(NF-1)}'|grep $service|wc -l`

                if [ "$val" == "0" ] ; then
                    msg=$msg"$service KO, "
                fi
            done

            S4=$msg
        fi

        message=$message$S4

        case $HOST in
            index*)
                ;;

            query*)
                [ "$st4" == "0" ] && K=$K$msg
                ;;
        esac

        case $HOST in
            index*)
                echo " $pjt : $S1 $S2 $S3 " >> /tmp/output
                echo " $pjt : $K " >> /tmp/outputbis
                ;;
            query*)
                echo " $pjt : $S1 $S2 $S3 $S4 " >>/tmp/output
                echo " $pjt : $K " >> /tmp/outputbis
                ;;
        esac
    done

    st=`awk -F 'KO' '{if (NF > 0) n += NF - 1 }; END { print n }' /tmp/output`

    if [ "$st" == "0" ]; then
        STATUS=$STATE_OK
        sed -i "1iALL PROCESS PERTIMM OK " /tmp/output
        MESSAGE="$(cat /tmp/output)"
    else
        STATUS=$STATE_WARNING
        sed -i "1iWARNING : $st check KO !! \n" /tmp/outputbis
        MESSAGE=$MESSAGE"$(cat /tmp/outputbis|grep KO)"
    fi

    return $STATUS
    return $MESSAGE
}

snmp_get() {
    check_pertimm
    case "$1" in
        1)
            echo -e "$BASEOID.$1\nINTEGER"
            echo $STATUS
            ;;
        2)
            echo -e "$BASEOID.$1\nSTRING"
            echo $MESSAGE
            ;;
    esac
}
# Parse for command-line arguments
while getopts 'ghns' options; do
    case "$options" in
        g) MODE='get' ;;
        n) MODE='next' ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done

shift $(($OPTIND-1))

if [ $# -ne 1 -o -z "$MODE" ]; then
    print_usage
    exit 1
fi
# Check for requested OID
OID=$1

if ! (echo $OID | grep -qE "^$BASEOID"); then
    echo "Error: base OID must begin with $BASEOID" >&2
    exit 1
fi

case ${OID#$BASEOID} in
    '')
        if [ "$MODE" == 'next' ]; then
            snmp_get 1
        fi
        ;;
    .1)
        if [ "$MODE" == 'get' ]; then
            snmp_get 1
        else
            snmp_get 2
        fi
        ;;
    .2)
        if [ "$MODE" == 'get' ]; then
            snmp_get 2
        fi
        ;;
esac


