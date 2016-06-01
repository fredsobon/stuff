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
"

SQL="
select sql_all_luns.path,
sql_all_luns.header_status,
sql_all_luns.archi, sql_all_luns.env, sql_all_luns.db_role, sql_all_luns.instance, sql_all_luns.storage_pool, sql_all_luns.diskgroup, sql_all_luns.id_lun, sql_asymetric_luns.count
from (
select archi,env,db_role,instance,storage_pool,diskgroup,id_lun,count(*) count
from (
select
header_status
,regexp_replace(path, $REGEXP_PATH, '\1') archi
,regexp_replace(path, $REGEXP_PATH, '\2') env
,regexp_replace(path, $REGEXP_PATH, '\3') db_role
,regexp_replace(path, $REGEXP_PATH, '\4') instance
,regexp_replace(path, $REGEXP_PATH, '\5') datacenter
,regexp_replace(path, $REGEXP_PATH, '\6') storage_pool
,regexp_replace(path, $REGEXP_PATH, '\7') diskgroup
,regexp_replace(path, $REGEXP_PATH, '\8') id_lun
from v\$asm_disk
where 
regexp_like(path, $REGEXP_PATH)
) sql
group by archi,env,db_role,instance,storage_pool,diskgroup,id_lun
having count(*) != 2
) sql_asymetric_luns
, (
select path, header_status
,regexp_replace(path, $REGEXP_PATH, '\1') archi
,regexp_replace(path, $REGEXP_PATH, '\2') env
,regexp_replace(path, $REGEXP_PATH, '\3') db_role
,regexp_replace(path, $REGEXP_PATH, '\4') instance
,regexp_replace(path, $REGEXP_PATH, '\5') datacenter
,regexp_replace(path, $REGEXP_PATH, '\6') storage_pool
,regexp_replace(path, $REGEXP_PATH, '\7') diskgroup
,regexp_replace(path, $REGEXP_PATH, '\8') id_lun
from v\$asm_disk
where 
regexp_like(path, $REGEXP_PATH)
) sql_all_luns
where
sql_asymetric_luns.archi=sql_all_luns.archi
and sql_asymetric_luns.env=sql_all_luns.env
and sql_asymetric_luns.db_role=sql_all_luns.db_role
and sql_asymetric_luns.instance=sql_all_luns.instance
and sql_asymetric_luns.storage_pool=sql_all_luns.storage_pool
and sql_asymetric_luns.diskgroup=sql_all_luns.diskgroup
and sql_asymetric_luns.id_lun=sql_all_luns.id_lun
;"


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


############
### MAIN ###
############

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

