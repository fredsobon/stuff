#!/bin/bash
#set -x
#
# to debug the script, put the commentary character off these two following lines
#exec 2> /opt/oracle/admin/orawork/tmp/jp.log
#set -x
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
WORK_DIR_TMP=$WORK_DIR/tmp/rman
WORK_DIR_LCK=$WORK_DIR/log/rman/lock
WORK_DIR_LOG=$WORK_DIR/log/rman/trc
WORK_DIR_ERR=$WORK_DIR/log/rman/err


mkdir -p $WORK_DIR
mkdir -p $WORK_DIR_TMP
mkdir -p $WORK_DIR_LCK
mkdir -p $WORK_DIR_LOG
mkdir -p $WORK_DIR_ERR


DATE_FORMAT="`date "+%d%m%Y%H%M"`"
FORMAT_BACKUP="%d_#BACKUP_TYPE#_dbid_%I_%T_${DATE_FORMAT}_%s_%p_%t.bkp"
#SNFORMAT_BACKUP="%d_#BACKUP_TYPE#_dbid_%I_${DATE_FORMAT}_%s_%p_%t.bkp"
DATE_FORMAT_LOG="`date +%d/%m/%Y' '%H:%M:%S`"
PATH_RMAN_DEFAULT="/data/orabackup/#ORACLE_SID_INPUT#/rman"
FORMAT_RMAN_DEFAULT="$PATH_RMAN_DEFAULT/$FORMAT_BACKUP"
FORMAT_SNAPSHOT_CTL="snapcf_#ORACLE_SID_INPUT#"
FORMAT_SNAPSHOT_CTL_DEFAULT="/data/orabackup/#ORACLE_SID_INPUT#/rman/$FORMAT_SNAPSHOT_CTL"

ORACLE_HOME_LOG=/opt/oracle/product/11.2.0.3/db_1
ORACLE_HOME_RMAN=/opt/oracle/product/10.2.0.5/db_1
TNS_ADMIN=/opt/oracle/product/11.2.0.3/db_1/network/admin

export CATALOG_SID=oraref1pb
PID_PMON="`ps -ef|grep ora_pmon_${CATALOG_SID}|grep -v grep|awk '{print $2}'`"
export ORACLE_HOME="`cat /proc/${PID_PMON}/environ|tr '\0' '\n'|grep ORACLE_HOME|awk -F= '/ORACLE_HOME/{print $2}'|uniq`"
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:$LD_LIBRARY_PATH




#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
# fonctions
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------


