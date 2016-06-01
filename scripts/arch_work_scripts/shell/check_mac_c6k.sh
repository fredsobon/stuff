#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-09-11
usage() {
        cat <<EOF
check_mac_c6k
Usage:
    check_mac_c6k.sh  -H|--host <IP>
Arguments :
   -H | --Host <IP>
        IP du C6K
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

#STD
IP_C6K_std="77.75.48.34--0008.e3ff.fc28--VIT"

#VIT
IP_C6K_vit="77.75.48.46--0019.a994.8000--ASN 10.250.0.30--001c.0e88.6000--BRE 46.255.176.81--54e0.32a3.af82--NEO 77.75.48.49--0008.e3ff.fd90--DC3"

# DC3
IP_C6K_dc3="77.75.48.50--0008.e3ff.fc28--VIT 213.152.0.89--0024.dc98.f672--NEO"
# ASN
IP_C6K_ASN="77.75.48.45--0008.e3ff.fc28--VIT"

# BRE :
IP_C6K_BRE="10.250.0.29--0008.e3ff.fc28--VIT"

check_MAC_C6K() {
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

val=`dig -x $HOST +short`
dc=`echo $val |awk -F "." '{print$5}'`

case $dc in
std)
list=$IP_C6K_std
;;
vit)
list=$IP_C6K_vit

;;
dc3)
list=$IP_C6K_dc3

;;
asn)
list=$IP_C6K_ASN

;;
bre)
list=$IP_C6K_BRE

;;

esac

for valeur in $list
do
ip=`echo $valeur |awk -F "--" '{print$1}'`
mac=`echo $valeur |awk -F "--" '{print$2}'`
lien=`echo $valeur |awk -F "--" '{print$3}'`
dc=`echo $dc |sed 's/.*/\U&/'`
result_snmp=`snmpwalk -v 1 -c pixro $val 1.3.6.1.2.1.4.22.1.2 |grep $ip |awk -F ":" '{print$2}' |tr ‘[A-Z]‘ ‘[a-z]‘ |awk ' { mac = $1$2"."$3$4"."$5$6 } END { print mac }'`
if [ "$result_snmp" = "$mac" ]
then
MESSAGE="Adress mac of $ip ($mac) ${dc} --> $lien is OK"
else
MESSAGE="Adress mac of $ip ($mac) ${dc} --> $lien is KO "
fi
echo $MESSAGE >> /tmp/output
done

m=`cat /tmp/output|grep -v OK|wc -l`
if [ "$m" = "0" ]
then
STATUS=$STATE_OK
MESSAGE=`cat /tmp/output`
else
STATUS=$STATE_WARNING
MESSAGE=`cat /tmp/output`
fi
rm -f /tmp/output
return  $STATUS
return $MESSAGE
}

check_MAC_C6K
echo "$MESSAGE"
exit $STATUS
