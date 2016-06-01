#!/bin/bash

# Author: dlarquey, Sylvie Nottet : 20/01/2014
#
# Last modified : 
    #dlarquey Thu Jan  9 13:08:27 CET 2014
    #Snottet 30/01/2014
#
# This script extracts all RMAN parameters for a target defined in the RMAN configuration file
# try '-h' option for help
#
# If you add some parameters, please modify this script:
# - check the parameter value: see the function check_target_parameters
# - output the parameter: see the function output_parameters

export PATH=$PATH:/usr/bin

# ----------------------------------------------------
# Variables globales
# ----------------------------------------------------

export WORK_SH=/opt/oracle/admin/orawork/shell/rman
export WORK_LIB=/opt/oracle/admin/orawork/lib/rman
export WORK_CFG=/opt/oracle/admin/orawork/cfg/rman
export WORK_LOG=/opt/oracle/admin/orawork/log/rman


#################
### Functions ###
#################


function printSyntax() {
clear
cat <<EOS

------------------ Help -------------------------


Usage : `basename $0` -t TARGET [-d] [-c] [-l] [-L Logfile]

Example : ./`basename $0` -t PROD_ATOOLS


Description :
Load, check and print RMAN configuration parameters for a specified target database using the rman configuration file.



	-l              Print available targets
	-t TARGET       Specify the target entry to search in the configuration file.
	-d              Enable the DEBUG mode. Print only the parameters if the DEBUG mode is disabled  
	-c CONFIGFILE   Specify the config file to use
	-p              Detail all available parameters
	-L              Specify the Log File you want use (optional)


Prerequisites:
        Parameters file         : $RMAN_CONFIG_FILE (default configuration file)
        Libraries files         : $WORK_LIB/hotbackuprman.lib

EOS
}


function list_targets() {
    local input_file=$1

    cat $input_file\
| grep "^[[:blank:]]*\[.*\][[:blank:]]*$"\
| sed "s/[[:blank:]]*\[\(.*\)\][[:blank:]]*$/\1/"

}


# input: input_file,input_target
# return: code into the variable $get_target_parameters_code
# This function extracts all pamareters with a good syntax: (minimum of 2 chars length)
# ^[a-z][a-z0-9_-]+=[a-z0-9_.@/-]+[[:blank:]]*$
function get_target_parameters() {
    local input_file=$1
    local input_target=$2
    get_target_parameters_code=


    # check duplicates
    nb=$(cat $input_file\
| sed -n "/^[[:blank:]]*\[$input_target\][[:blank:]]*$/",'/\[|^[[:blank:]]*$/'p\
| grep -v '^[[:blank:]]*#'\
| grep "^[[:blank:]]*\[$input_target\]"\
| wc -l)
    [ $nb -eq 0 ] && log_error "Target '$input_target' does not exist in the configuration file: $ARG_INPUT_FILE"
    [ $nb -gt 1 ] && log_error "More than one target for '$input_target' was found"

    get_target_parameters_code=$(cat $ARG_INPUT_FILE\
| sed -rn "/^[[:blank:]]*\[$input_target\][[:blank:]]*$/",'/^[[:blank:]]*\[|^[[:blank:]]*$/'p\
| grep -v '^[[:blank:]]*#'\
| egrep -oi '^[a-z][a-z0-9_-]+=[" a-z0-9_.@/,;-]+[[:blank:]]*'\
| sed "s/[[:blank:]]*$//g"\
    )
    [ -z "$get_target_parameters_code" ] && log_error "No parameters were found for the target: $input_target"
    return 0
}


function load_target_parameters() {

    eval $1
}