affiche_param_file()
{
  echo -e "\n\n-----------------------------------------------------------"
  echo -e "Parameters of the parameter file:\n"
  echo -e "Mandatory parameters :"
  echo -e "-sid                   : SID of a started database on this server"
  echo -e "-parallel              : Numeric value"
  echo -e "-target                : Target database connect string : user/password@tns_entry"
  echo -e "-window or -redundancy : Recovery window days number or recovery redundancy backup number\n"
  echo -e "-catalogmode           : Backup mode catalog or nocatalog. Y (default)or N\n"
  echo -e "-seq_ret or -tim_ret   : Nombre de sequences retenues ou Nombre d''heures de retention (Archivelog)\n"
  echo -e "-backed_arc            : Numeric value greater than zero\n"
  #-----------------------------------------------------------
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
  echo -e "-catalog    : catalog string connextion , for example rmancat/xxxx@oraref1pb"
  echo -e "\n\nExample of a global parameters line :"
  echo -e "GLOBAL_PARAMETERS -email_list toto@titi.fr -catalog rmancat/xxxx@oraref1pb\n"
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


pb_backup_exit1()
{ 
        LOG_ERR_FIC="$WORK_DIR_ERR/rman_${ORACLE_SID_INPUT}_${BACKUP_TYPE_INPUT}_${DATE_FORMAT}.err"

	echo -e "\n+--------------------------------------------------------------------------------------------------+"	> $LOG_ERR_FIC
	echo -e "+\n												      +"  	>>$LOG_ERR_FIC
	echo -e "+	Base 			: $ORACLE_SID_INPUT						      +"	>>$LOG_ERR_FIC
	echo -e "+	Log date 		: `date`							      +"	>>$LOG_ERR_FIC
	echo -e "+	Backup Type 	        : $BACKUP_TYPE_INPUT						      +"	>>$LOG_ERR_FIC
	echo -e "+\n												      +"   	>>$LOG_ERR_FIC
	echo -e "+--------------------------------------------------------------------------------------------------+\n"	>>$LOG_ERR_FIC
	
	cat $LOG_FIC >>$LOG_ERR_FIC
	
	echo -e "\n+--------------------------------------------------------------------------------------------------+\n"	>>$LOG_ERR_FIC
	echo -e "+ EOF"														>>$LOG_ERR_FIC	
	echo -e "+--------------------------------------------------------------------------------------------------+\n"	>>$LOG_ERR_FIC
	
	#SN /usr/bin/unix2dos -k $LOG_ERR_FIC #Pas d'envoi d'email de suite, pas de conversion du fichier.

	CODE_ERR="`cat $LOG_ERR_FIC | egrep 'RMAN-|ORA-'`"
	CMD_INSERT_LOG=$(echo "
        set serveroutput on
        connect $CONNECT_CAT_INPUT
        set serveroutput on
	
	begin
   		rmancat.pck_log_error.p_log_error (  p_db_name       => $ORACLE_SID_INPUT
                                    		   , p_backup_type   => $BACKUP_TYPE_INPUT
                                    		   , p_error_code    => substr($CODE_ERR, 1, 2000)
                                    		   , p_fic_err       => $LOG_ERR_FIC
                                    		   , p_backup_date   => to_date($DATE_FORMAT_LOG, 'dd/mm/yyyy hh24:mi:ss')
                                     		  );
	exception
	   when others then
	      raise;
	end;
	/
	exit;" | $ORACLE_HOME/bin/sqlplus -silent /nolog )


	#Erreur lors de la log dans la table. #SN
	ERRORS=$(echo -e $CMD_INSERT_LOG | grep 'ORA-' | grep -v '^$') 
        if [ -n "$ERRORS" ];then
		(echo -e "\nErreur : Backup $PARAM2 database $PARAM1\nImpossible de logger dans la base.\nVoir Fichier ci-joint."; /usr/bin/uuencode $LOG_ERR_FIC ${ORACLE_SID_INPUT}_${BACKUP_TYPE_INPUT}.err )   | mail -s "Erreur : Backup $PARAM2 database $PARAM1" "$EMAIL_LIST_INPUT"
        fi

	exit 1
}



#Sylvie Nottet - 25/01/2013
purge_archivelogs_files_cat()
{
 	#echo -e "--------------------------------------------------------------------------------------------">>$LOG_FIC
	echo -e "Purge des archivelogs sur $ORACLE_SID_INPUT 	    	     		      "		      >>$LOG_FIC	
 	echo -e "--------------------------------------------------------------------------------------------">>$LOG_FIC

CMD_PURGE=$(echo "set linesize 800
set serveroutput on
set pages 0
set head off
set feedback off
set trims off
set serveroutput on
connect $CONNECT_TAR_INPUT as sysdba
set serveroutput on

declare
      is_dataguard                integer := 0;
      v_sequence_ret_default      number := 10;
      v_backed_default            number := 1;
      v_time_retention            number := NVL ($RETTYPE_ARC_VALUE, 0);
      v_sequence_retention        number := NVL ($RETTYPE_ARC_VALUE, 0);
      v_backed                    number := NVL ($BACKED_VALUE, v_backed_default);
      v_role                      varchar2 (32000) := 'NOT DATA GUARD';
      v_comments                  varchar2 (32000);
   begin
      DBMS_OUTPUT.put_line ('CMD:SPOOL LOG TO $LOG_FIC append;\n');
      DBMS_OUTPUT.put_line ('CMD:crosscheck archivelog all;\n');

      select   COUNT ( * )
        into   is_dataguard
        from   v\$archive_dest d
       where   status not in ('INACTIVE', 'DEFERRED', 'ERROR', 'BAD PARAM', 'ALTERNATE', 'FULL') and target in ('STANDBY', 'REMOTE');


      if is_dataguard > 0 then
         v_comments                 := 'INFO: Identification de la cible => Environnement Data guard.';

         select   UPPER (database_role) into v_role from v\$database;

         v_comments                 := 'INFO: Database Cible de la sauvegarde => ' || v_role;


         if v_role = 'PRIMARY' then
            for seq in (  select   thread# as thread, MIN (sequence#) sequence
                            from   (  select   a.thread#
                                             , a.dest_id
                                             , MAX (a.sequence#) sequence#
                                        from   v\$archived_log a, v\$archive_dest_status t
                                       where   a.applied = 'YES' and t.status = 'VALID' and a.dest_id = t.dest_id
                                    group by   a.thread#, a.dest_id)
                        group by   thread#)
            loop
               case
                  when v_sequence_retention > 0 and v_backed > 0 then
                     DBMS_OUTPUT.put_line(   'CMD:delete noprompt archivelog until sequence='
                                          || (seq.sequence - v_sequence_retention)
                                          || ' thread '
                                          || seq.thread
                                          || ' backed up '
                                          || v_backed
                                          || ' times to device type disk;\n');
                  when v_sequence_retention > 0 and v_backed <= 0 then
                     DBMS_OUTPUT.put_line(   'CMD:delete noprompt archivelog until sequence='
                                          || (seq.sequence - v_sequence_retention)
                                          || ' thread '
                                          || seq.thread
                                          || ';\n');
                  else
                     DBMS_OUTPUT.put_line(   'CMD:delete noprompt archivelog until sequence='
                                          || (seq.sequence - v_sequence_ret_default)
                                          || ' thread '
                                          || seq.thread
                                          || ' backed up '
                                          || v_backed
                                          || ' times to device type disk;\n');
               end case;
            end loop;
         elsif v_role <> 'PRIMARY' then
            for seq in (  select   MAX (sequence#) sequence, thread# thread
                            from   v\$archived_log
                           where   applied = 'YES' and registrar = 'RFS'
                        group by   thread#)
            loop
               case
                  when v_sequence_retention > 0 and v_backed > 0 then
                     DBMS_OUTPUT.put_line(   'CMD:delete noprompt archivelog until sequence='
                                          || (seq.sequence - v_sequence_retention)
                                          || ' thread '
                                          || seq.thread
                                          || ' backed up '
                                          || v_backed
                                          || ' times to device type disk;\n');
                  when v_sequence_retention > 0 and v_backed <= 0 then
                     DBMS_OUTPUT.put_line(   'CMD:delete noprompt archivelog until sequence='
                                          || (seq.sequence - v_sequence_retention)
                                          || ' thread '
                                          || seq.thread
                                          || ';\n');
                  else
                     DBMS_OUTPUT.put_line(   'CMD:delete noprompt archivelog until sequence='
                                          || (seq.sequence - v_sequence_ret_default)
                                          || ' thread '
                                          || seq.thread
                                          || ' backed up '
                                          || v_backed
                                          || ' times to device type disk;\n');
               end case;
            end loop;
         end if;
      else
         v_role                     := 'INFO: Database Cible de la sauvegarde => NOT DATA GUARD CONFIGURATION';
         v_comments                 := 'INFO: Database Cible de la sauvegarde => NOT DATA GUARD CONFIGURATION';


         case
            when v_time_retention > 0 and v_backed > 0 then
               DBMS_OUTPUT.put_line(   'CMD:delete noprompt archivelog until time=''sysdate-'
                                    || v_time_retention
                                    || '/24'' backed up '
                                    || v_backed
                                    || ' times to device type disk;\n');
            when v_time_retention > 0 and v_backed <= 0 then
               DBMS_OUTPUT.put_line ('CMD:delete noprompt archivelog until time=''sysdate-' || v_time_retention || '/24'';\n');
            else
               DBMS_OUTPUT.put_line ('CMD:delete noprompt archivelog until time=''sysdate-1''  backed up '||v_backed ||' times to device type disk;\n');
         end case;

         DBMS_OUTPUT.put_line ( v_role || '.\n');
         DBMS_OUTPUT.put_line ( v_comments || '.\n');


    end if;


      DBMS_OUTPUT.put_line ('CMD:delete noprompt expired archivelog all;\n');
      DBMS_OUTPUT.put_line ('CMD:SPOOL LOG OFF;\n');

exception
   when others then
      DBMS_OUTPUT.put_line ('ORAERR : ' || SQLCODE || ' ' || SQLERRM);
end;
/
exit;" | $ORACLE_HOME/bin/sqlplus -silent /nolog )



	export ORACLE_HOME=$ORACLE_HOME_RMAN
	ERRORS=$(echo -e $CMD_PURGE | grep ORAERR)									
	COMMENTS=$(echo -e $CMD_PURGE | grep INFO |  sed -re 's/^[[:space:]]*INFO://')
	RMAN_COMMAND_PURGE=$(echo -e $CMD_PURGE | grep CMD |  sed -re 's/^[[:space:]]*CMD://')
	RMAN_COMMAND_PURGE_SYNTAX="echo \"${RMAN_COMMAND_PURGE}\"|$ORACLE_HOME_RMAN/bin/rman checksyntax target $CONNECT_TAR_INPUT catalog $CONNECT_CAT_INPUT"


	echo -e "INFO			: ${COMMENTS}"		 	>>$LOG_FIC
	echo -e "ERREUR			: ${ERRORS}"		 	>>$LOG_FIC
	echo -e "CMD_PURGE 		: $CMD_PURGE "
	echo "#-------------------------------------------------------------------------------------------"
	echo -e "Erreur Oracle : $ERROR"
	echo -e "Commande(s) executee(s): $RMAN_COMMAND_PURGE" 
	echo -e "Comments : $COMMENTS"
	echo "#-------------------------------------------------------------------------------------------"

#-------------------------------------------------------------------------------------------
#Check RMAN syntax purge Command
#-------------------------------------------------------------------------------------------
        echo -e "--------------------------------------------------------------------------------------------"      >> "$LOG_FIC"
        echo -e "Check syntax de la commande RMAN executee pour la purge : "                 			    >> "$LOG_FIC"
        echo -e "--------------------------------------------------------------------------------------------"      >> "$LOG_FIC"
        echo -e "${RMAN_COMMAND_PURGE}"                 							    >> "$LOG_FIC"
        echo -e "--------------------------------------------------------------------------------------------"      >> "$LOG_FIC"
	RETOUR_RMAN="`eval "$RMAN_COMMAND_PURGE_SYNTAX"`"

	echo "`cat $LOG_FIC`"|egrep 'RMAN-00558'
	if [ $? = 0 ];then
		echo -e "\n"	>>$LOG_FIC
		echo -e "x ------------------------------------------------------------------------------------------------">>$LOG_FIC
		echo -e "x RMAN SYNTAX ERROR RETURN FOR PURGE ARCHIVE LOG :						   ">>$LOG_FIC
		echo -e "x $RETOUR_RMAN"										    >>$LOG_FIC
		echo -e "x ------------------------------------------------------------------------------------------------">>$LOG_FIC
		pb_exit1 "$RETOUR_RMAN"
        else
#                echo -e "------------------------------------------------------------------------------------------------  ">> "$LOG_FIC"
                echo -e "Fin check syntax de la commande RMAN pour la purge des archivelogs	                           ">> "$LOG_FIC"
                echo -e "------------------------------------------------------------------------------------------------  ">> "$LOG_FIC"
	fi


#-------------------------------------------------------------------------------------------
# execution of rman command for the delete of archives
#--------------------------------------------------------------------------------------------
 	echo -e "--------------------------------------------------------------------------------------------"      >> "$LOG_FIC"
        echo -e "Execution de la purge des archives                          "      				    >> "$LOG_FIC"
        echo -e "--------------------------------------------------------------------------------------------"      >> "$LOG_FIC"

	RMAN_COMMAND_PURGE_EXEC="echo \"$RMAN_COMMAND_PURGE\"|$ORACLE_HOME_RMAN/bin/rman target $CONNECT_TAR_INPUT catalog $CONNECT_CAT_INPUT"
	RETOUR_RMAN="`eval "$RMAN_COMMAND_PURGE_EXEC"`"

	echo "`cat $LOG_FIC`"|egrep 'ORA-|RMAN-'
	if [ $? = 0 ];then
		echo -e "x ------------------------------------------------------------------------------------------------ ">>$LOG_FIC
		echo -e "x RMAN ERROR RETURN DURING PURGE ARCHIVE LOG :							    ">>$LOG_FIC
		echo -e "x $RETOUR_RMAN"										     >>$LOG_FIC
		echo -e "x ------------------------------------------------------------------------------------------------ ">>$LOG_FIC
		pb_exit1 "$RETOUR_RMAN"
        else
                echo -e "------------------------------------------------------------------------------------------------">> "$LOG_FIC"
                echo -e "Fin de la purge des archivelogs.	                             				 ">> "$LOG_FIC"
                echo -e "------------------------------------------------------------------------------------------------">> "$LOG_FIC"
	fi

	exit 0
}


retention_policy_on_primary ()
{
	RMAN_PRIMARY_COMMAND="`echo "#
	SPOOL LOG TO '$LOG_FIC' append;	
	CONFIGURE RETENTION POLICY TO ${RETTYPE_WINDOW_VALUE};
	SPOOL LOG OFF;
	quit"`"

	DATAGUARD=$(echo "set linesize 800
	set pages 0
	set head off
	set feedback off
	set trims off
	connect $CONNECT_TAR_INPUT as sysdba
	select   COUNT ( * )
	from   v\$archive_dest d
	where   status not in ('INACTIVE', 'DEFERRED', 'ERROR', 'BAD PARAM', 'ALTERNATE', 'FULL') and target in ('STANDBY', 'REMOTE');
	exit;" | $ORACLE_HOME/bin/sqlplus -silent /nolog )

	if [ "$DATAGUARD" -lt "0" ]; then
	#Si l on est dans une configuration data guard
		COMMAND_RMAN_PRIMARY="echo \"$RMAN_PRIMARY_COMMAND\"|$ORACLE_HOME_RMAN/bin/rman target $CONNECT_TAR_INPUT catalog $CONNECT_CAT_INPUT"
		RETOUR_RMAN_PRIMARY="`eval "$COMMAND_RMAN_PRIMARY"`"
		
		echo "`cat $LOG_FIC`"|egrep 'ORA-|RMAN-'
		if [ $? = 0 ];then
			echo -e "x --------------------------------------------------------------------------------------------" >> "$LOG_FIC"
			echo -e "x RMAN ERROR RETURN :"                                                                          >> "$LOG_FIC"
			echo -e "x $RETOUR_RMAN_PRIMARY"                                                                         >> "$LOG_FIC"
			echo -e "x --------------------------------------------------------------------------------------------" >> "$LOG_FIC"
			pb_exit1 "$RETOUR_RMAN_PRIMARY"
		else
			echo -e "--------------------------------------------------------------------------------------------"  >> "$LOG_FIC"
			echo -e "Fin de l execution du backup $BACKUP_TYPE_INPUT.                                       "       >> "$LOG_FIC"
			echo -e "--------------------------------------------------------------------------------------------"  >> "$LOG_FIC"
		fi	
	fi
}


backup_database_catalog ()
{
 	echo -e "+----------------------------------------------------------------------------------------------------+"        > $LOG_FIC
        echo -e "+                                                                                                    +"        >>$LOG_FIC
	echo -e "+                 Backup RMAN                                                                        +"	>>$LOG_FIC
        echo -e "+                 Base de données     : $ORACLE_SID_INPUT                                             "        >>$LOG_FIC
        echo -e "+                 Log date            : `date`                                                        "        >>$LOG_FIC
	echo -e "+                 Mode                : Catalog                                                      +"	>>$LOG_FIC
        echo -e "+                 Backup Type         : `echo $BACKUP_TYPE_INPUT | cut -d_ -f1`                       "        >>$LOG_FIC
        echo -e "+                                                                                                    +"        >>$LOG_FIC
        echo -e "+----------------------------------------------------------------------------------------------------+\n\n"    >>$LOG_FIC


	BOUCLE=1
	while [ "$BOUCLE" -le "$PARALLEL_VALUE" ]
	do
	 #SNCHANNEL_VALUE="${CHANNEL_VALUE}configure channel ${BOUCLE} device type disk format='${PATH_FORMAT_VALUE}';"
	 CHANNEL_VALUE="${CHANNEL_VALUE} ALLOCATE channel disk${BOUCLE} device type disk format='${PATH_FORMAT_VALUE}';"
	 BOUCLE=$(($BOUCLE+1))
	done
	echo $CHANNEL_VALUE
	
	#SN : retention_policy_on_primary

	RMAN_COMMAND="`echo "#
	SPOOL LOG TO '$LOG_FIC' append;
	CONFIGURE snapshot controlfile name to '$PATH_SNAPSHOT_CTL_VALUE';
	CONFIGURE CHANNEL DEVICE TYPE DISK CLEAR;
	CONFIGURE device type disk parallelism $PARALLEL_VALUE backup type to backupset;
	CONFIGURE device type disk backup type to $COMPRESSION_VALUE backupset;
	CONFIGURE channel device type disk maxpiecesize $MAXSETSIZE_VALUE;
	CONFIGURE controlfile autobackup ${AUTOBACKUP_VALUE};
	run { 
	"$CHANNEL_VALUE"
	execute script
	$BACKUP_SCRIPT;
	}
	resync catalog;
	SPOOL LOG OFF;
	quit"`"

	#RMAN_COMMAND="`echo "#
	#SPOOL LOG TO '$LOG_FIC' append;
	#configure snapshot controlfile name to '$PATH_SNAPSHOT_CTL_VALUE';
	#CONFIGURE CHANNEL DEVICE TYPE DISK CLEAR;
	#configure channel device type disk format '$PATH_FORMAT_VALUE';
	#configure device type disk parallelism $PARALLEL_VALUE backup type to backupset;
	#configure device type disk backup type to $COMPRESSION_VALUE backupset;
	#configure channel device type disk maxpiecesize $MAXSETSIZE_VALUE;
	#"$CHANNEL_VALUE"
	#configure controlfile autobackup ${AUTOBACKUP_VALUE};
	#run { execute script
	#$BACKUP_SCRIPT;
	#}
	#resync catalog;
	#SPOOL LOG OFF;
	#quit"`"


	#-------------------------------------------------------------------------------------------
	# rman check syntax for the backup execution.
	#--------------------------------------------------------------------------------------------
	export ORACLE_HOME=$ORACLE_HOME_RMAN
	echo -e "--------------------------------------------------------------------------------------------" 	>> "$LOG_FIC"
	echo -e "Check syntax de la commande RMAN executee pour le backup : "		     			>> "$LOG_FIC"
	echo -e "--------------------------------------------------------------------------------------------" 	>> "$LOG_FIC"
	echo -e "$RMAN_COMMAND \n"										>> "$LOG_FIC"
	echo -e "--------------------------------------------------------------------------------------------" 	>> "$LOG_FIC"


	sleep 2
	COMMAND_RMAN="echo \"$RMAN_COMMAND\"|$ORACLE_HOME_RMAN/bin/rman checksyntax target $CONNECT_TAR_INPUT catalog $CONNECT_CAT_INPUT"
	RETOUR_RMAN="`eval "$COMMAND_RMAN"`"

	echo "`cat $LOG_FIC`"|egrep 'RMAN-00558'
	if [ $? = 0 ];then
		echo -e "x --------------------------------------------------------------------------------------------">> "$LOG_FIC"
		echo -e "x RMAN SYNTAX ERROR RETURN :"									>> "$LOG_FIC"
		echo -e "x $RETOUR_RMAN"										>> "$LOG_FIC"
		echo -e "x --------------------------------------------------------------------------------------------">> "$LOG_FIC"
		pb_exit1 "$RETOUR_RMAN"
	else
		echo -e "\n"											       >> "$LOG_FIC"
		echo -e "---------------------------------------------------------------------------------------------">> "$LOG_FIC"
		echo -e "Fin check syntax de la commande RMAN pour le backup $BACKUP_TYPE_INPUT."		       >> "$LOG_FIC"
		echo -e "---------------------------------------------------------------------------------------------">> "$LOG_FIC"
	fi


	#-------------------------------------------------------------------------------------------
	# execution of rman command for the backup.
	#--------------------------------------------------------------------------------------------
	echo -e "\n"												>> "$LOG_FIC"
	echo -e "--------------------------------------------------------------------------------------------" 	>> "$LOG_FIC"
	echo -e "Execution du backup $BACKUP_TYPE_INPUT " 							>> "$LOG_FIC"
	echo -e "--------------------------------------------------------------------------------------------" 	>> "$LOG_FIC"

	sleep 2
set -x
	COMMAND_RMAN="echo \"$RMAN_COMMAND\"|$ORACLE_HOME_RMAN/bin/rman target $CONNECT_TAR_INPUT catalog $CONNECT_CAT_INPUT"
	RETOUR_RMAN_BACKUP="`eval "$COMMAND_RMAN"`"
	## EXEC BACKUP

	echo "`cat $LOG_FIC`"|egrep 'ORA-|RMAN-'
	if [ $? = 0 ];then
		echo -e "x --------------------------------------------------------------------------------------------">> "$LOG_FIC"
		echo -e "x RMAN ERROR RETURN :"										>> "$LOG_FIC"
		echo -e "x $RETOUR_RMAN_BACKUP"										>> "$LOG_FIC"
		echo -e "x --------------------------------------------------------------------------------------------">> "$LOG_FIC"
		 pb_exit1 "$RETOUR_RMAN_BACKUP"
	else
#		echo -e "--------------------------------------------------------------------------------------------" 	>> "$LOG_FIC"
		echo -e "Fin de l execution du backup $BACKUP_TYPE_INPUT.					"	>> "$LOG_FIC"
		echo -e "--------------------------------------------------------------------------------------------" 	>> "$LOG_FIC"
	fi


	#S'il s'agit d'un backup des archivelogs, on procède à la purge de ceux-ci
	case $BACKUP_TYPE_INPUT in
	     ARCHIVELOG_P|archivelog_p|ARCHIVELOG_S|archivelog_s)  	purge_archivelogs_files_cat;;
	     *)	echo -e "\nBackup Type : $BACKUP_TYPE_INPUT";;
	esac
	exit 0
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
		-email_list)     EMAIL_LIST_INPUT=$2; shift 2 ;;
		-catalog)       CONNECT_CAT_INPUT=$2  ; shift 2 ;;
		*)            	affiche_param_global;pb_exit1 "Incorrect GLOBAL parameter $1 in file parameter";;
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
# Checking if an other backup exist for the same database and in this case we exit
# the lock file is normally deleted at the end of this script
#--------------------------------------------------------------------------------------------
FIC_LOCK=$WORK_DIR_LCK/RMAN_${SID_PARAM}.lock
FIC_TRACE_PROV=$WORK_DIR_LOG/suivi_priorite.log

if [ ! -f $FIC_LOCK ];then #1
     echo "$$ $BACKUP_TYPE_INPUT" > $FIC_LOCK

elif [ -f $FIC_LOCK ];then # IF 1
  INPROGRESS_PROCESS_ID="`awk '{print $1}' $FIC_LOCK`"
  INPROGRESS_BACKUP_TYPE="`awk '{print $2}' $FIC_LOCK`"
  PID_INPROGRESS_BACKUP="`ps -ef|grep -v grep|grep $INPROGRESS_PROCESS_ID|awk -v PROCESS_ID=$INPROGRESS_PROCESS_ID '{if($2==PROCESS_ID){print $2}}'`"
    #####################
    # getting the situation
    #####################
  case $INPROGRESS_BACKUP_TYPE in
      FULL_P|full_p)          		BACKUP_CURRENT_WEIGHT=8;;
      FULL_S|full_s)          		BACKUP_CURRENT_WEIGHT=8;;
      FULL0_P|full0_p)         		BACKUP_CURRENT_WEIGHT=8;;
      FULL0_S|full0_s)         		BACKUP_CURRENT_WEIGHT=8;;
      CUMULATIF_P|cumulatif_p)    	BACKUP_CURRENT_WEIGHT=4;;
      CUMULATIF_S|cumulatif_s)    	BACKUP_CURRENT_WEIGHT=4;;
      INCREMENTAL_P|incremental_p)	BACKUP_CURRENT_WEIGHT=2;;
      INCREMENTAL_S|incremental_s)	BACKUP_CURRENT_WEIGHT=2;;
      ARCHIVELOG_P|archivelog_p)  	BACKUP_CURRENT_WEIGHT=0;;
      ARCHIVELOG_S|archivelog_s)  	BACKUP_CURRENT_WEIGHT=0;;
      *)         echo -e "\nin progress Backup type parameter $INPROGRESS_BACKUP_TYPE is not correct";;
  esac

  case $BACKUP_TYPE_INPUT in
      FULL_P|full_p)                    BACKUP_CURRENT_WEIGHT=8;;
      FULL_S|full_s)                    BACKUP_CURRENT_WEIGHT=8;;
      FULL0_P|full0_p)                  BACKUP_CURRENT_WEIGHT=8;;
      FULL0_S|full0_s)                  BACKUP_CURRENT_WEIGHT=8;;
      CUMULATIF_P|cumulatif_p)          BACKUP_CURRENT_WEIGHT=4;;
      CUMULATIF_S|cumulatif_s)          BACKUP_CURRENT_WEIGHT=4;;
      INCREMENTAL_P|incremental_p)      BACKUP_CURRENT_WEIGHT=2;;
      INCREMENTAL_S|incremental_s)      BACKUP_CURRENT_WEIGHT=2;;
      ARCHIVELOG_P|archivelog_p)        BACKUP_CURRENT_WEIGHT=0;;
      ARCHIVELOG_S|archivelog_s)        BACKUP_CURRENT_WEIGHT=0;;
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
	-sid)              ORACLE_SID_INPUT=$2 		; shift 2 ;;
	-parallel)         PARALLEL_INPUT=$2    	; shift 2 ;;
	-target)           CONNECT_TAR_INPUT=$2  	; shift 2 ;;
	-backup_path)      PATH_INPUT=$2 		; shift 2 ;;
	-compress)         COMPRESSION_INPUT=$2 	; shift 2 ;;
	-maxpiece)         MAXSETSIZE_INPUT=$2 		; shift 2 ;;
	-autobackup)       AUTOBACKUP_INPUT=$2 		; shift 2 ;;
	-window)           RETTYPE_WINDOW_INPUT="WINDOW"	; RETTYPE_INPUT=$2 		;  shift 2 ;;
	-redundancy)       RETTYPE_REDUNDANCY_INPUT="REDUNDANCY"; RETTYPE_INPUT=$2 		;  shift 2 ;;
	-catalogmode)      CATALOGMODE_INPUT=$2		; shift 2 ;;
	-log_path)         LOG_INPUT=$2 		; shift 2 ;;
	-seq_ret)    	   SEQ_RET=$2 			; RETTYPE_ARC_INPUT=$2			; shift 2 ;;		
	-tim_ret)	   TIM_RET=$2 			; RETTYPE_ARC_INPUT=$2			; shift 2 ;;		
	-backed_arc)	   BACKED_INPUT=$2    		; shift 2 ;;
	*)            	   affiche_param_file		; pb_exit1 "Incorrect parameter $1 in file parameter";;
   esac
