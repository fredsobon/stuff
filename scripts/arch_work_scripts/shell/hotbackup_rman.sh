#!/bin/bash
#
#
# to debug the script, put the commentary character off these two following lines
#exec 2> /opt/oracle/admin/orawork/tmp/jp.log
#set -x
#
#
#--------------------------------------------------------------------------------------------
# rman format parameters
#
# - rman format default corresponds to $FORMAT_RMAN_DEFAULT
#   the string #ORACLE_SID_INPUT# will be replace by ORACLE_SID_INPUT value
#   ahead in this script
#
# - in the case the -backup_path is given, the rman format will be
#   the given -backup_path parameter concatenate with $FORMAT_BACKUP
#
# version : 13-dec-2012:2
#--------------------------------------------------------------------------------------------
#
set -x
export PATH=/bin:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:/usr/local/bin

# parameters below contain sometimes a value between two #. In this case,
# the value is at the top of the script in order to be aware about, but the value between the #
# will be modify further the script 
#
# these parameters formats with % are from rman syntax
# DATE_FORMAT is used in order to group the type of backup by hour

WORK_DIR=/opt/oracle/admin/orawork
#WORK_DIR_TMP=$WORK_DIR/tmp
WORK_DIR_TMP=/tmp/$(basename $0)
WORK_DIR_LOG=$WORK_DIR/log


#DATE_FORMAT="`date "+%H%M"`"
#SNFORMAT_BACKUP="%d_#BACKUP_TYPE#_dbid_%I_%s_${DATE_FORMAT}_%s_%p_%t.bkp"
DATE_FORMAT="`date "+%d%m%Y%H%M"`"
FORMAT_BACKUP="%d_#BACKUP_TYPE#_dbid_%I_%T_${DATE_FORMAT}_%s_%p_%t.bkp"
PATH_RMAN_DEFAULT="/data/orabackup/#ORACLE_SID_INPUT#/rman"
FORMAT_RMAN_DEFAULT="$PATH_RMAN_DEFAULT/$FORMAT_BACKUP"
FORMAT_SNAPSHOT_CTL="snapcf_#ORACLE_SID_INPUT#"
FORMAT_SNAPSHOT_CTL_DEFAULT="/data/orabackup/#ORACLE_SID_INPUT#/rman/$FORMAT_SNAPSHOT_CTL"

ORACLE_HOME_RMAN=/opt/oracle/product/10.2.0.5/db_1
TNS_ADMIN=/opt/oracle/product/11.2.0.3/db_1/network/admin

export CATALOG_SID=oraref1pb
PID_PMON="`ps -ef|grep ora_pmon_${CATALOG_SID}|grep -v grep|awk '{print $2}'`"
export ORACLE_HOME="`cat /proc/${PID_PMON}/environ|tr '\0' '\n'|grep ORACLE_HOME|awk -F= '/ORACLE_HOME/{print $2}'|uniq`"
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:$LD_LIBRARY_PATH




#--------------------------------------------------------------------------------------------
# fonctions
#--------------------------------------------------------------------------------------------
affiche_param_file()
{
  echo -e "\n\n-----------------------------------------------------------"
  echo -e "Parameters of the parameter file:\n"
  echo -e "Mandatory parameters :"
  echo -e "-sid                         : SID of a started database on this server"
  echo -e "-parallel                    : Numeric value"
  echo -e "-target                      : target database connect string : user/password@tns_entry"
  echo -e "-window or -redundancy : recovery window days number or recovery redundancy backup number\n"
  echo -e "\nOptional parameter:"
  echo -e "-backup_path           : backups directory on disk, default value = $FORMAT_RMAN_DEFAULT\n"
  echo -e "-compress              : Y (default)or N\n"
  echo -e "-maxpiece              : Maximum size of a backupset en GBytes (default unlimited)\n"
  echo -e "-autobackup            : Autobackup controlfile Y or N (default)\n"
  echo -e "-log_path              : Rman log directory, default value = no log produce by rman\n"
}


