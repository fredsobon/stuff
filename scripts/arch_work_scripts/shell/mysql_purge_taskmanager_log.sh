#!/bin/bash


# Author: David Larquey
# Last modified: dlarquey, Thu Apr  2 13:44:17 CEST 2015

# This script is used to purge unused log partitions for taskmanager


export PATH=$PATH:/usr/bin
ARG_DRYRUN='DEFAULT'


# Table to purge
SCHEMA=taskmanager
TABLE=task_exec_log
# Ths table is partitioned by month
# The partition name is like 'pX' where X is the month index
PARTITION_PREFIX="p"

# SQL
SQL_LIST_PARTITIONS="PARTITION_NAME,TABLE_ROWS,AVG_ROW_LENGTH,ROUND(DATA_LENGTH/1024/1024) DATA_LENGTH_MB,ROUND(INDEX_LENGTH/1024/1024) INDEX_LENGTH_MB,DATA_FREE from information_schema.PARTITIONS where TABLE_SCHEMA='${SCHEMA}' and TABLE_NAME='${TABLE}'"

# Number of complete months to keep before the current date
# According to the retention, all datas aged from the previous month will be purged
# Must be greater or equal than 1 to avoid purging the previous or current month and lower than 12 because the table is partitioned by month and not by year and month !
MONTH_RETENTION=2


# Functions

printSyntax() {
cat <<EOS

$(basename $0) - Purge unused log partitions for taskmanager

SYNTAX

    $(basename $0) <-n|-e> [-h]

This script is used to purge old partitions of the table ${SCHEMA}.${TABLE}

MODE
    -n          Dry run mode: DO NOTHING
    -e          Enable the anonymisation (disabled by default)

OPTIONAL
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

    [ $MONTH_RETENTION -lt 1 ] && logerror "We can't purge the previous or the current month !"
    test_table=$(mysql -sBN -e "SELECT concat(table_schema,'.',table_name) from information_schema.TABLES WHERE table_schema='$SCHEMA' and table_name='$TABLE';")
    [ "x$test_table" == "x${SCHEMA}.${TABLE}" ] || logerror "Can't find the target table to anonymize: ${SCHEMA}.${TABLE}. ABORT"

}


is_integer() {
    local a=$1
    echo $a|egrep -q '^[0-9]+'
    return $?
}




# MAIN
PARTITION_TO_PURGE=
STDBUF=$(which stdbuf 2>/dev/null)
[ "x$(id -u)" == "x0" ] && logerror "Can't run under root privileges"
[ -n "$STDBUF" ] && [ -x $STDBUF ] || logerror "Can't find stdbuf"

# Get options
[ $# -lt 1 ] && printSyntax
while getopts neh option; do
    case "$option" in
        n) ARG_DRYRUN=1 ;;
        e) [ "$ARG_DRYRUN" == 'DEFAULT' ] && ARG_DRYRUN=0 ;;
        h) printSyntax; exit ;;
    esac
done
# Dry run mode by default
[ "$ARG_DRYRUN" != '0' ] && ARG_DRYRUN=1
[ $ARG_DRYRUN -eq 0 ] && DO_ANONYMIZATION='TRUE'

# get the month to purge
CUR_MONTH=$(date +%m|sed s/^0//)
is_integer $CUR_MONTH || logerror "$CUR_MONTH  is not a valid month"
([ $CUR_MONTH -ge 1 ] && [ $CUR_MONTH -le 12 ]) || logerror "$CUR_MONTH is not a valid month"
PURGE_LAST_N_MONTH=$((MONTH_RETENTION + 1))
if [ $CUR_MONTH -le $PURGE_LAST_N_MONTH ]; then
    MONTH_INDEX_TO_PURGE=$((12+${CUR_MONTH}-${PURGE_LAST_N_MONTH}))
else
    MONTH_INDEX_TO_PURGE=$((${CUR_MONTH}-${PURGE_LAST_N_MONTH}))
fi
is_integer $MONTH_INDEX_TO_PURGE || logerror "Invalid month index concerned for the purge: $MONTH_INDEX_TO_PURGE"
[ $MONTH_INDEX_TO_PURGE -eq $CUR_MONTH ] && logerror "The month to purge can't be the current month !"



do_checks
PARTITION_TO_PURGE=$(mysql -sBN -e "select PARTITION_NAME from information_schema.PARTITIONS where TABLE_SCHEMA='${SCHEMA}' and TABLE_NAME='${TABLE}'" | egrep "^${PARTITION_PREFIX}${MONTH_INDEX_TO_PURGE}$")
[ -z "$PARTITION_TO_PURGE" ] && logerror "Can't find the partition '${PARTITION_PREFIX}${MONTH_INDEX_TO_PURGE}' for the table ${SCHEMA}.${TABLE}"

echo "-----------------------------------------------------------------------------------------------------------------"
echo "- [$(date)] START the purge of the partition '${PARTITION_TO_PURGE}' for the table ${SCHEMA}.${TABLE}"
echo "-----------------------------------------------------------------------------------------------------------------"


log "ALL prerequisites checks are OK"
log "Current Month index: $CUR_MONTH"
log "Month index before concerned by the purge: $MONTH_INDEX_TO_PURGE"
log "Partition to purge: ${SCHEMA}.${TABLE}.${PARTITION_TO_PURGE}"
log "List all partitions for the table ${SCHEMA}.${TABLE}"
$STDBUF -oL mysql -e "select $SQL_LIST_PARTITIONS" 2>&1
log "List the partition concerned for the purge:"
$STDBUF -oL mysql -e "select $SQL_LIST_PARTITIONS and PARTITION_NAME='${PARTITION_TO_PURGE}'" 2>&1

if [ $ARG_DRYRUN -eq 1 ]; then
    echo "DRY RUN mode =======> Nothing will be done !!!!!!!"
    exit
fi

# Do the purge
SQL_PURGE="ALTER TABLE ${SCHEMA}.${TABLE} TRUNCATE PARTITION ${PARTITION_TO_PURGE}"
log "SQL used for the purge: $SQL_PURGE"
log "PURGE: Launching the purge of the partition: ${SCHEMA}.${TABLE}.${PARTITION_TO_PURGE}"

$STDBUF -oL mysql -e "$SQL_PURGE" 2>&1

log "PURGE: The purge treatment has finished"
log "PURGE: List all partitions for the table: ${SCHEMA}.${TABLE}"
$STDBUF -oL mysql -e "select $SQL_LIST_PARTITIONS" 2>&1