function check_mandatory_parameters() {

    #---------------------------------------------------------------------------#
    #---------- Test values for mandatory parameters --------------------#
    #---------------------------------------------------------------------------#
    [ -z "$RP_TARGET_DBNAME" ]              && log_error "Wrong value for the parameter RP_TARGET_DBNAME: $RP_TARGET_DBNAME"
    [ -z "$RP_TARGET_USER" ]                && log_error "Wrong value for the parameter RP_TARGET_USER: $RP_TARGET_USER"
    [ -z "$RP_TARGET_PASSWORD" ]            && log_error "Wrong value for the parameter RP_TARGET_PASSWORD: $RP_TARGET_PASSWORD"
    [ -z "$RP_TARGET_TNS" ]                 && log_error "Wrong value for the parameter RP_TARGET_TNS: $RP_TARGET_TNS"
    [ -z "$RP_CLIENT_INSTANCE" ]            && log_error "Wrong value for the parameter RP_CLIENT_INSTANCE: $RP_CLIENT_INSTANCE"

     if [ -z "$RP_BACKUP_RETENTION_DAYS" ] || ! is_integer "$RP_BACKUP_RETENTION_DAYS" || [ $RP_BACKUP_RETENTION_DAYS -le 0 ]; then 
         log_error "ERROR: Wrong value for the parameter RP_BACKUP_RETENTION_DAYS: $RP_BACKUP_RETENTION_DAYS. Please check hotbackuprman.conf file."
     fi

    RP_TARGET_ENV=$(echo $RP_TARGET_ENV | tr [:lower:] [:upper:])
    if [ -z "$RP_TARGET_ENV" ] || ! echo $RP_TARGET_ENV | egrep -q '^(PROD|UAT|DEV|QUAL)$'; then
        log_error "Wrong value for the parameter RP_TARGET_ENV: $RP_TARGET_ENV"
    fi
    
    if [ -z "$RP_BACKUP_FILE_PATH" ] || ! [ -d "$RP_BACKUP_FILE_PATH" ]; then
        log_error "Wrong value for the parameter RP_BACKUP_FILE_PATH: $RP_BACKUP_FILE_PATH"
    fi

    if [ -z "$RP_LOG_PATH" ] || ! [ -d "$RP_LOG_PATH" ]; then
        log_error "Wrong value for the parameter RP_LOG_PATH: $RP_LOG_PATH"
    fi

    RP_BACKUP_RETENTION_POLICY=$(echo $RP_BACKUP_RETENTION_POLICY | tr [:upper:] [:lower:])
    if [ -z "$RP_BACKUP_RETENTION_POLICY" ] || ! echo $RP_BACKUP_RETENTION_POLICY | egrep -q '^(window|redundancy)$'; then
        log_error "Wrong value for the parameter RP_BACKUP_RETENTION_POLICY: $RP_BACKUP_RETENTION_POLICY"
    else
	    if [ "$RP_BACKUP_RETENTION_POLICY" = "window" ]; then
		    RP_BACKUP_RETENTION_POLICY="RECOVERY WINDOW OF $RP_BACKUP_RETENTION_DAYS days"
	    else
		    RP_BACKUP_RETENTION_POLICY="REDUNDANCY $RP_BACKUP_RETENTION_DAYS"
	    fi
    fi

    RP_FULL_ON_PRIMARY=$(echo $RP_FULL_ON_PRIMARY | tr [:lower:] [:upper:])
    if [ -z "$RP_FULL_ON_PRIMARY" ] || ! echo $RP_FULL_ON_PRIMARY | egrep -q '^(Y|N)$'; then
        log_error "Wrong value for the parameter RP_FULL_ON_PRIMARY=$RP_FULL_ON_PRIMARY"
    fi
	#echo "DEBUG 2 RP_FULL_ON_PRIMARY=$RP_FULL_ON_PRIMARY <<<<<<<<<<<<<<<<<<<<<"
    
    if [ -z "$RP_STBY_TARGET_TNS" ] && [ "$RP_FULL_ON_PRIMARY" = "Y" ] ; then
        log "INFO: Not value for the parameter RP_STBY_TARGET_TNS='$RP_STBY_TARGET_TNS'. Automatically changed by 'NOFULLBACKUP_ON_STANDBY'. Please check hotbackuprman.conf file for more info."
        RP_STBY_TARGET_TNS=NOFULLBACKUP_ON_STANDBY
    elif [ -z "$RP_STBY_TARGET_TNS" ] && [ "$RP_FULL_ON_PRIMARY" = "N" ] ; then
        log_error "Wrong value for the parameter RP_STBY_TARGET_TNS='$RP_STBY_TARGET_TNS' while RP_FULL_ON_PRIMARY='$RP_FULL_ON_PRIMARY'. Please check hotbackuprman.conf file."
    fi	

    RP_BACKUP_CATALOGMODE=$(echo $RP_BACKUP_CATALOGMODE | tr [:lower:] [:upper:])
    if [ -z "$RP_BACKUP_CATALOGMODE" ] || ! echo $RP_BACKUP_CATALOGMODE | egrep -q '^(Y|N|S)$'; then
        log "WARNING: Wrong value for the parameter RP_BACKUP_CATALOGMODE='$RP_BACKUP_CATALOGMODE'. Automatically changed by 'N'. Please check hotbackuprman.conf file."
        RP_BACKUP_CATALOGMODE=N
    fi

    if [ -z "$RP_CATALOG_TNS" ] && [ "$RP_BACKUP_CATALOGMODE" = "N" ] ; then
        log "INFO: Not value for the parameter RP_CATALOG_TNS. Automatically changed by 'NOBACKUPWITHCATALOG_MODE'."
        RP_CATALOG_TNS=NOBACKUPWITHCATALOG_MODE
    elif [ -z "$RP_CATALOG_TNS" ] && ([ "$RP_BACKUP_CATALOGMODE" = "Y" ] || [ "$RP_BACKUP_CATALOGMODE" = "S" ]); then
        log_error "Wrong value for the parameter RP_CATALOG_TNS : '$RP_CATALOG_TNS'  while RP_BACKUP_CATALOGMODE='$RP_BACKUP_CATALOGMODE"
    elif  [ "$RP_BACKUP_CATALOGMODE" = "Y" ] || [ "$RP_BACKUP_CATALOGMODE" = "S" ] ; then
        [ -z "$RP_CATALOG_USER" ]               && log_error "Wrong value for the parameter RP_CATALOG_USER: '$RP_CATALOG_USER'  while RP_BACKUP_CATALOGMODE='$RP_BACKUP_CATALOGMODE'"
        [ -z "$RP_CATALOG_PASSWORD" ]           && log_error "Wrong value for the parameter RP_CATALOG_PASSWORD: '$RP_CATALOG_PASSWORD'"
    fi	

}



