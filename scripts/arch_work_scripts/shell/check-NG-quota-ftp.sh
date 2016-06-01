#!/bin/bash
#
#
BASEOID='.1.3.6.1.4.1.38673.1.33'
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
check_quota_ftp() {
STATE_OK=0
STATE_WARNING=1

Quota_W="85.00"
Quota_Cr="90.00"

/usr/bin/sudo /usr/sbin/xfs_quota -x -c 'report'  /srv/data/prod /srv/data/uat /srv/data/dev| sed '1,2d;4d;s/Project ID/ProjectID/'| grep -Ev "/srv/data|ProjectID|^---|Blocks"| column -t  > /tmp/out_ftp_quota 2>/dev/null

while read line 
do

    folder=`echo $line |awk '{print$1}'`
    used=`echo $line |awk '{print$2}'`
    quota=`echo $line |awk '{print$4}'`
    param=`echo $line |awk -F "_" '{print$1}'`
    user=`echo $folder |awk -F "${param}_" '{print$2}'`
    #echo " folder $folder : quota = $cota --> Used = $used ------- $user" 

    P_QUOTA_U=`echo $line | awk '{pu=$2/$4*100}{printf("%.2f", pu)}'`

result1=`echo "${P_QUOTA_U} > ${Quota_W}" |bc`
result2=`echo "${P_QUOTA_U} > ${Quota_Cr}" |bc`
if [ "$result1" -eq "1" ]
then
    if [ "$result2" -eq "1" ]
    then
        MESSAGE="$user : quota used is $P_QUOTA_U % / "
        echo -e "$MESSAGE\n" >> /tmp/report_ftp_quota
    else
        MESSAGE="$user : quota used is $P_QUOTA_U % / "
         echo -e "$MESSAGE\n" >> /tmp/report_ftp_quota
    fi
else
st="OK "
quota_S="OK"
MESSAGE="OK - $user respect his quota :)"
echo -e "$MESSAGE\n" >> /tmp/report_ftp_quota
fi

done < /tmp/out_ftp_quota

retour=`grep -Ev "OK|" /tmp/report_ftp_quota |wc -l `

if [ "$retour" != "0" ] ; then
    STATUS=$STATE_WARNING
    MESSAGE=`cat /tmp/report_ftp_quota|grep -v OK`
else
    STATUS=$STATE_OK
    MESSAGE="OK -  All users respect their quota :)"
fi
echo " " > /tmp/report_ftp_quota
return $STATUS
return $MESSAGE
}


snmp_get() {
    check_quota_ftp
    case "$1" in
        0)
            echo -e "$BASEOID.$1\nINTEGER"
            echo $STATUS 
            ;;
        1)
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

