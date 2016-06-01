#!/bin/bash
#set -x
#========================================================================================
# Title         : taskmanager_touch.sh
# Date          : 2014-01-22
# Author        : Abdelaziz LAMJARHJARH for E-merchant 
# Version       : 1.0
# Description   : This script does a touch on State fqdn cron 
#========================================================================================
# Version History :
#
#========================================================================================
FILE=`hostname -f`
PATH="/mnt/share/taskmanager/state"

param=`/bin/hostname -f |/usr/bin/awk -F "." '{print$1}'`
echo "$param"
case "$param" in
cron00)
;;
*)
/usr/bin/touch $PATH/$FILE
;;
esac

