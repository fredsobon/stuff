#!/bin/bash


# Author: David Larquey
# Last modified: dlarquey, Tue Dec 16 13:14:27 CET 2014

# This script is used to purge/anonymize all personnal datas for the WEBCALL database, according to the CNIL compliance project

export PATH=$PATH:/usr/bin
ARG_DRYRUN='DEFAULT'

# Procedure used for the purge
PROC="p_dba_cnil_purge_webcall"
PROC_SCHEMA="dba"
# Expected procedure version for the main database treatment
EXPECTED_PROC_VERSION='1.0'

# Database to treat
TARGET_DB="webcall"

# Parameters used for the treatment
DO_TREATMENT='FALSE'
DO_DB_READ_HOT_PARAM='FALSE'
ARG_SLEEPTIME=30
ARG_BULKCOLLECT=5000
RETENTION_YEARS=5 # default data retention in years

# Functions

printSyntax() {
cat <<EOS

$(basename $0) - CNIL - Purge data for the mysql $TARGET_DB database

SYNTAX

    $(basename $0) <-n|-e> [-h] [-C bulk_collected_rows] [-S time]

This script is used to purge all personnal informations for the $TARGET_DB database
The data retention is hard fixed into the main database procedure: ${PROC_SCHEMA}.${PROC}
All personnal datas older than $RETENTION_YEARS years will be purged


PREREQUISITES

The main procedure and child procedures & functions used for the treatment must exists in the schema ${PROC_SCHEMA}
- ${PROC_SCHEMA}.p_dba_cnil_purge_webcall (MAIN procedure)
- ${PROC_SCHEMA}.f_dba_get_param_value (function)
- ${PROC_SCHEMA}.f_dba_update_param_value (procedure)

The log table and the configuration table must exists in the schema ${PROC_SCHEMA}
- ${PROC_SCHEMA}.purge_logs
- ${PROC_SCHEMA}.dba_proc_params


OPTIONAL
    -n          Dry run mode: DO NOTHING
    -e          Enable the purge (disabled by default)

    -C  rows    Number of rows to purge in a batch (transaction)
                    * The setting parameter in database overrides this one
                Default: $ARG_BULKCOLLECT
    -S  time    Sleep time (in seconds) between processing 2 batches
                    * The setting parameter in database overrides this one
                Default: ${ARG_SLEEPTIME}s
    -H          Enable the hot database configuration for parameters used by the procedure

    -h          Print this help

EOS
    exit
}

logerror() {
    echo "Error: $*" >&2
    exit 1
}

log() {
    echo "[$(date)] $*"
}

do_check_master() {
    test_slave=$(mysql -BN -e "show status like 'Slave_running'" 2>/dev/null|awk '{print $2}')
    [ "x$test_slave" == 'xOFF' ] || logerror "I'am not an active MASTER. Abort."
}

do_checks() {

    do_check_master

    test_proc=$(mysql -sBN -e "show procedure status like '$PROC';" 2>/dev/null|awk '{print $1"."$2}')
    [ "x$test_proc" == "x${PROC_SCHEMA}.${PROC}" ] || logerror "Can't find the main treatment procedure into the database: ${PROC_SCHEMA}.${PROC}. ABORT"
    
    count_tables=$(mysql -sBN -e "SELECT count(*) from information_schema.TABLES WHERE table_schema='$TARGET_DB'")
    [ $count_tables -gt 0 ] || logerror "Can't find the target database for the treatement: ${TARGET_DB} or the database is empty. ABORT"

    # Check if the version of the procedure is the expexted one
    proc_version=$(mysql -sBN -e "CALL ${PROC_SCHEMA}.${PROC}('GET_VERSION', $ARG_BULKCOLLECT, $ARG_SLEEPTIME, FALSE, FALSE);")
    [ "x${proc_version}" == "x${EXPECTED_PROC_VERSION}" ] || logerror "The version of the procedure (${proc_version}) does not match the expected one: <$EXPECTED_PROC_VERSION>. ABORT."

    # Check if the data retention is well hard fixed into the main procedure
    proc_retention=$(mysql -sBN -e "CALL ${PROC_SCHEMA}.${PROC}('GET_RETENTION', $ARG_BULKCOLLECT, $ARG_SLEEPTIME, FALSE, FALSE);")
    [ ${proc_retention} -ne $RETENTION_YEARS ] && logerror "The hard fixed data retention into the procedure '${PROC_SCHEMA}.${PROC}' (${proc_retention} years) does not match the expected one: ${RETENTION_YEARS} years. ABORT"

}


# MAIN
STDBUF=$(which stdbuf 2>/dev/null)
[ "x$(id -u)" == "x0" ] && logerror "Can't run under root privileges"
[ -n "$STDBUF" ] && [ -x $STDBUF ] || logerror "Can't find stdbuf"

# Get options
[ $# -lt 1 ] && printSyntax
while getopts r:neS:C:Hh option; do
    case "$option" in
        n) ARG_DRYRUN=1 ;;
        e) [ "$ARG_DRYRUN" == 'DEFAULT' ] && ARG_DRYRUN=0 ;;
        S) ARG_SLEEPTIME=$OPTARG ;;
        C) ARG_BULKCOLLECT=$OPTARG ;;
        H) DO_DB_READ_HOT_PARAM='TRUE' ;;
        h) printSyntax; exit ;;
    esac
done
# Dry run mode by default
[ "$ARG_DRYRUN" != '0' ] && ARG_DRYRUN=1
[ $ARG_DRYRUN -eq 0 ] && DO_TREATMENT='TRUE'

echo "--------------------------------------------------------------------"
echo "- [$(date)] START the CNIL treatment for the database: ${TARGET_DB}"
echo "--------------------------------------------------------------------"

do_checks

log "ALL prerequisites checks are OK"
mode=
[ $ARG_DRYRUN -eq 1 ] && mode="in DRY RUN mode =======> Nothing will be done !!!!!!!"
log "STARTING the treatment $mode..."

#CREATE PROCEDURE dba.p_dba_cnil_purge_webcall(
#    IN v_proc_name VARCHAR(255), IN v_param_collect_rows INTEGER, IN v_param_db_sleep_time INTEGER, IN v_param_debug BOOLEAN, IN v_do_purge BOOLEAN
#)


# The sleep time and the bulk collected parameters could be overriden dynamically by the parameters defined into the configuration table in the schema ${PROC_SCHEMA}

# Let's Go
echo "Running: CALL ${PROC_SCHEMA}.${PROC}('p_dba_cnil_purge_webcall', $ARG_BULKCOLLECT, $ARG_SLEEPTIME, $DO_DB_READ_HOT_PARAM, $DO_TREATMENT);"

$STDBUF -oL mysql -e "CALL ${PROC_SCHEMA}.${PROC}('p_dba_cnil_purge_webcall', $ARG_BULKCOLLECT, $ARG_SLEEPTIME, $DO_DB_READ_HOT_PARAM, $DO_TREATMENT);" 2>&1


