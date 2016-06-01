#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2015-01-16

usage() {
        cat <<EOF
check_vmware_tools_esx
Usage:
    check_vmware_tools_esx.sh  -H|--host <IP> 
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
 exit
fi

check_vmware_tools_esx() {
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

for vm in `snmpwalk -v1 -c pixro $HOST 1.3.6.1.4.1.6876.2.1.1.2 |awk '{print$NF}'|sed "s/^\([\"']\)\(.*\)\1\$/\2/g"`;
do
/usr/local/nagios/bin/check_esx3-0.5.pl -H $HOST -u nagios -p pixmania -N $vm -l runtime -s tools >> /tmp/vmtools_report
done

STAT=`cat /tmp/vmtools_report |grep -vc OK`

if [ "$STAT" = "0" ]
then
STATUS=$STATE_OK
MESSAGE="VMware_tools on all VMs are OK"
else
STATUS=$STATE_WARNING
MESSAGE=`cat  /tmp/vmtools_report |grep -v OK`
fi
return  $STATUS
return $MESSAGE
}

check_vmware_tools_esx
echo "$MESSAGE" 
rm -f /tmp/vmtools_report
exit $STATUS



