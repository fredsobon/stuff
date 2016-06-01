#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2015-01-14

usage() {
        cat <<EOF
check_backup_esx
Usage:
    check_backup_esx.sh  -H|--host <IP> 
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

check_backup_esx() {
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

STAT=`/usr/bin/snmpwalk -v 1 -c pixro $HOST 1.3.6.1.2.1.25.2.3.1.3 |grep esxi_backup |wc -l`

if [ "$STAT" = "0" ]
then
STATUS=$STATE_OK
MESSAGE="Pas de backup en cours"
else
STATUS=$STATE_WARNING
MESSAGE="Backup in progress !!"
fi
return  $STATUS
return $MESSAGE
}

check_backup_esx
echo "$MESSAGE" 
exit $STATUS