function check_dynamic_parameters() {
    #---------------------------------------------------------------------------#
    #---------- Mandotory Parameters dynamically modified ----------------------#
    #---------------------------------------------------------------------------#
    if [ -z "$RP_BACKUP_MAXPIECE" ] || ! is_integer "$RP_BACKUP_MAXPIECE" || [ $RP_BACKUP_MAXPIECE -le 0 ]; then
        log "WARNING: Wrong value for the parameter RP_BACKUP_MAXPIECE=$RP_BACKUP_MAXPIECE. Automatically changed by 'UNLIMITED'. Please check hotbackuprman.conf file."
        RP_BACKUP_MAXPIECE="UNLIMITED"
    else
         RP_BACKUP_MAXPIECE="${RP_BACKUP_MAXPIECE}G"
    fi

    if [ -z "$RP_ARCHIVE_RETENTION_NUMBER" ] || ! is_integer "$RP_ARCHIVE_RETENTION_NUMBER" || [ $RP_ARCHIVE_RETENTION_NUMBER -le 0 ]; then 
        log "WARNING: Wrong value for the parameter RP_ARCHIVE_RETENTION_NUMBER"=$RP_ARCHIVE_RETENTION_NUMBER". Automatically changed by '5'. Please check hotbackuprman.conf file."
        RP_ARCHIVE_RETENTION_NUMBER=5
    fi
	
	if [ -z "$RP_ARCHIVE_BACKUP_COUNT" ] || ! is_integer "$RP_ARCHIVE_BACKUP_COUNT" || [ $RP_ARCHIVE_BACKUP_COUNT -le 0 ]; then 
        log "WARNING: Wrong value for the parameter RP_ARCHIVE_BACKUP_COUNT"=$RP_ARCHIVE_BACKUP_COUNT". Automatically changed by '2'. Please check hotbackuprman.conf file."
        RP_ARCHIVE_BACKUP_COUNT=2
    fi
     
    if [ -z "$RP_PARALLELISM" ] || ! is_integer "$RP_PARALLELISM" || [ $RP_PARALLELISM -le 0 ]; then
         log "WARNING: Wrong value for the parameter RP_PARALLELISM=$RP_PARALLELISM. Automatically changed by '1'. Please check hotbackuprman.conf file."
         RP_PARALLELISM=1
    fi

    RP_ACTIVATE_BACKUP=$(echo $RP_ACTIVATE_BACKUP | tr [:lower:] [:upper:])
    if [ -z "$RP_ACTIVATE_BACKUP" ] || ! echo $RP_ACTIVATE_BACKUP | egrep -q '^(Y|N)$'; then
        log "WARNING: Wrong value for the parameter RP_ACTIVATE_BACKUP=$RP_ACTIVATE_BACKUP. Automatically changed by 'Y'. Please check hotbackuprman.conf file."
        RP_ACTIVATE_BACKUP=Y
    fi

    RP_BACKUP_COMPRESSION=$(echo $RP_BACKUP_COMPRESSION | tr [:lower:] [:upper:])
    if [ -z "$RP_BACKUP_COMPRESSION" ] || ! echo $RP_BACKUP_COMPRESSION | egrep -q '^(Y|N)$'; then
        log "WARNING: Wrong value for the parameter RP_BACKUP_COMPRESSION=$RP_BACKUP_COMPRESSION. Automatically changed by 'Y'. Please check hotbackuprman.conf file."
        RP_BACKUP_COMPRESSION="COMPRESSED"
    else
        case $RP_BACKUP_COMPRESSION in
            Y)  RP_BACKUP_COMPRESSION="COMPRESSED";;
            N)  RP_BACKUP_COMPRESSION="";;
        esac
    fi
    
    RP_AUTOBACKUP_CTL=$(echo $RP_AUTOBACKUP_CTL | tr [:lower:] [:upper:])
    if [ -z "$RP_AUTOBACKUP_CTL" ] || ! echo $RP_AUTOBACKUP_CTL | egrep -q '^(Y|N)$'; then
        log "WARNING: Wrong value for the parameter RP_AUTOBACKUP_CTL=$RP_AUTOBACKUP_CTL. Automatically changed by 'N'. Please check hotbackuprman.conf file."
        RP_AUTOBACKUP_CTL="OFF"
    else
        case $RP_AUTOBACKUP_CTL in
                Y)  RP_AUTOBACKUP_CTL="ON";;
                N)  RP_AUTOBACKUP_CTL="OFF";;
        esac
    fi
    
    RP_ARCHIVE_RETENTION_POLICY=$(echo $RP_ARCHIVE_RETENTION_POLICY | tr [:upper:] [:lower:])
    if [ -z "$RP_ARCHIVE_RETENTION_POLICY" ] || ! echo $RP_ARCHIVE_RETENTION_POLICY | egrep -q '^(time|sequence)$'; then
        log "WARNING: Wrong value for the parameter RP_ARCHIVE_RETENTION_POLICY"=$RP_ARCHIVE_RETENTION_POLICY". Automatically changed by 'time'. Please check hotbackuprman.conf file."
        RP_ARCHIVE_RETENTION_POLICY="time"
    fi
    
    RP_BACKUP_ARC_P_BEFORE_PURGE=$(echo $RP_BACKUP_ARC_P_BEFORE_PURGE | tr [:lower:] [:upper:])
    if [ -z "$RP_BACKUP_ARC_P_BEFORE_PURGE" ] || ! echo $RP_BACKUP_ARC_P_BEFORE_PURGE | egrep -q '^(Y|N)$'; then
        log "WARNING: Wrong value for the parameter RP_BACKUP_ARC_P_BEFORE_PURGE=$RP_BACKUP_ARC_P_BEFORE_PURGE. Automatically changed by 'Y'. Please check hotbackuprman.conf file."
        RP_BACKUP_ARC_P_BEFORE_PURGE=Y
    fi

    RP_BACKUP_ARC_S_BEFORE_PURGE=$(echo $RP_BACKUP_ARC_S_BEFORE_PURGE | tr [:lower:] [:upper:])
    if [ -z "$RP_BACKUP_ARC_S_BEFORE_PURGE" ] || ! echo $RP_BACKUP_ARC_S_BEFORE_PURGE | egrep -q '^(Y|N)$'; then
        RP_BACKUP_ARC_S_BEFORE_PURGE=Y
        log "WARNING: Wrong value for the parameter RP_BACKUP_ARC_S_BEFORE_PURGE=$RP_BACKUP_ARC_S_BEFORE_PURGE. Automatically changed by 'Y'. Please check hotbackuprman.conf file."
    fi
    
    RP_ARCHIVELOG_P_DELETION_POLICY=$(echo $RP_ARCHIVELOG_P_DELETION_POLICY | tr [:lower:] [:upper:])
    if [ -z "$RP_ARCHIVELOG_P_DELETION_POLICY" ] || ! echo $RP_ARCHIVELOG_P_DELETION_POLICY | egrep -q '^(CLEAR|NONE|APPLIED_ON_STANDBY)$'; then
        log "WARNING: Wrong value for the parameter RP_ARCHIVELOG_P_DELETION_POLICY=$RP_ARCHIVELOG_P_DELETION_POLICY. Automatically changed by 'NONE'. Please check hotbackuprman.conf file."
        RP_ARCHIVELOG_P_DELETION_POLICY="CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;"
    else
		case $RP_ARCHIVELOG_P_DELETION_POLICY in
			NONE)	RP_ARCHIVELOG_P_DELETION_POLICY="CONFIGURE ARCHIVELOG DELETION POLICY TO $RP_ARCHIVELOG_P_DELETION_POLICY ;";;
			APPLIED_ON_STANDBY)	RP_ARCHIVELOG_P_DELETION_POLICY="CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON STANDBY;";;
			CLEAR)	RP_ARCHIVELOG_P_DELETION_POLICY="";;
		esac
    fi
	
	RP_ARCHIVELOG_S_DELETION_POLICY=$(echo $RP_ARCHIVELOG_S_DELETION_POLICY | tr [:lower:] [:upper:])
    if [ -z "$RP_ARCHIVELOG_S_DELETION_POLICY" ] || ! echo $RP_ARCHIVELOG_S_DELETION_POLICY | egrep -q '^(CLEAR|NONE|APPLIED_ON_STANDBY)$'; then
        log "WARNING: Wrong value for the parameter RP_ARCHIVELOG_S_DELETION_POLICY=$RP_ARCHIVELOG_S_DELETION_POLICY. Automatically changed by 'NONE'. Please check hotbackuprman.conf file."
        RP_ARCHIVELOG_S_DELETION_POLICY="CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;"
    else
		case $RP_ARCHIVELOG_S_DELETION_POLICY in
			CLEAR|NONE)	RP_ARCHIVELOG_S_DELETION_POLICY="CONFIGURE ARCHIVELOG DELETION POLICY TO $RP_ARCHIVELOG_S_DELETION_POLICY ;";;
			APPLIED_ON_STANDBY)	RP_ARCHIVELOG_S_DELETION_POLICY="CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON STANDBY;";;
		esac
    fi
	

}


