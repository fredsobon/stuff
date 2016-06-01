#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-10-13

DNS_SEARCH=`which dns_search`
usage() {
        cat <<EOF

Aknowledge alerte bigip  ( sync | bascule )

Usage:
     acknowledge.sh -t < bascule|synch>  

Arguments :
   
   -t | --type <type alerte>  
         (sync, bascule)
 
[Divers]
   -h | --help

EOF
}

while [ $# -ne 0 ]; do
        case $1 in
                '--type'|'-t')
                        TYPE_ALERTE=$2
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
clear

list_server=`$DNS_SEARCH ^work0 -1`

# Check mandatory parameters
if [ -z "$TYPE_ALERTE" ]  ; then
     usage
     exit
fi

echo "La liste des serveurs work :"
echo "$list_server"
echo "\n\n"
case $TYPE_ALERTE in
bascule)
for srv in $list_server
do
ssh -o StrictHostKeyChecking=no $srv " rm -f /tmp/state_lb* "
done
;;
sync)
for srv in $list_server
do
ssh -o StrictHostKeyChecking=no $srv " rm -f /tmp/sync_lb* "
done
;;
esac