affiche_param_global()
{
  echo -e "\n\n-----------------------------------------------------------"
  echo -e "You must give these GLOBAL parameters in the parameter file, following the label GLOBAL_PARAMETERS at the begining of the line:"
  echo -e "-email_list : email where will be send the error messages, multi addresses must be separated by a comma, not a blank"
  echo -e "-catalog    : catalog string connextion , for example rmancat/xxxx@oraref1p"
  echo -e "\n\nExample of a global parameters line :"
  echo -e "GLOBAL_PARAMETERS -email_list toto@titi.fr -catalog rmancat/xxxx@oraref1p\n"
}


affiche_param_line()
{
  echo -e "\n\n-----------------------------------------------------------"
  echo -e "You must give 3 parameters on the command line:"
  echo -e "-type      : FULL, CUMULATIF, INCREMENTAL, ARCHIVELOG" 
  echo -e "-sid       : SID of the database you want to backup on this server"
  echo -e "-paramfile : location of the parameter file containing the backup parameter"
}



# in order they appear in the functions ==> can be set even a problem happens before they are read
export PARAM1=$2
export PARAM2=$4
#


send_email()
{
#  echo "$1"|mail -s "Probleme backup rman $PARAM1 $PARAM2" "$EMAIL_LIST_INPUT"
#  echo -e "$2"|mail -s "$1 database $PARAM1 backup $PARAM2"  s.nottet@pixmania-group.com jean-pierre.carret@easyteam.fr
#  echo -e "$2"|mail -s "$1 database $PARAM1 backup $PARAM2"  s.nottet@pixmania-group.com

   echo -e "$2"|mail -s "$1 database $PARAM1 backup $PARAM2"  "$EMAIL_LIST_INPUT"
}

pb_exit1()
{ 
  send_email "Probleme backup rman" "$1"
  exit 1
}
#
#--------------------------------------------------------------------------------------------
# getting the input parameters
#--------------------------------------------------------------------------------------------

# -ne 6 because we have the type of param and the param
if [ "$#" -ne 6 ];then
  affiche_param_line
  affiche_param_file
  pb_exit1 "No enough parameters on the parameter line"
fi



while [ $# -gt 1 ] ; do
case $1 in
-sid)       SID_PARAM=$2 ; shift 2 ;;
-type)      BACKUP_TYPE_INPUT=$2 ;    shift 2 ;;
-paramfile) FIC_PARAM=$2 ;     shift 2 ;;
*)            echo "Command parameter $1 is not correct";affiche_param_file;pb_exit1 "Command parameter $1 is not correct";;
esac
done


FIC_OUTPUT=$WORK_DIR_LOG/RMAN_${SID_PARAM}.output
exec >$FIC_OUTPUT
exec 2>&1


if [ ! -e "$FIC_PARAM" ];then
  echo -e "\n\nThe parameter file $FIC_PARAM doesnt exist\n\n"
   pb_exit1 "The parameter file $FIC_PARAM doesnt exist"
fi


#--------------------------------------------------------------------------------------------
# reading the parameter file in order to find the global parameters
#--------------------------------------------------------------------------------------------
PARAM_GLOBAL_LINE=""

PARAM_GLOBAL_LINE="`sed -n 's/GLOBAL_PARAMETERS\(.*\)/\1/p' $FIC_PARAM`"
set -- $PARAM_GLOBAL_LINE
while [ $# -gt 1 ] ; do
case $1 in
-email_list)      EMAIL_LIST_INPUT=$2; shift 2 ;;
-catalog)        CONNECT_CAT_INPUT=$2  ; shift 2 ;;
*)            affiche_param_global;pb_exit1 "Incorrect GLOBAL parameter $1 in file parameter";;
esac
done


if [ "$EMAIL_LIST_INPUT" = "" ]; then affiche_param_file;pb_exit1 "mandatory parameter email list is missing";fi
if [ "$CONNECT_CAT_INPUT" = "" ];then affiche_param_file;pb_exit1 "mandatory parameter connect string catalog is missing";fi