function check_optionnal_parameters() {
    #---------------------------------------------------------------------------#
    #---------- Test null values for optionnal parameters ----------------------#
    #---------------------------------------------------------------------------#
    [ -z "$SP_LOG_SCHEMA_INPUT" ]           &&  log "WARNING: Wrong value for the parameter SP_LOG_SCHEMA_INPUT: $SP_LOG_SCHEMA_INPUT. Can't log in database."
    [ -z "$SP_LOG_PASSWORD_INPUT" ]         &&  log "WARNING: Wrong value for the parameter SP_LOG_PASSWORD_INPUT: $SP_LOG_PASSWORD_INPUT. Can't log in database."
    [ -z "$SP_LOG_TNS_INPUT" ]              &&  log "WARNING: Wrong value for the parameter SP_LOG_TNS_INPUT: $SP_LOG_TNS_INPUT. Can't log in database."
    [ -z "$SP_LOG_TABLE_LOG_MAIN_ACTIONS" ] &&  log "WARNING: Wrong value for the parameter SP_LOG_TABLE_LOG_MAIN_ACTIONS: $SP_LOG_TABLE_LOG_MAIN_ACTIONS. Can't log in database."
    [ -z "$SP_LOG_TABLE_LOGS" ]             &&  log "WARNING: Wrong value for the parameter SP_LOG_TABLE_LOGS: $SP_LOG_TABLE_LOGS. Can't log in database." 

    #RP_SENDMAIL_TO:  could be null
    #RP_LOG_PATH : Check effectue ulterieurement
}


