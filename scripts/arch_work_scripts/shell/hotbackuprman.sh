#!/bin/bash
#
############################################################################
# hotbackuprman.sh
#
# Usage         : 
# Effectue les types de backups FULL, FULL 0, INCR, CUMUL, ARCH
# Effectue des backups Catalog ou controle file
# Auteur(e)     : David Larquey, Sylvie Nottet 		01/01/2014
# Modification  : Sylvie Nottet, 29/01/2014
#
############################################################################
#
#

export PATH=$PATH:/usr/bin

# ----------------------------------------------------
# Variables globales
# ----------------------------------------------------
export WORK_SH=/opt/oracle/admin/orawork/shell/rman
export WORK_LIB=/opt/oracle/admin/orawork/lib/rman
export WORK_CFG=/opt/oracle/admin/orawork/cfg/rman
export WORK_LOG=/opt/oracle/admin/orawork/log/rman


ARG_TARGET_DBNAME=$1
ARG_TARGET_ENV=$(echo $2|tr [:lower:] [:upper:])
ARG_TARGET_NAME="${ARG_TARGET_ENV}_${ARG_TARGET_DBNAME}"
ARG_TARGET_BACKUP_TYPE=$(echo $3|tr [:lower:] [:upper:])
SCRIPT_CHECK_PARAMS=$WORK_SH/hotbackuprman.check.sh



#################
### Functions ###
#################
function printSyntax() {
clear
cat <<EOH

------------------ Help -------------------------

Usage :	
	`basename $0` [DBNAME] [ENV] [BACKUP_TYPE]

Example : $(dirname $0)/`basename $0` ATOOLS PROD FULL


Description :
	Allows to do these features :

	FULL backup database .................................[BACKUP_TYPE=FULL]
	FULL backup database level 0..........................[BACKUP_TYPE=FULL0]
	CUMULATIF backup database.............................[BACKUP_TYPE=CUMULATIF]
	INCREMENTAL backup database...........................[BACKUP_TYPE=INCREMENTAL]
	ARCHIVELOG backup database on Primary database........[BACKUP_TYPE=ARCHIVELOGP]
	ARCHIVELOG backup database on Standby database........[BACKUP_TYPE=ARCHIVELOGS]
	PURGE of obsoletes and expired backups................[BACKUP_TYPE=PURGE_BACKUP]
	PURGE of old archivelog on Primary database...........[BACKUP_TYPE=PURGE_ARCHIVEP]
	PURGE of old archivelog on Standby database...........[BACKUP_TYPE=PURGE_ARCHIVES]

Prerequisites:
	Parameters file 	: hotbackuprman.conf
	Libraries files		: hotbackuprman.lib, hotbackuprman.libdb
	Others files and script : hotbackuprman.check.sh


NOTICE:
The configuration file defined all parameters associated for a database.
The entry for the database in the configuration file is named like 'ENV_DBNAME'. Example: PROD_ATOOLS

By default each database to save has 8 parameters to provide into the hotbackuprman.conf file.
CAUTION: Do not delete a DEFAULT settings. It can be replaced in the section of the database to save


EOH
}