#--------------------------------------------------------------------------------------------
# reading the parameter file in order to find the SID given like a parameter
#--------------------------------------------------------------------------------------------
SID_LINE=""

while read line
do 
  # no interpretation of - in the line options
  SID_READ="`echo $line|sed -n "s/-sid \($SID_PARAM\) .*$/\1/p"`"
  if [ "$SID_READ" = "$SID_PARAM" ];then
     if [ "$SID_LINE" != "" ];then
        echo -e "\n\nSID $SID_LINE in double in parameter file $FIC_PARAM\n\n"
        pb_exit1 "SID $SID_LINE in double in parameter file $FIC_PARAM"
     fi
     SID_LINE=$SID_PARAM
     set -- $line
  fi
done <$FIC_PARAM


if [ "$SID_LINE" = "" ];then
  echo -e "\nThe sid given on the argument line doesn't exist in the parameter file\n\n"
  pb_exit1 "The sid given on the argument line doesn't exist in the parameter file"
fi 



#--------------------------------------------------------------------------------------------
# Checking if an other backup exist for the same database and in this case we exist
# the lock file is normally deleted at the end of this script
#--------------------------------------------------------------------------------------------
FIC_LOCK=$WORK_DIR_TMP/RMAN_${SID_PARAM}.lock
FIC_TRACE_PROV=$WORK_DIR_LOG/suivi_priorite.log

mkdir -p $WORK_DIR_TMP || pb_exit1 "Can't create directory: $WORK_DIR_TMP"
if [ ! -f $FIC_LOCK ];then #1
	 touch $FIC_LOCK || pb_exit1 "Can't create the lock file: $FIC_LOCK"
     echo "$$ $BACKUP_TYPE_INPUT" > $FIC_LOCK
