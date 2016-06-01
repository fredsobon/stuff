#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2015-01-16


usage() {
        cat <<EOF
check_vmware_tools_esx
Usage:
     list_VM.sh -n <ESX_NAME>  # ex: list_VM.sh esx22 
Arguments :
   -n | --Name 
        Hostname court de l ESXi 
[Divers]
   -h | --help
         Affiche cette aide
EOF
}

while [ $# -ne 0 ]; do
        case $1 in
                '--name'|'-n')
                        ESX_NAME=$2
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
if [ -z "$ESX_NAME" ] ; then
 usage
 exit
fi

IP=`/usr/bin/dig +short ${ESX_NAME}.groupe-llp.com`

CMD="/usr/bin/snmpwalk -v1 -c pixro $IP 1.3.6.1.4.1.6876.2.1.1.2"
SNMP_SERVER="work01.monit.common.prod.vit.e-merchant.net"


ssh -o StrictHostKeyChecking=no $SNMP_SERVER "$CMD" | awk '{print$NF}'|sed "s/^\([\"']\)\(.*\)\1\$/\2/g" 


