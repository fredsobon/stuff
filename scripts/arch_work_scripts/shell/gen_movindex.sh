sqlplus -s "/ as sysdba" << FINSQL

spool movindex.sql

   SET LINES        250
   SET PAGES        0

select 'alter index '||owner||'.'||INDEX_NAME||' nologging;'||chr(10)
||'alter index '||owner||'.'||INDEX_NAME||' rebuild tablespace IDX_XS01'||chr(10)
||'storage (initial 16K next 16K maxextents unlimited pctincrease 0);'||chr(10)
||'alter index '||owner||'.'||INDEX_NAME||' logging;'||chr(10)
||'analyze index '||owner||'.'||INDEX_NAME||' estimate statistics sample 20 percent;'
from dba_indexes
where TABLESPACE_NAME='CEWE_IDX';

spool off
FINSQL
