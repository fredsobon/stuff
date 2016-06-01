#!/bin/bash
#
#
BASEOID='.1.3.6.1.4.1.38673.1.29.1'
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

check_domu() {

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

XENDOM_CONFIG=/etc/default/xendomains

test -r $XENDOM_CONFIG || { echo "$XENDOM_CONFIG not existing";
        if [ "$1" = "stop" ]; then exit 0;
        else exit 6; fi; }

. $XENDOM_CONFIG

CRIT=0;
WARN=0;
ERROR=0;
OK=0;
ndomu=$(find /etc/xen/vm/ -name *.cfg |wc -l)
if [ "$ndomu" == "0" ]; then
STATUS=0
MESS="Xen OK but no VMs on this Hypervisor ! "
return  $STATUS
return $MESS
else

#Looking for the autostarted domains state
for dom in /etc/xen/vm/*.cfg; do
  #This needs improvement, doesn't work if it isn't www.example.com
  NAME=$(basename $dom| awk -F ".cfg" '{print$1}')
  sudo xm list $NAME > /tmp/.check_xen_host 2>/dev/null
  if [ "$?" != "0" ]; then
  list1[$ERROR]=$(echo $NAME|awk -F "e-merchant" '{print$1}')
  let ERROR++;
  else
  list2[$OK]=$(echo $NAME|awk -F "e-merchant" '{print$1}')
  let OK++
  fi;
  R=`cat /tmp/.check_xen_host | tail -1 | cut -c 64`
  B=`cat /tmp/.check_xen_host | tail -1 | cut -c 65`
  P=`cat /tmp/.check_xen_host | tail -1 | cut -c 66`
  S=`cat /tmp/.check_xen_host | tail -1 | cut -c 67`
  C=`cat /tmp/.check_xen_host | tail -1 | cut -c 68`
  D=`cat /tmp/.check_xen_host | tail -1 | cut -c 69`

  if [ "$R" == "r" ] || [ "$B" == "b" ]; then
    #This one is OK, no exiting
          echo "OK - Virtual System is Up" > /dev/null
  fi

  if [ "$P" == "p" ]; then
         # echo "Warning - $NAME is Paused"
         list3[$WARN]=$(echo $NAME|awk -F "e-merchant" '{print$1}')
    let WARN++
  fi

  if [ "$S" == "s" ] || [ "$C" == "c" ] || [ "$D" == "d" ]; then
         # echo "Critical - $NAME is Down"
          list4[$CRIT]=$(echo $NAME|awk -F "e-merchant" '{print$1}')
    let CRIT++
  fi
done


 n1=$(expr $ERROR - 1)
 n2=$(expr $WARN - 1)
 n3=$(expr $CRIT - 1)
 n4=$(expr $OK - 1)

if [ "$ERROR" != "0" ] ; then
chaine1=`for i in $(seq 0 $n1); do echo -n " ${list1[$i]}, " ; done`
message="WARNING $ERROR VMs not running : $chaine1" 
MESS=$message
#exitstatus=$STATE_WARNING
if [ "$WARN" != "0" ] ; then
chaine3=`for i in $(seq 0 $n2); do echo -n " ${list3[$i]}, " ; done`
MESS="$message and there are $WARN guests paused : $chaine3"
fi
STATUS=$STATE_WARNING
fi

if [ "$WARN" = "0" ]  && [ "$CRIT" = "0" ] && [ "$ERROR" = "0" ]; then
   chaine2=`for i in $(seq 0 $n4); do echo -n " ${list2[$i]}, " ; done`
    MESS="All OK no guests with problems. List of VM : $chaine2  "
    STATUS=$STATE_OK
elif [ "$CRIT" != "0" ]; then
    chaine4=`for i in $(seq 0 $n3); do echo -n " ${list4[$i]}, " ; done`
    MESS="ERROR, there are $CRIT guests with problems: $chaine4"
    STATUS=$STATE_CRITICAL
fi

return  $STATUS 
return $MESS
fi
}

snmp_get() {
    check_domu  
    case "$1" in
        0)
            echo -e "$BASEOID.$1\nINTEGER"
            echo $STATUS 
            ;;
        1)
            echo -e "$BASEOID.$1\nSTRING"
            echo $MESS 
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
            snmp_get 0
       fi
        ;;
    .0)
        if [ "$MODE" == 'get' ]; then
            snmp_get 0 
        else
            snmp_get 1
        fi
        ;;
    .1)
        if [ "$MODE" == 'get' ]; then
            snmp_get 1 
        fi
        ;;
esac