done


#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
# CHECKING MANDATORY PARAMETERS
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------

if [ "$ORACLE_SID_INPUT" = "" ];        then affiche_param_file;pb_exit1 "mandatory parameter ORACLE_SID_INPUT missing";fi
if [ "$PARALLEL_INPUT" = "" ];     	then affiche_param_file;pb_exit1 "mandatory parameter parallel missing";fi
if [ "$BACKUP_TYPE_INPUT" = "" ];  	then affiche_param_file;pb_exit1 "mandatory parameter backup type missing";fi
if [ "$CONNECT_TAR_INPUT" = "" ];     	then affiche_param_file;pb_exit1 "mandatory parameter connect string target is missing";fi


#--------------------------------------------------------------------------------------------
# Checking of retention polity of backups.
#--------------------------------------------------------------------------------------------
if [ "$RETTYPE_WINDOW_INPUT" = "" ] && [ "$RETTYPE_REDUNDANCY_INPUT" = "" ];then 
    	affiche_param_file;pb_exit1 "mandatory parameter retention policy by WINDOW or REDUNDANCY"
fi	

#--------------------------------------------------------------------------------------------
# Checking of sequence or time retention for archivelogs applied on standby
#--------------------------------------------------------------------------------------------
if [ "$SEQ_RET" = "" ] && [ "$TIM_RET" = "" ];then 
    affiche_param_file;pb_exit1 "mandatory parameter retention policy of archivelog by seq_ret or tim_ret"	