function output_parameters() {
echo "\
RP_TARGET_DBNAME=$RP_TARGET_DBNAME
RP_TARGET_ENV=$RP_TARGET_ENV
RP_TARGET_USER=$RP_TARGET_USER
RP_TARGET_PASSWORD=$RP_TARGET_PASSWORD
RP_TARGET_TNS=$RP_TARGET_TNS
RP_FULL_ON_PRIMARY=$RP_FULL_ON_PRIMARY
RP_PARALLELISM=$RP_PARALLELISM
RP_ACTIVATE_BACKUP=$RP_ACTIVATE_BACKUP
RP_ARCHIVE_RETENTION_POLICY=$RP_ARCHIVE_RETENTION_POLICY
RP_ARCHIVE_RETENTION_NUMBER=$RP_ARCHIVE_RETENTION_NUMBER
RP_BACKUP_RETENTION_POLICY=\"$RP_BACKUP_RETENTION_POLICY\"
RP_BACKUP_RETENTION_DAYS=$RP_BACKUP_RETENTION_DAYS
RP_BACKUP_FILE_PATH=$RP_BACKUP_FILE_PATH
RP_BACKUP_MAXPIECE=$RP_BACKUP_MAXPIECE
RP_ARCHIVE_BACKUP_COUNT=$RP_ARCHIVE_BACKUP_COUNT
RP_BACKUP_COMPRESSION=$RP_BACKUP_COMPRESSION
RP_ARCHIVELOG_S_DELETION_POLICY=\"$RP_ARCHIVELOG_S_DELETION_POLICY\"
RP_ARCHIVELOG_P_DELETION_POLICY=\"$RP_ARCHIVELOG_P_DELETION_POLICY\"
RP_BACKUP_CATALOGMODE=$RP_BACKUP_CATALOGMODE
RP_BACKUP_ARC_S_BEFORE_PURGE=$RP_BACKUP_ARC_S_BEFORE_PURGE
RP_BACKUP_ARC_P_BEFORE_PURGE=$RP_BACKUP_ARC_P_BEFORE_PURGE
RP_AUTOBACKUP_CTL=$RP_AUTOBACKUP_CTL
RP_STBY_TARGET_TNS=$RP_STBY_TARGET_TNS
RP_LOG_PATH=$RP_LOG_PATH
RP_SENDMAIL_TO=$RP_SENDMAIL_TO
RP_CATALOG_USER=$RP_CATALOG_USER
RP_CATALOG_TNS=$RP_CATALOG_TNS
RP_CATALOG_PASSWORD=$RP_CATALOG_PASSWORD
RP_CLIENT_INSTANCE=$RP_CLIENT_INSTANCE
SP_LOG_SCHEMA_INPUT=$SP_LOG_SCHEMA_INPUT
SP_LOG_PASSWORD_INPUT=$SP_LOG_PASSWORD_INPUT
SP_LOG_TNS_INPUT=$SP_LOG_TNS_INPUT
SP_LOG_TABLE_LOG_MAIN_ACTIONS=$SP_LOG_TABLE_LOG_MAIN_ACTIONS
SP_LOG_TABLE_LOGS=$SP_LOG_TABLE_LOGS"
}


