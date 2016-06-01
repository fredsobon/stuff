#!/bin/bash


# Author: David Larquey
# Last modified: dlarquey, Tue Jul 29 17:53:30 CEST 2014

# 29/10/2014    The retention parameter in years is now a hard setting
#               Check if the procedure to anonymize has the expected version

# This script is used to anonymize all datas for the SAV database, according to the CNIL compliance project


export PATH=$PATH:/usr/bin


ARG_DRYRUN='DEFAULT'

# Procedure used to anonymize
PROC="p_dba_table_anonymizor_SAV"
PROC_SCHEMA="dba"
# Expected version for the procedure to anonymize
EXPECTED_PROC_VERSION='1.0'

# Table to anonymize
TABLE_SCHEMA="SAV"
TABLE="SAVAdresse"

# Parameters used for the anonymization
DO_ANONYMIZATION='FALSE'

# Retention in years: All data who are older than the specified retention will be anonymized
ARG_RETENTION_YEARS=3

ARG_SLEEPTIME=30
ARG_BULKCOLLECT=5000


# Functions

printSyntax() {
cat <<EOS

$(basename $0) - CNIL - Anonymize data for the mysql SAV database

SYNTAX

    $(basename $0) <-n|-e> [-h] [-C bulk_collected_rows] [-S time]

This script is used to anonymize the SAV database
All datas older than $ARG_RETENTION_YEARS years will be anonymized

OPTIONAL
    -n          Dry run mode: DO NOTHING
    -e          Enable the anonymisation (disabled by default)
    -h          Print this help
    -C  rows    Number of rows to anonymize in a stripe (transaction)
                * The setting parameter in database overrides this one
                Default: $ARG_BULKCOLLECT
    -S  time    Sleep time (in seconds) between collecting 2 stripes
                * The setting parameter in database overrides this one
                Default: ${ARG_SLEEPTIME}s

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
    [ "x$test_proc" == "x${PROC_SCHEMA}.${PROC}" ] || logerror "Can't find the anonymization procedure: ${PROC_SCHEMA}.${PROC}. ABORT"
    
    test_table=$(mysql -sBN -e "SELECT concat(table_schema,'.',table_name) from information_schema.TABLES WHERE table_schema='$TABLE_SCHEMA' and table_name='$TABLE';")
    [ "x$test_table" == "x${TABLE_SCHEMA}.${TABLE}" ] || logerror "Can't find the target table to anonymize: ${TABLE_SCHEMA}.${TABLE}. ABORT"

    # Check if the version of the procedure to anonymize is the expexted one
    proc_version=$(mysql -sBN -e "CALL ${PROC_SCHEMA}.${PROC}('GET_VERSION', $ARG_RETENTION_YEARS, $ARG_BULKCOLLECT, $ARG_SLEEPTIME, FALSE);")
    [ "x${proc_version}" == "x${EXPECTED_PROC_VERSION}" ] || logerror "The version of the anonymization procedure (${proc_version}) does not match the expected one: <$EXPECTED_PROC_VERSION>. ABORT."

}


# MAIN
STDBUF=$(which stdbuf 2>/dev/null)
[ "x$(id -u)" == "x0" ] && logerror "Can't run under root privileges"
[ -n "$STDBUF" ] && [ -x $STDBUF ] || logerror "Can't find stdbuf"

# Get options
[ $# -lt 1 ] && printSyntax
while getopts r:neS:C:h option; do
    case "$option" in
        n) ARG_DRYRUN=1 ;;
        e) [ "$ARG_DRYRUN" == 'DEFAULT' ] && ARG_DRYRUN=0 ;;
        S) ARG_SLEEPTIME=$OPTARG ;;
        C) ARG_BULKCOLLECT=$OPTARG ;;
        h) printSyntax; exit ;;
    esac
done
# Dry run mode by default
[ "$ARG_DRYRUN" != '0' ] && ARG_DRYRUN=1
[ $ARG_DRYRUN -eq 0 ] && DO_ANONYMIZATION='TRUE'

echo "-----------------------------------------------------------------------------------------------------------------"
echo "- [$(date)] START the anonymization of the table: ${TABLE_SCHEMA}.${TABLE} older than $ARG_RETENTION_YEARS years"
echo "-----------------------------------------------------------------------------------------------------------------"

do_checks

log "ALL prerequisites checks are OK"
mode=
[ $ARG_DRYRUN -eq 1 ] && mode="in DRY RUN mode =======> Nothing will be done !!!!!!!"
log "STARTING the anonymization $mode..."

#CREATE PROCEDURE dba.p_dba_table_anonymizor_SAV (
#    IN v_proc_name VARCHAR(255), IN v_retention_years INTEGER, IN v_param_collect_rows INTEGER, IN v_param_db_sleep_time INTEGER, IN v_do_anonymize BOOLEAN
#)

# The sleep time and the bulk collected parameters could be overriden dynamically by the parameters defined into: "dba.dba_proc_params"
$STDBUF -oL mysql -e "CALL ${PROC_SCHEMA}.${PROC}('p_dba_table_anonymizor_SAV', $ARG_RETENTION_YEARS, $ARG_BULKCOLLECT, $ARG_SLEEPTIME, $DO_ANONYMIZATION);" 2>&1