fi


#--------------------------------------------------------------------------------------------
# Checking of backup mode
#--------------------------------------------------------------------------------------------
CATALOGMODE_VALUE="Y"
case $CATALOGMODE_INPUT in
Y|y)        CATALOGMODE_VALUE="Y";;
N|n)        CATALOGMODE_VALUE="N";;
*)	    affiche_param_file;pb_exit1 "mandatory parameter : backup mode by CATALOG(Y) or NOCATALOG(N)"		
esac


#--------------------------------------------------------------------------------------------
# Checking of SID parameter
#--------------------------------------------------------------------------------------------

SID_RETOUR=$(echo " 
set pages 0
set head off
set feedback off
set trims off
connect $CONNECT_TAR_INPUT  as sysdba
select db_unique_name from v\$database;
exit"|sqlplus -L -S /nolog|tr -d "\n")
 
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
# Checking of backuped archivelogs parameter
# The parameter need to be numeric and not lower to 0
#--------------------------------------------------------------------------------------------
BACKED_VALUE="`echo $BACKED_INPUT|sed -n "/^[0-9]*$/p"`"
if [ "$BACKED_VALUE" = "" ] || [ "$BACKED_VALUE" -lt "0" ];then
   echo -e "\n\nBacked archive parameter = $BACKED_INPUT is not correct\n"
   affiche_param_file
   pb_exit1 "Backed archive parameter = $BACKED_INPUT is not correct"
fi

#--------------------------------------------------------------------------------------------
# Checking of sequence and time retention parameter
# The parameter need to be numeric and not equal to 0 #SN
#--------------------------------------------------------------------------------------------
RETTYPE_ARC_VALUE="`echo $RETTYPE_ARC_INPUT|sed -n "/^[0-9]*$/p"`"

if [ "$RETTYPE_ARC_VALUE" = "" ] || [ "$RETTYPE_ARC_VALUE" -lt "0" ];then
   	echo -e "\n\nSequence or time retention parameter = $RETTYPE_ARC_INPUT is not correct\n"
   	affiche_param_file
   	pb_exit1 "Sequence or time retention parameter = $RETTYPE_ARC_INPUT is not correct"
fi


#--------------------------------------------------------------------------------------------
# Checking of backup type
#--------------------------------------------------------------------------------------------
case $BACKUP_TYPE_INPUT in
	FULL_P|full_p)              	BACKUP_SCRIPT="glob_full_db_backup_nolevel";;
	FULL_S|full_s)              	BACKUP_SCRIPT="glob_full_db_backup_nolevel_stby";;
	FULL0_P|full0_p)              	BACKUP_SCRIPT="glob_full_db_backup_level0";;
	FULL0_S|full0_s)              	BACKUP_SCRIPT="glob_full_db_backup_level0";;
	CUMULATIF_P|cumulatif_p)    	BACKUP_SCRIPT="glob_cum_db_backup";;
	CUMULATIF_S|cumulatif_s)    	BACKUP_SCRIPT="glob_cum_db_backup";;
	INCREMENTAL_P|incremental_p)	BACKUP_SCRIPT="glob_incr_db_backup";;
	INCREMENTAL_S|incremental_s)	BACKUP_SCRIPT="glob_incr_db_backup_stby";;
	ARCHIVELOG_P|archivelog_p)  	BACKUP_SCRIPT="glob_arch_ctl_sp_backup_nopurge_prim";;
	ARCHIVELOG_S|archivelog_s)  	BACKUP_SCRIPT="glob_arch_ctl_backup_nopurge_stby";;
	*)          			echo -e "\nBackup type parameter $BACKUP_TYPE_INPUT is not correct";affiche_param_file;pb_exit1 "Backup type parameter $BACKUP_TYPE_INPUT is not correct";;
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



