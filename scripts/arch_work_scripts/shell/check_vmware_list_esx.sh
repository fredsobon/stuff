#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2015-01-16

usage() {
        cat <<EOF
check_vmware_list_esx
Usage:
    check_vmware_list_esx.sh  -H|--host <IP> 
Arguments :
   -H | --Host <IP>
        IP de l ESXi 
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

# Check mandatory parameters
if [ -z "$HOST" ] ; then
 usage
fi

check_vmware_list_esx() {
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
OUT=`/usr/local/nagios/bin/check_esx3-0.5.pl -H $HOST -u nagios -p pixmania -l runtime -s list `

STAT=`echo $OUT|grep -c DOWN`

if [ "$STAT" = "0" ]
then
STATUS=$STATE_OK
MESSAGE=" All VMs are UP "
else
STATUS=$STATE_WARNING
MESSAGE="WARNING: At least one VM is down -  `echo $OUT |awk -F " - " '{print$2}'` "
fi
return  $STATUS
return $MESSAGE
}

check_vmware_list_esx
echo "$MESSAGE" 
exit $STATUS