function all_parameters_details() {


clear
cat <<EOS
Print all available parameters.

Usage :
	$(basename $0) -p

EOS

cat $ARG_INPUT_FILE |sed -n /#BEGIN_LIST/,/#END_LIST/p|tail -n+2|head -n-1|sed s/^#//g

echo -e "\n"
}

###################
### MAIN        ###
###################

ARG_DEBUG=0
ARG_DETAILS=0
ARG_LIST_TARGETS=0
LOG_MAIN_STEP=INIT
LOG_STEP=GET_RMAN_PARAMETERS
ARG_LOGFILE=

[ -f $WORK_LIB/hotbackuprman.lib ] || { echo "Missing main library $WORK_LIB/hotbackuprman.lib"; exit 1; }
. $WORK_LIB/hotbackuprman.lib >/dev/null


# Trap the EXIT signal
trap do_exit EXIT


# Default config file is defined into hotbackuprman.lib
ARG_INPUT_FILE=$RMAN_CONFIG_FILE

while getopts t:ph:dc:lL:h option; do
    case "$option" in
        t) ARG_TARGET=$OPTARG ;;
        d) ARG_DEBUG=1 ;;
        c) ARG_INPUT_FILE=$OPTARG ;;
        l) ARG_LIST_TARGETS=1 ;;
        p) ARG_DETAILS=1 ;; 
        L) ARG_LOGFILE=$OPTARG ;;
        h) printSyntax; exit ;;
    esac