#################
### MAIN      ###
#################
[ $# -ne 3 ] && { printSyntax; exit 1; }

LOG_MAIN_STEP=INIT
LOG_STEP=LAUNCH_SCRIPT

# ----------------------------------------------------
# Load libraries
# ----------------------------------------------------
# Script library
[ -f $WORK_LIB/hotbackuprman.lib ] || { printSyntax; echo "ERROR : Missing main library hotbackuprman.lib!"; exit 1; }
. $WORK_LIB/hotbackuprman.lib
do_init

#SQL Library
[ -f $WORK_LIB/hotbackuprman.libdb ] || { printSyntax; echo "ERROR : Missing main SQL library hotbackuprman.libdb!"; exit 1; }
. $WORK_LIB/hotbackuprman.libdb

# Trap the EXIT signal
trap do_exit EXIT INT

#Check script
[ -f "$SCRIPT_CHECK_PARAMS" ] || { printSyntax; echo "ERROR : Missing included script $SCRIPT_CHECK_PARAMS! >&2"; exit 1; }
[ -x "$SCRIPT_CHECK_PARAMS" ] || { printSyntax; echo "ERROR : Missing included script $SCRIPT_CHECK_PARAMS! >&2"; exit 1; }



# ----------------------------------------------------
# Check ARGS
# ----------------------------------------------------
HOST=`hostname`

log ""
log "---------------------------------------------------------------------------------------------------"
log "*** Start treatment of this command : $0 $@ on $HOST at $DATE ***"
log "---------------------------------------------------------------------------------------------------"
log ""
log "+ Temporary Log file\t: $LOGFILE"

LOG_STEP=GET_RMAN_PARAMETERS
log "Get all RMAN parameters for the alias target $ARG_TARGET_NAME for DB $ARG_TARGET_DBNAME"
log "Running check script: $SCRIPT_CHECK_PARAMS -t $ARG_TARGET_NAME -L $LOGFILE"

# ----------------------------------------------------
# Execution du script de check
# ----------------------------------------------------
CMD_RMAN_PARAMS=$($SCRIPT_CHECK_PARAMS -t $ARG_TARGET_NAME -L $LOGFILE) ; ret=$?

if [ $ret -ne 0 ]; then
	log_error "An error has occured during the load of RMAN parameters" 
else
	log "End of execution of the check script: $SCRIPT_CHECK_PARAMS"
fi

[ -z "$CMD_RMAN_PARAMS" ] &&  log_error "No parameter were found for the target $ARG_TARGET_NAME"

log "Loading RMAN parameters for the target ${ARG_TARGET_NAME}................."
eval $(echo $CMD_RMAN_PARAMS|egrep '^RP_|^SP_')


#[ "$ARG_TARGET_DBNAME" != "$RP_TARGET_DBNAME" ] &&  log_error "The specified DBNAME does not match the parameter in the configuration file" 
[ "$ARG_TARGET_ENV" != "$RP_TARGET_ENV" ] &&  log_error "The specified environment does not match the parameter in the configuration file" 


case $ARG_TARGET_BACKUP_TYPE in
            FULL|full)				ARG_TARGET_BACKUP_TYPE="FULL";;
	    FULL0|full0)			ARG_TARGET_BACKUP_TYPE="FULL0";;
            CUMULATIF|cumulatif)		ARG_TARGET_BACKUP_TYPE="CUMULATIF";;
            INCREMENTAL|incremental)  		ARG_TARGET_BACKUP_TYPE="INCREMENTAL";;
            ARCHIVELOGP|archivelogp)  		ARG_TARGET_BACKUP_TYPE="ARCHIVELOGP";;
            ARCHIVELOGS|archivelogs)  		ARG_TARGET_BACKUP_TYPE="ARCHIVELOGS";;
            PURGE_BACKUP|purge_backup) 		ARG_TARGET_BACKUP_TYPE="PURGE_BACKUP";;
            PURGE_ARCHIVEP|purge_archivep)	ARG_TARGET_BACKUP_TYPE="PURGE_ARCHIVEP";;
            PURGE_ARCHIVES|purge_archives)	ARG_TARGET_BACKUP_TYPE="PURGE_ARCHIVES";;
            *) 					{ printSyntax; echo "Invalid backup type: $ARG_TARGET_BACKUP_TYPE"; log_error "Invalid backup type: $ARG_TARGET_BACKUP_TYPE"; exit 1; }
esac


# ----------------------------------------------------
# Init: logging to file
# ----------------------------------------------------
ENVLOG=$(echo $RP_TARGET_ENV | tr [:upper:] [:lower:])
logfile=$LOGDIR/${ENVLOG}/RMAN_${ARG_TARGET_DBNAME}_${ARG_TARGET_ENV}_${ARG_TARGET_BACKUP_TYPE}.log
tracefile=$LOGDIR/${ENVLOG}/RMAN_${ARG_TARGET_DBNAME}_${ARG_TARGET_ENV}_${ARG_TARGET_BACKUP_TYPE}.trc


init_logfile $logfile
init_tracefile $tracefile


cat $TMPDIR/${SCRIPTNAME}.$$.log >>$logfile
cat $TMPDIR/${SCRIPTNAME}.$$.log >>$tracefile
log "Switching to logfile: $logfile"


log "+ Target DB\t: $ARG_TARGET_DBNAME"
log "+ Environment\t: $ARG_TARGET_ENV"
log "+ Backup type\t: $ARG_TARGET_BACKUP_TYPE"
log "+ Log file\t: $LOGFILE"
log "+ Trace file\t: $TRACEFILE"

trace "+ Target DB\t\t: $ARG_TARGET_DBNAME"
trace "+ Environment\t: $ARG_TARGET_ENV"
trace "+ Backup type\t: $ARG_TARGET_BACKUP_TYPE"
trace "+ Log file\t\t: $LOGFILE"
trace "+ Trace file\t: $TRACEFILE"


