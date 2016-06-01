#!/bin/ksh

# dlarquey @ E-merchant
# Last modified: Tue Dec 22 17:35:00 CET 2015

ORATAB=/etc/oratab
REGEXP_PATH="'^/dev/mapper/([a-z]+[0-9]+)([p|ud])([a-z])([0-9]+)_dc([0-9]+)z([0-9]+)_([a-z0-9]+)_([0-9]+)(.*$)'"

SQLPLUS_OPTS="
set linesize 256
col path format a36
col header_status format a14
col archi format a12
col env format a6
col db_role format a10
col instance format a10
col datacenter format a12
col storage_pool format a16
col diskgroup format a16
col id_lun format a6

col header_status_disk1 format a16
col header_status_disk2 format a16
col path_disk1 format a36
col path_disk2 format a36
col sql format a256
"

SQL_GET_SYM_INFOS="
sql_all_luns_1.diskgroup,
sql_all_luns_1.id_lun,
sql_all_luns_1.path path_disk1,
sql_all_luns_2.path path_disk2,
sql_all_luns_1.header_status header_status_disk1,
sql_all_luns_2.header_status header_status_disk2"

function gendynsql_alter {
SQL_GEN_SYM_DISK_TO_ADD="
'--------- '||upper(sql_all_luns_1.diskgroup)||'#'||sql_all_luns_1.id_lun||' ---------'||chr(10)
||'ALTER DISKGROUP DG_'||upper(sql_all_luns_1.diskgroup)||' ADD '||chr(10)
||chr(9)||'FAILGROUP '||sql_all_luns_1.diskgroup||'_dc'||sql_all_luns_1.datacenter||' DISK '''||'/dev/mapper/'||sql_all_luns_1.archi||sql_all_luns_1.env||sql_all_luns_1.db_role||sql_all_luns_1.instance||'_dc'||sql_all_luns_1.datacenter||'z'||sql_all_luns_1.storage_pool||'_'||sql_all_luns_1.diskgroup||'_'||sql_all_luns_1.id_lun
|| ''' NAME '||upper('DC'||sql_all_luns_1.datacenter||sql_all_luns_1.diskgroup)||lpad(sql_all_luns_1.id_lun, 2, '0')||chr(10)
||chr(9)||'FAILGROUP '||sql_all_luns_1.diskgroup||'_dc'||sql_all_luns_2.datacenter||' DISK '''||'/dev/mapper/'||sql_all_luns_1.archi||sql_all_luns_1.env||sql_all_luns_1.db_role||sql_all_luns_1.instance||'_dc'||sql_all_luns_2.datacenter||'z'||sql_all_luns_1.storage_pool||'_'||sql_all_luns_1.diskgroup||'_'||sql_all_luns_1.id_lun
|| ''' NAME '||upper('DC'||sql_all_luns_2.datacenter||sql_all_luns_1.diskgroup)||lpad(sql_all_luns_1.id_lun, 2, '0')||chr(10)
||chr(9)||'REBALANCE POWER '||$REBALANCE_POWER||';' \"---\""
}

function gendynsql {
SQL_GET_SYMETRIC_DISKS="
SELECT $SQL_SYM_SELECT
FROM (
SELECT header_status,archi,env,db_role,instance,storage_pool,diskgroup,id_lun,count(*) count
FROM (
SELECT
header_status
,regexp_replace(path, $REGEXP_PATH, '\1') archi
,regexp_replace(path, $REGEXP_PATH, '\2') env
,regexp_replace(path, $REGEXP_PATH, '\3') db_role
,regexp_replace(path, $REGEXP_PATH, '\4') instance
,regexp_replace(path, $REGEXP_PATH, '\5') datacenter
,regexp_replace(path, $REGEXP_PATH, '\6') storage_pool
,regexp_replace(path, $REGEXP_PATH, '\7') diskgroup
,regexp_replace(path, $REGEXP_PATH, '\8') id_lun
FROM v\$asm_disk
WHERE 
regexp_like(path, $REGEXP_PATH)
) sql
group by header_status,archi,env,db_role,instance,storage_pool,diskgroup,id_lun
having count(*) = 2
) sql_available_symetric_luns
, (
SELECT path, header_status
,regexp_replace(path, $REGEXP_PATH, '\1') archi
,regexp_replace(path, $REGEXP_PATH, '\2') env
,regexp_replace(path, $REGEXP_PATH, '\3') db_role
,regexp_replace(path, $REGEXP_PATH, '\4') instance
,regexp_replace(path, $REGEXP_PATH, '\5') datacenter
,regexp_replace(path, $REGEXP_PATH, '\6') storage_pool
,regexp_replace(path, $REGEXP_PATH, '\7') diskgroup
,regexp_replace(path, $REGEXP_PATH, '\8') id_lun
FROM v\$asm_disk
WHERE 
regexp_like(path, $REGEXP_PATH)
) sql_all_luns_1
, (
SELECT path, header_status
,regexp_replace(path, $REGEXP_PATH, '\1') archi
,regexp_replace(path, $REGEXP_PATH, '\2') env
,regexp_replace(path, $REGEXP_PATH, '\3') db_role
,regexp_replace(path, $REGEXP_PATH, '\4') instance
,regexp_replace(path, $REGEXP_PATH, '\5') datacenter
,regexp_replace(path, $REGEXP_PATH, '\6') storage_pool
,regexp_replace(path, $REGEXP_PATH, '\7') diskgroup
,regexp_replace(path, $REGEXP_PATH, '\8') id_lun
FROM v\$asm_disk
WHERE 
regexp_like(path, $REGEXP_PATH)
) sql_all_luns_2
WHERE
sql_available_symetric_luns.archi = sql_all_luns_1.archi
and sql_available_symetric_luns.env = sql_all_luns_1.env
and sql_available_symetric_luns.db_role = sql_all_luns_1.db_role
and sql_available_symetric_luns.instance = sql_all_luns_1.instance
and sql_available_symetric_luns.storage_pool = sql_all_luns_1.storage_pool
and sql_available_symetric_luns.diskgroup = sql_all_luns_1.diskgroup
and sql_available_symetric_luns.id_lun = sql_all_luns_1.id_lun
and sql_all_luns_1.env = sql_all_luns_2.env
and sql_all_luns_1.db_role = sql_all_luns_2.db_role
and sql_all_luns_1.instance = sql_all_luns_2.instance
and sql_all_luns_1.storage_pool = sql_all_luns_2.storage_pool
and sql_all_luns_1.diskgroup = sql_all_luns_2.diskgroup
and sql_all_luns_1.id_lun = sql_all_luns_2.id_lun
and sql_all_luns_1.datacenter < sql_all_luns_2.datacenter
and sql_available_symetric_luns.header_status = sql_all_luns_1.header_status
and sql_all_luns_1.header_status = sql_all_luns_2.header_status
and sql_available_symetric_luns.header_status = 'CANDIDATE'
order by sql_available_symetric_luns.diskgroup, sql_available_symetric_luns.id_lun
;"
}

SQL_GET_ALL_AVAILABLE_DISKS="
SELECT path, header_status
,regexp_replace(path, $REGEXP_PATH, '\1') archi
,regexp_replace(path, $REGEXP_PATH, '\2') env
,regexp_replace(path, $REGEXP_PATH, '\3') db_role
,regexp_replace(path, $REGEXP_PATH, '\4') instance
,regexp_replace(path, $REGEXP_PATH, '\5') datacenter
,regexp_replace(path, $REGEXP_PATH, '\6') storage_pool
,regexp_replace(path, $REGEXP_PATH, '\7') diskgroup
,regexp_replace(path, $REGEXP_PATH, '\8') id_lun
FROM v\$asm_disk
WHERE 
regexp_like(path, $REGEXP_PATH)
and header_status = 'CANDIDATE'
order by diskgroup, id_lun
;"




function gendynsql_preferred_read_path {
DC=$(hostname -f|egrep -o '\.(prod|uat|dev)\.[^\.]+\.'|cut -d'.' -f3)
SQL_GEN_PREFERRED_READ_PATH="
SELECT 'ALTER SYSTEM SET asm_preferred_read_failure_groups = '
|| LISTAGG(''''||name||'.'||replace(lower(name||'_$DC'), 'dg_', '')||'''', ',') WITHIN GROUP (order by name) \"---\"
FROM v\$asm_diskgroup;
"
}




#################
### Functions ###
#################


function error {
    echo "Error: $*" 2>&1
    exit 1
}

function getenv {
    ORASID=$(grep '^+ASM' $ORATAB|cut -d':' -f1)
    ORAHOME=$(grep '^+ASM' $ORATAB|cut -d':' -f2)
    [ -z "$ORASID" -o -z "$ORAHOME" ] && error "Can't find ASM instance"
    export ORACLE_HOME=$ORAHOME
    export ORACLE_SID=$ORASID
    unset ORA_NLS10
}

function usage {

    cat <<EOS
$PROG

    * For E-Merchant internal usage only *
    The LUNs name must strictly respect the E-Merchant naming convention
    Example: /dev/mapper/erac1pa1_dc2z2_index_3

SYNOPSIS

    Get infos for Oracle ASM available disks
    Generate SQL commands for Oracle ASM disks and diskgroups

    -a      Get all available disks for ASM
    -s      Get all available symetric disks for ASM on the expected diskgroup
    -g      Generate the SQL command to add symetric disks for ASM
    -p      Parallelism to apply (rebalance power) when adding a disk
            Only available when using the '-g' option
    -r      Generate the SQL command to apply for setting the ASM preferred read path
    -h      This help


EXAMPLES

# To generate SQL commands to add symetric LUNs with a parallelism of 4:
    $PROG -g -p 4

EOS

    exit 2

}



############
### MAIN ###
############

PROG=$(basename $0)
ARG_GET_ALL_AVAILABLE_DISKS=0
ARG_GET_SYM_DISKS=0
ARG_GEN_SYM_DISKS=0
ARG_SQL_GEN_PREFERRED_READ_PATH=0
REBALANCE_POWER=1

[ $# -eq 0 ] && usage

while getopts 'asghp:r' option; do
  case "${option}" in
    a) ARG_GET_ALL_AVAILABLE_DISKS=1 ;;
    s) ARG_GET_SYM_DISKS=1 ;;
    g) ARG_GEN_SYM_DISKS=1 ;;
    p) REBALANCE_POWER=$OPTARG ;;
    r) ARG_SQL_GEN_PREFERRED_READ_PATH=1 ;;
    h) usage ;;
    *) error "Unexpected option ${option}" ; usage ;;
  esac
done


if [ $ARG_GET_ALL_AVAILABLE_DISKS -eq 1 ]; then
    SQL=$SQL_GET_ALL_AVAILABLE_DISKS
elif [ $ARG_GET_SYM_DISKS -eq 1 ]; then
    SQL_SYM_SELECT=$SQL_GET_SYM_INFOS
    gendynsql
    SQL=$SQL_GET_SYMETRIC_DISKS
elif [ $ARG_GEN_SYM_DISKS -eq 1 ]; then
    echo $REBALANCE_POWER | egrep -q '^[0-9]+$' || error "The parallelism must be an integer"
    gendynsql_alter
    SQL_SYM_SELECT=$SQL_GEN_SYM_DISK_TO_ADD
    gendynsql
    SQL=$SQL_GET_SYMETRIC_DISKS
    SQLPLUS_OPTS="$SQLPLUS_OPTS
set pagesize 0 head off"
elif [ $ARG_SQL_GEN_PREFERRED_READ_PATH -eq 1 ]; then
    gendynsql_preferred_read_path
    SQL=$SQL_GEN_PREFERRED_READ_PATH
    SQLPLUS_OPTS="$SQLPLUS_OPTS
set pagesize 0 head off"
fi

getenv
tmpfile=$(mktemp)

sqlplus -s <<EOS / as sysdba >$tmpfile
$SQLPLUS_OPTS
set feedback off
set time off timing off
set termout off
set trim on trimspool on
set echo off

$SQL
EOS

cat $tmpfile
rm -f $tmpfile