done
ARG_TARGET_DBNAME=$ARG_TARGET

if [ "$#" -eq 0 ]; then 
	printSyntax
fi

if [ -n "$ARG_LOGFILE" ]; then
    LOGFILE=$ARG_LOGFILE
else
    do_init
fi

[ $ARG_DETAILS -eq 1 ] && { all_parameters_details; exit; }

[ $ARG_LIST_TARGETS -eq 0 ] && [ -z "$ARG_TARGET" ] && log_error "Missing target name"

[ -f $ARG_INPUT_FILE ] || log_error "Missing the config file: $ARG_INPUT_FILE"

[ $ARG_LIST_TARGETS -eq 1 ] && { list_targets $ARG_INPUT_FILE; exit; }


if [ $ARG_DEBUG -eq 0 ]; then
    exec 6>&1 7>&2;
    exec >/dev/null ; #exec 2>&1
fi


[ $ARG_DEBUG -eq 1 ] && echo "+ Log File: $LOGFILE"
[ $ARG_DEBUG -eq 1 ] && echo "+ Loading DEFAULT parameters"

#log "DEBUG get_target_parameters_code=$get_target_parameters_code"


get_target_parameters $ARG_INPUT_FILE 'DEFAULT' && load_target_parameters "$get_target_parameters_code"
get_target_parameters_code_default=$get_target_parameters_code

[ $ARG_DEBUG -eq 1 ] && echo -e "$get_target_parameters_code_default"
[ $ARG_DEBUG -eq 1 ] && echo "+ Loading specific parameters for the target: $ARG_TARGET"

get_target_parameters $ARG_INPUT_FILE $ARG_TARGET && load_target_parameters "$get_target_parameters_code"
get_target_parameters_code_target=$get_target_parameters_code

[ $ARG_DEBUG -eq 1 ] && echo -e "$get_target_parameters_code_target"
[ $ARG_DEBUG -eq 1 ] && echo "+ Check all parameters"

log "Check mandatory parameters................."
check_mandatory_parameters

log "Check dynamic parameters................."
check_dynamic_parameters

log "Check optionnal parameters................."
check_optionnal_parameters


if [ $ARG_DEBUG -eq 0 ]; then
    # we enable STDOUT only for printing RMAN parameters
    exec 1>&6 6>&- ; exec 2>&7 7>&-
    output_parameters
    exec >/dev/null
fi


[ $ARG_DEBUG -eq 1 ] && echo "OK: We have a good configuration for the target $ARG_TARGET"
exit 0
