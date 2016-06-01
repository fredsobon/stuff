#!/bin/bash
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-10-02
# Sonde SNMP pour check la synchronisation des BIGIP 
usage() {
        cat <<EOF
check_sync_bigip
Usage:
    check_sync_bigip.sh  -H|--host <IP> 
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
if [[ $HOST  =~ 10.3.254 ]] 
then
    BASEOID='1.3.6.1.4.1.3375.2.1.1.1.1.6.0'
    valeur=`/usr/bin/snmpget -Oqv -v2c $HOST -c pixro $BASEOID`
    STATE=`echo $valeur |cut -c2`
    SITE="VIT"
else
    BASEOID='.1.3.6.1.4.1.3375.2.1.14.1'
    STATE=`/usr/bin/snmpget -Oqv -v2c $HOST -c pixro ${BASEOID}.3.0`
    MESSAGE=`/usr/bin/snmpget -Oqv -v2c $HOST -c pixro ${BASEOID}.4.0`
    SITE="DC3"
fi

check_Sync_bigip() {

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

FILE_MAX_AGE="10800"
filename="/tmp/sync_lb_${HOST}"


case $SITE in 
VIT)
if [ ! -e $filename ]
        then
            valeur=`/usr/bin/snmpget -Oqv -v2c $HOST -c pixro $BASEOID`
            STATE=`echo $valeur |cut -c2`
            case $STATE in
                0)
                  STATUS=$STATE_OK
                  MESSAGE="OK – Pas de probleme de synchronisation BIGIP"
                ;;
                3)
                  STATUS=$STATE_CRITICAL
                  MESSAGE="CRITICAL – Les deux BIGIP ont ete modifie!!!"
                ;;
                *)
                  STATUS=$STATE_OK
                  MESSAGE="WARNING – Verifier la synchro du BIGIP!!!"
                  /usr/bin/touch $filename
                ;;
            esac

else
        valeur=`/usr/bin/snmpget -Oqv -v2c $HOST -c pixro $BASEOID`
        STATE=`echo $valeur |cut -c2`
        case $STATE in
            0)
              STATUS=$STATE_OK
              MESSAGE="OK – Pas de probleme de synchronisation BIGIP"
              /bin/rm -f $filename
            ;;
            3)
              STATUS=$STATE_CRITICAL
              MESSAGE="CRITICAL – Les deux BIGIP ont ete modifie!!!"
            ;;
            *)
              DELAIS=`/bin/date -d "now - $( stat -c "%Y" $filename ) seconds" +%s`
              t=$(echo "scale=0; (($DELAIS/60))" |bc)
              if [ "$DELAIS" -gt "$FILE_MAX_AGE" ]
                then
                    STATUS=$STATE_WARNING
                    MESSAGE="WARNING – Sync KO depuis plus de 3 heures ($t minutes) - Verifier la synchro du BIGIP!!! "
              else
                    STATUS=$STATE_OK
                    MESSAGE="WARNING – Sync BIGIP KO  depuis moins de 3 heures ($t minutes)"
              fi
            ;;
        esac

fi
;;
DC3)
if [ ! -e $filename ]
        then
            case $STATE in
                0)
                  STATUS=$STATE_OK
                ;;
                2)
                  STATUS=$STATE_CRITICAL
                ;;
                1)
                  STATUS=$STATE_OK
                  /usr/bin/touch $filename
                ;;
            esac

else
        case $STATE in
            0)
              STATUS=$STATE_OK
              /bin/rm -f $filename
            ;;
            2)
              STATUS=$STATE_CRITICAL
            ;;
            1)
              DELAIS=`/bin/date -d "now - $( stat -c "%Y" $filename ) seconds" +%s`
              t=$(echo "scale=0; (($DELAIS/60))" |bc)
              if [ "$DELAIS" -gt "$FILE_MAX_AGE" ]
                then
                    STATUS=$STATE_WARNING
                    MESSAGE="WARNING – Sync KO depuis plus de 3 heures ($t minutes) - Verifier la synchro du BIGIP!!! "
              else
                    STATUS=$STATE_OK
                    MESSAGE="WARNING – Sync BIGIP KO  depuis moins de 3 heures ($t minutes)"
              fi
            ;;
        esac

fi

;;
esac

return $STATUS
return $MESSAGE
}

check_Sync_bigip
echo "$MESSAGE"
exit $STATUS

