#!/bin/bash
#set -x

#=======================================================================================#
# Title         : sync_config_pertimm.sh                                                #
# Date          : 2014-11-19                                                            #
# Author        : Abdelaziz LAMJARHJARH for E-merchant                                  #
# Version       : 1.0                                                                   #
# Description   : Synchronisation fichiers avec FTP                                     #
#                                                                                       #
#=======================================================================================#
# Version History :                                                                     #    
#                                                                                       #
#=======================================================================================#

ENV=`hostname -f|awk -F "." '{print$4}'`

FOLDER_P="/opt/pertimm/projects"
FOLDER_UI="apps/ui_search/config/plugins"
FOLDER_API="apps/api_search/config/plugins"
case $ENV in 
uat) 
SERVER_FTP="10.3.197.12"
;;
prod)
SERVER_FTP="10.3.121.50"
;;
esac
#echo $SERVER_FTP
FOLDER_P_FTP="/srv/exchange/data/e-merchant/pertimm"
LISTE_SYNC="catalog itemDetail sort wordWheel xref"

function src
{
val=`/usr/bin/ssh $SERVER_FTP "ls $FOLDER_P_FTP/$1/$2/ |wc -l "`

if [ $val == "0" ]
then
        age_src="0"
else
        age_src=`ssh $SERVER_FTP "date +%s -r $FOLDER_P_FTP/$1/$2/config.xml"`
fi
echo $age_src
}

function dest_ui
{
if [ ! -e $FOLDER_P/$1/$FOLDER_UI/$2/config.xml ]
then
        age_dest_ui="0"
else
        age_dest_ui=`date +%s -r $FOLDER_P/$1/$FOLDER_UI/$2/config.xml`
fi
echo $age_dest_ui
}

function dest_api
{
if [ ! -e $FOLDER_P/$1/$FOLDER_API/$2/config.xml ]
then
        age_dest_api="0"
else
        age_dest_api=`date +%s -r $FOLDER_P/$1/$FOLDER_API/$2/config.xml`
fi

echo $age_dest_api
}

for prj in $(ls $FOLDER_P)
do
        for fld in $LISTE_SYNC
          do
                valeur_dst_ui=$(dest_ui $prj $fld)
                valeur_dst_api=$(dest_api $prj $fld)
                valeur_src=$(src $prj $fld)
                
                diff_scr_dst_ui=$((valeur_src - valeur_dst_ui))
                diff_src_dst_api=$((valeur_src - valeur_dst_api))


                case $valeur_dst_ui in

                0)
                        #echo " no file config.xml in query "
                ;;
                *)

                ## ui_search
                if [ "$diff_scr_dst_ui" -gt "0" ]
                then
                  rsync -a root@$SERVER_FTP:$FOLDER_P_FTP/$prj/$fld/config.xml $FOLDER_P/$prj/$FOLDER_UI/$fld/config.xml
                else
                        if [ "$diff_scr_dst_ui" != "0" ]
                        then
                           rsync -a $FOLDER_P/$prj/$FOLDER_UI/$fld/config.xml root@$SERVER_FTP:$FOLDER_P_FTP/$prj/$fld/config.xml
                        fi
                fi
                ## api_search
                if [ "$diff_src_dst_api" -gt "0" ]
                then
                  rsync -a root@$SERVER_FTP:$FOLDER_P_FTP/$prj/$fld/config.xml $FOLDER_P/$prj/$FOLDER_API/$fld/config.xml
                else
                        if [ "$diff_scr_dst_api" != "0" ]
                        then
                           rsync -a $FOLDER_P/$prj/$FOLDER_API/$fld/config.xml root@$SERVER_FTP:$FOLDER_P_FTP/$prj/$fld/config.xml
                        fi
                fi

                ;;
                esac
          done
/bin/chown -R pertimm:pertimm $FOLDER_P/$prj/$FOLDER_API/*/config.xml
done


