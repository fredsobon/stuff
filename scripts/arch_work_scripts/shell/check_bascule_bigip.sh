#!/bin/bash
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-10-02
# Sonde SNMP pour remonter la bascule du BIGIP entre standby & active 
usage() {
        cat <<EOF
check_bascule_bigip
Usage:
    check_bascule_bigip.sh  -H|--host <IP> 
Arguments :
   -H | --Host <IP>
        IP du BIGIP 
[Divers]
   -h | --help
         Affiche cette aide
EOF
}
while [ $# -ne 0 ]; do
        case $1 in
                '--host'|'-H')
                        HOST=$2
                        ;;
                '--help'|'-h')
                        usage
                        exit
                        ;;
                           *)
                        ;;
        esac
        shift
done
BASEOID='.1.3.6.1.4.1.3375.2.1.1.1.1.19.0'

check_bascule_bigip() {
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

output="/tmp/state_lb_${HOST}"
if [ ! -e $output ]
then
STATE=`/usr/bin/snmpget -Oqv -v2c $HOST -c pixro $BASEOID`
echo $STATE > $output
LIST_STATE[0]=$STATE
case $STATE in
0)
  LIST_STATE[1]="Status : STANDBY"
;;
3)
  LIST_STATE[1]="Status : ACTIVE"
;;
esac
else
STATE=`cat $output|head -1`
LIST_STATE[0]=$STATE
case $STATE in
0)
  LIST_STATE[1]="Status : STANDBY"
;;
3)
  LIST_STATE[1]="Status : ACTIVE"
;;
esac
fi

STATE=`/usr/bin/snmpget -Oqv -v2c $HOST -c pixro $BASEOID`

if [ "$STATE" != "${LIST_STATE[0]}" ]
then
STATUS=$STATE_WARNING
case $STATE in
0)
  LIST_STATE[1]="Status : STANDBY"
;;
3)
  LIST_STATE[1]="Status : ACTIVE"
;;
esac
MESSAGE="WARNING - le BIGIP a basculé vers ${LIST_STATE[1]}"
else
STATUS=$STATE_OK
MESSAGE="OK - Pas de bascule --> ${LIST_STATE[1]}"
fi

return $STATUS
return $MESSAGE
}

check_bascule_bigip
echo "$MESSAGE"
exit $STATUS
               