#
elif [ -f $FIC_LOCK ];then # IF 1
  INPROGRESS_PROCESS_ID="`awk '{print $1}' $FIC_LOCK`"
  INPROGRESS_BACKUP_TYPE="`awk '{print $2}' $FIC_LOCK`"
  PID_INPROGRESS_BACKUP="`ps -ef|grep -v grep|grep $INPROGRESS_PROCESS_ID|awk -v PROCESS_ID=$INPROGRESS_PROCESS_ID '{if($2==PROCESS_ID){print $2}}'`"
    #####################
    # getting the situation
    #####################
  case $INPROGRESS_BACKUP_TYPE in
      FULL|full)              BACKUP_CURRENT_WEIGHT=8;;
      FULL0|full0)            BACKUP_CURRENT_WEIGHT=8;;
      FULLS|fulls)            BACKUP_CURRENT_WEIGHT=8;;
      CUMULATIF|cumulatif)    BACKUP_CURRENT_WEIGHT=4;;
      INCREMENTAL|incremental)BACKUP_CURRENT_WEIGHT=2;;
      ARCHIVELOG|archivelog)  BACKUP_CURRENT_WEIGHT=0;;
      *)         echo -e "\nin progress Backup type parameter $INPROGRESS_BACKUP_TYPE is not correct";;
  esac

  case $BACKUP_TYPE_INPUT in
      FULL|full)              BACKUP_CANDIDAT_WEIGHT=8;;
      FULL0|full0)            BACKUP_CANDIDAT_WEIGHT=8;;
      FULLS|fulls)            BACKUP_CANDIDAT_WEIGHT=8;;
      CUMULATIF|cumulatif)    BACKUP_CANDIDAT_WEIGHT=4;;
      INCREMENTAL|incremental)BACKUP_CANDIDAT_WEIGHT=2;;
      ARCHIVELOG|archivelog)  BACKUP_CANDIDAT_WEIGHT=0;;
      *)         echo -e "\ncandidate Backup type parameter $BACKUP_TYPE_INPUT is not correct";;
  esac



    #####################
    # making a decision
    #####################
  PERE_PID=0
  if [ "$PID_INPROGRESS_BACKUP" = "" ];then  #2
     echo "$$ $BACKUP_TYPE_INPUT" > $FIC_LOCK
     PERE_PID=0
  #
  #
  elif [ $BACKUP_CANDIDAT_WEIGHT -eq $BACKUP_CURRENT_WEIGHT ];then
     # the father is the father of candidate process linux
     PERE_PID="$PPID"
     MEMO_ACTION="lancement du backup job $BACKUP_TYPE_INPUT de la base $SID_PARAM alors que le backup $INPROGRESS_BACKUP_TYPE est en cours,\nle backup $INPROGRESS_BACKUP_TYPE en cours est conserve,le backup nouvellement lance est stoppe"
  #
  #
  elif [ $BACKUP_CANDIDAT_WEIGHT -gt $BACKUP_CURRENT_WEIGHT ];then
     # writing information in file
     echo "$$ $BACKUP_TYPE_INPUT" > $FIC_LOCK
     # the father is the father of active process linux doing an rman backup
     PERE_PID="`ps -p $PID_INPROGRESS_BACKUP -o ppid|tail -1`"
     MEMO_ACTION="lancement du backup job $BACKUP_TYPE_INPUT de la base $SID_PARAM alors que le backup $INPROGRESS_BACKUP_TYPE est en cours,\nle backup $INPROGRESS_BACKUP_TYPE est stoppe"
  #
  #
  elif [ $BACKUP_CANDIDAT_WEIGHT -lt $BACKUP_CURRENT_WEIGHT ];then
     # the father is the father of candidate process linux
     PERE_PID="$PPID"
     MEMO_ACTION="lancement du backup job $BACKUP_TYPE_INPUT de la base $SID_PARAM alors que le backup $INPROGRESS_BACKUP_TYPE est en cours,\nle backup $BACKUP_TYPE_INPUT est stoppe"
  fi #2


    #####################
    # possibly stopping the scheduler job 
    #####################
  # kill of the maching process id <=> scheduler job name
  if [ "$PID_INPROGRESS_BACKUP" != "" ];then
      GRAND_PERE_PID="`ps -ef|grep extjobo|grep $PERE_PID|awk '{print $10}'`"
      export ORACLE_SID=$CATALOG_SID
      COMMANDE="
      set pages 0
      set head off
      set feedback off
      select 'exec DBMS_SCHEDULER.stop_job(job_name =>'''||job_name||''',force=>true);'||chr(10)||'exit'
      from dba_scheduler_running_jobs where SLAVE_OS_PROCESS_ID='${GRAND_PERE_PID}';
      exit"
      COMMANDE_STOP_JOB="`echo "$COMMANDE"|sqlplus -s / as sysdba`"
      sleep 1
      echo "`date` $MEMO_ACTION">> $FIC_TRACE_PROV
      echo "`date` command executee :\n $COMMANDE_STOP_JOB">> $FIC_TRACE_PROV
      send_email "Probleme de scheduler job rman due a un chevauchement de jobs" "Chevauchement detecte : \n$MEMO_ACTION\n\nLa commande d arret a ete  $COMMANDE_STOP_JOB"
      echo "$COMMANDE_STOP_JOB"|sqlplus -s / as sysdba
  fi

fi #1

#--------------------------------------------------------------------------------------------
# reading the parameter get from the line matching the ORACLE_SID given like a parameter
# in the file parameter
#--------------------------------------------------------------------------------------------
echo -e "\n\nParameter line read : $*\n"

while [ $# -gt 1 ] ; do
case $1 in
-sid)              ORACLE_SID_INPUT=$2 ; shift 2 ;;
-parallel)         PARALLEL_INPUT=$2    ; shift 2 ;;
-target)           CONNECT_TAR_INPUT=$2  ; shift 2 ;;
-backup_path)      PATH_INPUT=$2 ;        shift 2 ;;
-compress)         COMPRESSION_INPUT=$2 ; shift 2 ;;
-maxpiece)         MAXSETSIZE_INPUT=$2 ;   shift 2 ;;
-autobackup)       AUTOBACKUP_INPUT=$2 ;  shift 2 ;;
-window)           RETTYPE_WINDOW_INPUT="WINDOW";RETTYPE_INPUT=$2 ;  shift 2 ;;
-redundancy)       RETTYPE_REDUNDANCY_INPUT="REDUNDANCY";RETTYPE_INPUT=$2 ;  shift 2 ;;
-log_path)         LOG_INPUT=$2 ;         shift 2 ;;
*)            affiche_param_file;pb_exit1 "Incorrect parameter $1 in file parameter";;
esac
done
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
# CHECKING MANDATORY PARAMETERS
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
if [ "$ORACLE_SID_INPUT" = "" ];         then affiche_param_file;pb_exit1 "mandatory parameter ORACLE_SID_INPUT missing";fi
if [ "$PARALLEL_INPUT" = "" ];     then affiche_param_file;pb_exit1 "mandatory parameter parallel missing";fi
if [ "$BACKUP_TYPE_INPUT" = "" ];  then affiche_param_file;pb_exit1 "mandatory parameter backup type missing";fi
if [ "$CONNECT_TAR_INPUT" = "" ];      then affiche_param_file;pb_exit1 "mandatory parameter connect string target is missing";fi
if [ "$RETTYPE_WINDOW_INPUT" = "" ] && [ "$RETTYPE_REDUNDANCY_INPUT" = "" ];then 
    affiche_param_file;pb_exit1 "mandatory parameter retention policy by WINDOW or REDUNDANCY"
fi


#--------------------------------------------------------------------------------------------
# Checking of SID parameter
#--------------------------------------------------------------------------------------------

#SID_RETOUR=$($ORACLE_HOME/bin/sqlplus -L -S /nolog <<EOF
#set pages 0
#set head off
#set feedback off
#set trims off
#connect $CONNECT_TAR_INPUT
#select name from v\$database;
#EOF)


SID_RETOUR=$(echo " 
set pages 0
set head off
set feedback off
set trims off
connect $CONNECT_TAR_INPUT 
select name from v\$database;
exit"|sqlplus -L -S /nolog|tr -d "\n")

#JP
#SID_RETOUR="`echo "
#set pages 0
#set head off
#set feedback off
#set trims off
#connect $CONNECT_TAR_INPUT
#select name from v\\$database;
#exit"|sqlplus -L -S /nolog|tr -d "\n"`"


#echo "SN -  ORACLE_SID_INPUT : $ORACLE_SID_INPUT"
#echo "SN - SID_RETOUR : $SID_RETOUR"


if [ "$ORACLE_SID_INPUT" != "$SID_RETOUR" ];then
  echo -e "\n\$ORACLE_SID_INPUT parameter doesn't match a started database\n"
  pb_exit1 "$ORACLE_SID_INPUT parameter doesn't match a started database"
fi



#--------------------------------------------------------------------------------------------
# Checking of parallelism parameter
# The parameter need to be numeric and not equal to 0
#--------------------------------------------------------------------------------------------
PARALLEL_VALUE="`echo $PARALLEL_INPUT|sed -n "/^[0-9]*$/p"`"
if [ "$PARALLEL_VALUE" = "" ] || [ "$PARALLEL_VALUE" = "0" ];then
   echo -e "\n\nParallel parameter = $PARALLEL_INPUT is not correct\n"
   affiche_param_file
   pb_exit1 "Parallel parameter = $PARALLEL_INPUT is not correct"
fi


#--------------------------------------------------------------------------------------------
# Checking of backup type
#--------------------------------------------------------------------------------------------
case $BACKUP_TYPE_INPUT in

FULL|full)              BACKUP_SCRIPT="glob_full_db_backup_nolevel";;
FULL0|full0)              BACKUP_SCRIPT="glob_full_db_backup_level0";;
FULLS|fulls)              BACKUP_SCRIPT="test_full_stby";;
CUMULATIF|cumulatif)    BACKUP_SCRIPT="glob_cum_db_backup";;
INCREMENTAL|incremental)BACKUP_SCRIPT="glob_incr_db_backup";;
ARCHIVELOG|archivelog)  BACKUP_SCRIPT="glob_archlog_backup";;
*)          echo -e "\nBackup type parameter $BACKUP_TYPE_INPUT is not correct";affiche_param_file;pb_exit1 "Backup type parameter $BACKUP_TYPE_INPUT is not correct";;
esac


FORMAT_BACKUP_VALUE="`echo $FORMAT_BACKUP|sed  "s/#BACKUP_TYPE#/${BACKUP_TYPE_INPUT}/g"`"

#--------------------------------------------------------------------------------------------
# Checking of  parameter retention policy by WINDOW or REDUNDANCY
#--------------------------------------------------------------------------------------------
# numeric test with sed
RETTYPE_VALUE="`echo $RETTYPE_INPUT|sed -n "/^[0-9]*$/p"`"
if [ "$RETTYPE_VALUE" = "" ];then
   echo -e "\n\n Retention parameter value = $RETTYPE_VALUE must to be numeric\n"
   affiche_param_file
   pb_exit1 "Retention parameter value = $RETTYPE_VALUE must to be numeric"
fi

if [ "$RETTYPE_WINDOW_INPUT" != "" ];then
   RETTYPE_WINDOW_VALUE="RECOVERY WINDOW OF $RETTYPE_VALUE days" 

elif [ "$RETTYPE_REDUNDANCY_INPUT" != "" ];then
   RETTYPE_WINDOW_VALUE="REDUNDANCY $RETTYPE_VALUE" 
fi


#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
# CHECKING OPTIONAL PARAMETERs
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------



#--------------------------------------------------------------------------------------------
# COmposition of backup path
#--------------------------------------------------------------------------------------------
ORACLE_SID_INPUT_LOWERCASE="`echo $ORACLE_SID_INPUT|awk '{print tolower($1)}'`"


if [ "$PATH_INPUT" != "" ];then


  PATH_FORMAT_VALUE="$PATH_INPUT/$FORMAT_BACKUP_VALUE"
  PATH_SNAPSHOT_CTL_VALUE="`echo $PATH_INPUT/$FORMAT_SNAPSHOT_CTL|sed  "s/#ORACLE_SID_INPUT#/${ORACLE_SID_INPUT_LOWERCASE}/g"`"
else
  PATH_FORMAT_VALUE="`echo $FORMAT_RMAN_DEFAULT|sed  "s/#ORACLE_SID_INPUT#/${ORACLE_SID_INPUT_LOWERCASE}/g"`"
  PATH_SNAPSHOT_CTL_VALUE="`echo $FORMAT_SNAPSHOT_CTL_DEFAULT|sed  "s/#ORACLE_SID_INPUT#/${ORACLE_SID_INPUT_LOWERCASE}/g"`"
fi

echo "snap=$PATH_SNAPSHOT_CTL_VALUE"

#--------------------------------------------------------------------------------------------
# Checking of compression
#--------------------------------------------------------------------------------------------

COMPRESSION_VALUE="COMPRESSED"
case $COMPRESSION_INPUT in
Y|y)        COMPRESSION_VALUE="COMPRESSED";;          
N|n)        COMPRESSION_VALUE="";;
esac


#--------------------------------------------------------------------------------------------
# Checking of maxsetsize value
# The parameter needs to be numeric
#--------------------------------------------------------------------------------------------
# numeric test with sed
MAXSETSIZE_VALUE="`echo $MAXSETSIZE_INPUT|sed -n "/^[0-9]*$/p"`"
if [ "$MAXSETSIZE_INPUT" != "" ] && [ "$MAXSETSIZE_VALUE" = "" ];then
   echo -e "\n\nMaxsetsize parameter = $MAXSETSIZE_INPUT is not correct\n"
   affiche_param_file
   pb_exit1 "Maxsetsize parameter = $MAXSETSIZE_INPUT is not correct"
fi

if [ "$MAXSETSIZE_VALUE" != "" ];then
   MAXSETSIZE_VALUE="${MAXSETSIZE_VALUE}G" 
else
   MAXSETSIZE_VALUE="UNLIMITED" 

fi


#--------------------------------------------------------------------------------------------
# Checking of autobackup controlfile
#--------------------------------------------------------------------------------------------

AUTOBACKUP_VALUE="OFF"
case $AUTOBACKUP_INPUT in
Y|y)        AUTOBACKUP_VALUE="ON";;          
N|n)        AUTOBACKUP_VALUE="OFF";;
esac


#--------------------------------------------------------------------------------------------
# Checking of log path
#--------------------------------------------------------------------------------------------
LOG_VALUE=""
if [ "$LOG_INPUT" != "" ];then
  LOG_VALUE="|tee $LOG_INPUT/rman_${ORACLE_SID_INPUT}_${BACKUP_TYPE_INPUT}.log"
fi



#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
# RMAN COMMAND CREATION
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
BOUCLE=1
while [ "$BOUCLE" -le "$PARALLEL_VALUE" ]
do
 CHANNEL_VALUE="${CHANNEL_VALUE}configure channel ${BOUCLE} device type disk format='${PATH_FORMAT_VALUE}';"
 BOUCLE=$(($BOUCLE+1))
done
echo $CHANNEL_VALUE


RMAN_COMMAND="`echo "#
configure snapshot controlfile name to '$PATH_SNAPSHOT_CTL_VALUE';
CONFIGURE CHANNEL DEVICE TYPE DISK CLEAR;
configure channel device type disk format '$PATH_FORMAT_VALUE';
configure device type disk parallelism $PARALLEL_VALUE backup type to backupset;
configure device type disk backup type to $COMPRESSION_VALUE backupset;
configure channel device type disk maxpiecesize $MAXSETSIZE_VALUE;
"$CHANNEL_VALUE"
configure controlfile autobackup ${AUTOBACKUP_VALUE};
CONFIGURE RETENTION POLICY TO ${RETTYPE_WINDOW_VALUE};
run { execute script
$BACKUP_SCRIPT;
}
resync catalog;
quit"`"

echo "COMMAND8RMAN=$RMAN_COMMAND"
#-------------------------------------------------------------------------------------------
# rman check syntax 
#--------------------------------------------------------------------------------------------
export ORACLE_HOME=$ORACLE_HOME_RMAN

sleep 2
COMMAND_RMAN="echo \"$RMAN_COMMAND\"|$ORACLE_HOME_RMAN/bin/rman checksyntax target $CONNECT_TAR_INPUT catalog $CONNECT_CAT_INPUT $LOG_VALUE"

RETOUR_RMAN="`eval "$COMMAND_RMAN"`"
echo "$RETOUR_RMAN"|egrep 'RMAN-00558'
if [ $? = 0 ];then
echo "------------------------------------------------------------------------------------------------"
 echo " RMAN SYNTAX ERROR"
 echo "------------------------------------------------------------------------------------------------"
 echo "$RETOUR_RMAN"
 pb_exit1 "$RETOUR_RMAN"
fi

#-------------------------------------------------------------------------------------------
# execution of rman command
#--------------------------------------------------------------------------------------------
sleep 2
COMMAND_RMAN="echo \"$RMAN_COMMAND\"|$ORACLE_HOME_RMAN/bin/rman target $CONNECT_TAR_INPUT catalog $CONNECT_CAT_INPUT $LOG_VALUE"
echo "Rman command : $COMMAND_RMAN"

RETOUR_RMAN="`eval "$COMMAND_RMAN"`"
echo "$RETOUR_RMAN"|egrep 'ORA-|RMAN-'
if [ $? = 0 ];then
 echo "------------------------------------------------------------------------------------------------"
 echo "------------------------------------------------------------------------------------------------"
 echo "------------------------------------------------------------------------------------------------"
 echo " RMAN ERROR RETURN"
 echo "------------------------------------------------------------------------------------------------"
 echo "------------------------------------------------------------------------------------------------"
 echo "------------------------------------------------------------------------------------------------"
 echo "erreur backup rman : $RETOUR_RMAN"

 pb_exit1 "$RETOUR_RMAN"
fi




exit 0