[ "$RP_ACTIVATE_BACKUP" = "N" ] && { log_error "Backup Deactivated. See RP_ACTIVATE_BACKUP parameter in $RMAN_CONFIG_FILE"; echo "RP_ACTIVATE_BACKUP=$RP_ACTIVATE_BACKUP";  }

# ----------------------------------------------------
# Init: Check client instance
# ----------------------------------------------------
get_ora_env $RP_CLIENT_INSTANCE
log "Client ORACLE_HOME used : <$ORACLE_HOME> SID:<$ORACLE_SID>"


# ----------------------------------------------------
# Init: Check that the logger instance is a primary and enable logging to database
# ----------------------------------------------------
init_check_logger_instance


# ----------------------------------------------------
# Init: Check that the catalog instance is a primary
# ----------------------------------------------------

init_check_catalog_instance


# ----------------------------------------------------
# Init: Log RMAN paramaters into database
# ----------------------------------------------------
LOG_STEP=GET_RMAN_PARAMETERS

msg_temp="-- ARGS
ARG_TARGET_DBNAME=$ARG_TARGET_DBNAME
ARG_TARGET_ENV=$ARG_TARGET_ENV
ARG_TARGET_BACKUP_TYPE=$ARG_TARGET_BACKUP_TYPE
-- RMAN
$CMD_RMAN_PARAMS"


LOG_STEP='GET_RMAN_PARAMETERS'
log_sql_update_main_action "backup_param='$msg_temp'" $LOG_MAIN_STEP $LOG_STEP "Loading RMAN parameters" "COMPLETED" $ORA_LOG_MAIN_ACTIONS_ID


# ----------------------------------------------------
# Init: Get the backup priority
# ----------------------------------------------------
#LOCKFILE=$TMPDIR/${SCRIPTNAME}_${ARG_TARGET_DBNAME}_${ARG_TARGET_ENV}_${ARG_TARGET_BACKUP_TYPE}.lock
LOCKFILE=$TMPDIR/${SCRIPTNAME}_${ARG_TARGET_DBNAME}_${ARG_TARGET_ENV}.lock
init_manage_priority


# ----------------------------------------------------
# Init: Write lock file
# ----------------------------------------------------
init_write_lock_file


# ----------------------------------------------------
# Build rman parameters
# ----------------------------------------------------
build_rman_parameters


# ----------------------------------------------------
# Checking and lauching of rman backup
# ----------------------------------------------------


#echo -e "\n\nARG_TARGET_BACKUP_TYPE: $ARG_TARGET_BACKUP_TYPE\n\n"
#exit

if [ "$ARG_TARGET_BACKUP_TYPE" = "FULL" ]; then

    backup_full_database_nolevel
    purge_archivelog
    purge_obsolete_expired
	#resync_catalog_backup_files

elif [ "$ARG_TARGET_BACKUP_TYPE" = "FULL0" ]; then

    backup_full_database_level0
    purge_archivelog
    purge_obsolete_expired
	#resync_catalog_backup_files

elif [ "$ARG_TARGET_BACKUP_TYPE" = "CUMULATIF" ]; then

    backup_cumulative
	#resync_catalog_backup_files
	
elif [ "$ARG_TARGET_BACKUP_TYPE" = "INCREMENTAL" ]; then

    backup_incremental
	#resync_catalog_backup_files
	
elif [ "$ARG_TARGET_BACKUP_TYPE" = "ARCHIVELOGP" ] || [ "$ARG_TARGET_BACKUP_TYPE" = "ARCHIVELOGS" ]; then

    backup_archivelog
    #resync_catalog_backup_files

elif  [ "$ARG_TARGET_BACKUP_TYPE" = "PURGE_BACKUP" ]; then

    purge_obsolete_expired
	#resync_catalog_backup_files
	
elif  [ "$ARG_TARGET_BACKUP_TYPE" = "PURGE_ARCHIVE" ] ||  [ "$ARG_TARGET_BACKUP_TYPE" = "PURGE_ARCHIVEP" ] || [ "$ARG_TARGET_BACKUP_TYPE" = "PURGE_ARCHIVES" ]; then

    purge_archivelog
	#resync_catalog_backup_files

else
    MSG= ">>>>>>>>>>>>>>>>>>>>> Can't identified the backup type  <<<<<<<<<<<<<<<<<<"
    echo "$MSG"
    log "$MSG"
    exit 1
fi


if [ $RESET_LOCK -eq 1 ]; then
    [ -f $LOCKFILE ] || log "WARNING: The lock file does not exist !!!"
fi
