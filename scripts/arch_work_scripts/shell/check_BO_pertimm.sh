#!/bin/bash
#
#set -x
#========================================================================================
# Title         : check_BO_pertimm.sh
# Date          : 2014-08-01
# Author        : Abdelaziz LAMJARHJARH for E-merchant 
# Version       : 1.0
# Description   : Sonde for checking status of the last job on BO pertimm by projects  
#========================================================================================
# Version History :
#
#========================================================================================

check_BO_pertimm() {
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

HOST=`hostname -f`
FOLDER="/opt/pertimm/projects"
i=0
for pjt in $(ls $FOLDER);
do
   STATUS=0
   echo "===> Projects : $pjt : " > /tmp/${pjt}_state_BO
   st=`/bin/su pertimm -c "/opt/pertimm/projects/$pjt/apps/queue_web_service/script/nagios/check_last_job"`
   result[$i]=" $pjt ==>  $st "
   echo ${result[$i]} >> /tmp/${pjt}_state_BO 
   i=$(expr $i + 1)
   val=`grep -c "JOB OK" /tmp/${pjt}_state_BO`
   #echo "======================"
   #cat /tmp/${pjt}_state_BO

   m=$i
   if [ "$val" = "1" ]; then
        STATUS=$STATE_OK
        MESSAGE="OK -  LAST JOB FOR $pjt IS FINISHED SUCCESFULLY  !"
   else
        STATE=$STATE_WARNING
        MESSAGE="WARNING - LAST JOB FOR $pjt IS FINISHED WITH FAILD"
   fi

   echo $MESSAGE >> /tmp/${pjt}_state_BO

done


#exit

echo "===================== RAPPORT - `date "+%a %d %b %Y %H:%M:%S"`========================" > /tmp/rapport_BO
for pjt in $(ls $FOLDER);
do
cat /tmp/${pjt}_state_BO >> /tmp/rapport_BO
done

valeur=` grep -c "JOB OK"  /tmp/rapport_BO `
if [ "$valeur" = "$m" ]; then
        STATUS=$STATE_OK 
        MESSAGE="OK -  LAST JOB FOR ALL PROJECTS IS FINISHED SUCCESFULLY  !"
else
	STATE=$STATE_WARNING
        MESSAGE=`cat /tmp/rapport_BO|grep -v OK`
fi
return $STATUS
return $MESSAGE
}

check_BO_pertimm

