#!/bin/bash
#set -x
#=========================================================================================================
# Title         : Monitoring quota on server FTP 1.35
# Date          : 2014-08-25
# Author        : Abdelaziz LAMJARHJARH for E-merchant 
# Version       : 1.0
# Description   : script which check quota for list_user of FTP and send a mail to bocompta@pixvalley.com 
#               and it.prod.admin@pixmania-group.com if one of them is reached. 
#
#=========================================================================================================
# Version History :
#
#=========================================================================================================

function message() {

cat <<EOF
$st : User $user has exceed its allowed quota by more than $quota_S % !!!  
-------------------------------------------------------"
Quota autorised : $quota KB,
Used : $used KB, 
Percentage used : $P_QUOTA_U %
Regards,
Sysadmin
EOF

}

Quota_W="85.00"
Quota_Cr="90.00"
Mail_D_Alert="bocompta@pixvalley.com"
Mail_admin="a.lamjarhjarh@pixmania-group.com"


/usr/sbin/xfs_quota -x -c 'report'  /srv/data/prod /srv/data/uat /srv/data/dev| sed '1,2d;4d;s/Project ID/ProjectID/'| grep -Ev "/srv/data|ProjectID|^---|Blocks"| column -t  > /tmp/out_quota 2>/dev/null

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
     	st="CRITICAL /!\ "
        quota_S=$Quota_Cr
        echo $line |grep -q pix_fep
        case $? in 
        0)
         message $user $quota_S $quota $used $st $P_QUOTA_U | mail -s " CRITICAL: $user has exceeded its allowed quota by more than $Quota_Cr % !!" $Mail_admin $Mail_D_Alert 
        ;;
        1)
         message $user $quota_S $quota $used $st $P_QUOTA_U | mail -s " CRITICAL: $user has exceeded its allowed quota by more than $Quota_Cr % !!" $Mail_admin
        ;;
        esac 
    else
         st="WARNING !"
         quota_S=$Quota_W
         echo $line |grep -q pix_fep
         case $? in 
         0)
         message $user $quota_S $quota $used $st $P_QUOTA_U | mail -s " WARNING: $user has exceeded its allowed quota by more than $Quota_W %  " $Mail_admin $Mail_D_Alert
         ;;
         1) 
         message $user $quota_S $quota $used $st $P_QUOTA_U | mail -s " WARNING: $user has exceeded its allowed quota by more than $Quota_W %  " $Mail_admin 
         ;;
         esac
    fi
else
st="OK "
quota_S="OK"

fi

done < /tmp/out_quota