#--------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------#
# CHECKING OPTIONAL PARAMETERS - CHECKING OPTIONAL PARAMETERS - CHECKING OPTIONAL PARAMETERS
#--------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------#


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
	LOG_FIC="$LOG_INPUT/rman_${ORACLE_SID_INPUT}_${BACKUP_TYPE_INPUT}.log"
	echo > $LOG_FIC
  	LOG_VALUE="|tee $LOG_FIC"
fi


#--------------------------------------------------------------------------------------------
# Composition of backup path
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
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
# Lancement du backup en fonction du type
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
case $BACKUP_TYPE_INPUT in
        FULL_P|full_p)                  BACKUP_SCRIPT="glob_full_db_backup_nolevel"; 		CAT=1;;
        FULL_S|full_s)                  BACKUP_SCRIPT="glob_full_db_backup_nolevel_stby";	CAT=1;;
        FULL0_P|full0_p)                BACKUP_SCRIPT="glob_full_db_backup_level0";		CAT=1;;
        FULL0_S|full0_s)                BACKUP_SCRIPT="glob_full_db_backup_level0";		CAT=1;;
        CUMULATIF_P|cumulatif_p)        BACKUP_SCRIPT="glob_cum_db_backup";			CAT=1;;
        CUMULATIF_S|cumulatif_s)        BACKUP_SCRIPT="glob_cum_db_backup";			CAT=1;;
        INCREMENTAL_P|incremental_p)    BACKUP_SCRIPT="glob_incr_db_backup";			CAT=1;;
        INCREMENTAL_S|incremental_s)    BACKUP_SCRIPT="glob_incr_db_backup_stby";		CAT=1;;
        ARCHIVELOG_P|archivelog_p)      BACKUP_SCRIPT="glob_arch_ctl_sp_backup_nopurge_prim";	CAT=1;;
        ARCHIVELOG_S|archivelog_s)      BACKUP_SCRIPT="glob_arch_ctl_backup_nopurge_stby";	CAT=1;;
        *)                              echo -e "\nBackup type parameter $BACKUP_TYPE_INPUT is not correct";affiche_param_file;pb_exit1 "Backup type parameter $BACKUP_TYPE_INPUT is not correct";;
esac

if  [ "$CATALOGMODE_VALUE"="Y" ]; then
	backup_database_catalog
fi

#-------------------------------------------------------------------------------------------
#EOF
#-------------------------------------------------------------------------------------------
