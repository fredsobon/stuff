#!/bin/sh
#
#########################################################################################
#                                                                                       #
# Verification des requetes les plus consomatrice                                       #
#                                                                                       #
# Auteur : Maziar GHAZALI (DBA), David LARQUEY (DBA)                                    #
# Data de creation : 12/11/2013                                                         #
#                                                                                       #
#########################################################################################



# This script extracts the top 5 sql requests that consummes the most CPU, IO and Memory resources
# You must specify oracle the instance name as parameter
# Try -h option for help
# It writes it's temporary files into /tmp/SCRIPT_NAME


TOP=5 # Number of sql requests to extract

# Enable the debug mode by default
# This mode displays all executed sql requests
DEBUG=1

# Files
SCRIPT=$(basename $0)
SCRIPTNAME=${SCRIPT%%.*}

# Email
SEND_MAIL=1
SENDMAIL='/usr/sbin/sendmail -t'
EMAILALL_CUSTOMERS="it.prod.dba@pixmania-group.com it.dev.managers@pixmania-group.com"

# sql
SQLPLUS_OPTS="set lines 100 pages 9999 echo off verify off head off feed off serveroutput on timing off time off term off long 1024"
PATTERN_START_DATA="---START_DATA---"



#################
### Functions ###
#################

printsyntax() {
cat <<EOT
$(basename $0) - Executing TOP 5 consuming requests

    -i  Oracle instance name
    -a  Disable the debug mode. Send the report mail to the customers
    -d  Enable the debug mode. This mode is enabled by default
        This mode displays all executed sql requests and send report mail to the operators
    -h  This help
EOT
    exit
}


send_email() {
    MAILTO="$1"
    SUBJECT="$2"
    BODY="$3"
    mail_body_file=$(mktemp -t ${SCRIPTNAME}_${ORACLE_SID}.email.XXX)

    echo "Send mail to: $MAILTO"
    cat >$mail_body_file <<EOM
From: Monitoring DBA <no-reply@e-merchant.com>
To: $MAILTO
Subject: $SUBJECT
Mime-Version: 1.0
Content-Type: text/plain; charset=utf-8
Content-Transfer-Enconding: 8bit
EOM
    echo -e "\n$BODY\n" >>$mail_body_file
    cat $mail_body_file | eval $SENDMAIL
    rm -f $mail_body_file
}

# input: file $MAILFILE
send_mail() {
    if [ $SEND_MAIL -eq 1 ]; then
        send_email "$EMAILALL" "$EMAIL_OBJECT" "`cat -s $MAILFILE`"
    fi
}


# database role
get_db_role() {
    DB_ROLE=
    temp_file=$(mktemp -t ${SCRIPTNAME}_${ORACLE_SID}.getdbrole.XXX)
    SQL_DB_ROLE='select database_role from v$database;'

    ${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" << EOSQL >${temp_file}
--- Options
$SQLPLUS_OPTS

exec dbms_output.put_line('$PATTERN_START_DATA');
$SQL_DB_ROLE

EOSQL

    # Datas are separated from the headers by a line started with '-'
    cat -s $temp_file|sed -n "/^${PATTERN_START_DATA}/,\$p"|tail -n+2 >$MON_DB_ROLE
    rm -f ${temp_file}
    DB_ROLE=`cat $MON_DB_ROLE|egrep 'PRIMARY|STANDBY'`
    echo "Database role: <$DB_ROLE>"
    [ -z "$DB_ROLE" ] && return 1
    return 0
}

check_db_role() {
    get_db_role || { echo "Can't determine the database role"; exit 1; }
}


do_check_only_if_primary_mode() {
    check_db_role
    [ "$DB_ROLE" != 'PRIMARY' ] && { echo "The database is not on PRIMARY Mode ($DB_ROLE). Nothing to do"; exit 1; }
}


init_sql() {

### CPU ###
SQL_CPU="select sql_id, executions_total, cpu_time_total_s, iowait_total_s, cpu_time_total_s_per_execution, SQL_FULLTEXT
from
(
select a.SQL_FULLTEXT,
       s.sql_id,
       s.module,
       s.cpu_time_total / 1000000 as cpu_time_total_s,
       (s.cpu_time_total / 1000000)/DECODE(s.executions_total, 0, 1, s.executions_total) as cpu_time_total_s_per_execution,
       s.iowait_total / 1000000 as iowait_total_s,
       s.fetches_total,
       s.sorts_total,
       s.executions_total,
       s.loads_total,
       s.disk_reads_total,
       s.direct_writes_total / 1024,
       s.buffer_gets_total,
       s.rows_processed_total,
       s.elapsed_time_total / 1000000,
       s.apwait_total / 1000000,
       s.ccwait_total / 1000000,
       s.plsexec_time_total / 1000000,
       s.javexec_time_total / 1000000
       from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT h, v\$sqlarea a
       where s.executions_total != 0
         and s.INSTANCE_NUMBER = h.INSTANCE_NUMBER
         and s.snap_id = h.snap_id
         and a.SQL_ID = s.sql_id
         and h.begin_interval_time > timestamp'$DATE_BEGIN'
         and h.end_interval_time < timestamp'$DATE_END'
         order by cpu_time_total_s desc
)where rownum <= $TOP;"

SQL_CPU_PER_EXEC="select sql_id, executions_total, cpu_time_total_s, iowait_total_s, cpu_time_total_s_per_execution, SQL_FULLTEXT
from
(
select a.SQL_FULLTEXT,
       s.sql_id,
       s.module,
       s.cpu_time_total / 1000000 as cpu_time_total_s,
       (s.cpu_time_total / 1000000)/DECODE(s.executions_total, 0, 1, s.executions_total) as cpu_time_total_s_per_execution,
       s.iowait_total / 1000000 as iowait_total_s,
       s.fetches_total,
       s.sorts_total,
       s.executions_total,
       s.loads_total,
       s.disk_reads_total,
       s.direct_writes_total / 1024,
       s.buffer_gets_total,
       s.rows_processed_total,
       s.elapsed_time_total / 1000000,
       s.apwait_total / 1000000,
       s.ccwait_total / 1000000,
       s.plsexec_time_total / 1000000,
       s.javexec_time_total / 1000000
       from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT h, v\$sqlarea a
       where s.executions_total != 0
         and s.INSTANCE_NUMBER = h.INSTANCE_NUMBER
         and s.snap_id = h.snap_id
         and a.SQL_ID = s.sql_id
         and h.begin_interval_time > timestamp'$DATE_BEGIN'
         and h.end_interval_time < timestamp'$DATE_END'
         order by (s.cpu_time_total / 1000000)/DECODE(s.executions_total, 0, 1, s.executions_total) desc
)where rownum <= $TOP;"


### IO ###
SQL_IO="select SQL_ID, executions_total, disk_reads_total, reads_per_execution, SQL_FULLTEXT
from
(
select a.SQL_FULLTEXT,
             s.sql_id,
             s.module,
             s.cpu_time_total / 1000000,
             s.iowait_total / 1000000,
             s.fetches_total,
             s.sorts_total,
             s.executions_total,
             s.loads_total,
             s.disk_reads_total,
             (s.disk_reads_total /DECODE(s.executions_total, 0, 1, s.executions_total)) reads_per_execution,
             s.direct_writes_total / 1024,
             s.buffer_gets_total,
             s.rows_processed_total,
             s.elapsed_time_total / 1000000,
             s.apwait_total / 1000000,
             s.ccwait_total / 1000000,
             s.plsexec_time_total / 1000000,
             s.javexec_time_total / 1000000
        from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT h, v\$sqlarea a
       where s.executions_total != 0
         and s.INSTANCE_NUMBER = h.INSTANCE_NUMBER
         and s.snap_id = h.snap_id
         and a.SQL_ID = s.sql_id
         and h.begin_interval_time > timestamp'$DATE_BEGIN'
         and h.end_interval_time < timestamp'$DATE_END'
         order by disk_reads_total desc
)where rownum <= 5;"

SQL_IO_PER_EXEC="select SQL_ID, executions_total, disk_reads_total, reads_per_execution, SQL_FULLTEXT
from
(
select a.SQL_FULLTEXT,
             s.sql_id,
             s.module,
             s.cpu_time_total / 1000000,
             s.iowait_total / 1000000,
             s.fetches_total,
             s.sorts_total,
             s.executions_total,
             s.loads_total,
             s.disk_reads_total,
             (s.disk_reads_total /DECODE(s.executions_total, 0, 1, s.executions_total)) reads_per_execution,
             s.direct_writes_total / 1024,
             s.buffer_gets_total,
             s.rows_processed_total,
             s.elapsed_time_total / 1000000,
             s.apwait_total / 1000000,
             s.ccwait_total / 1000000,
             s.plsexec_time_total / 1000000,
             s.javexec_time_total / 1000000
        from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT h, v\$sqlarea a
       where s.executions_total != 0
         and s.INSTANCE_NUMBER = h.INSTANCE_NUMBER
         and s.snap_id = h.snap_id
         and a.SQL_ID = s.sql_id
         and h.begin_interval_time > timestamp'$DATE_BEGIN'
         and h.end_interval_time < timestamp'$DATE_END'
         order by reads_per_execution desc
)where rownum <= 5;"


### MEM ###
SQL_MEM="select SQL_ID, executions_total, rows_processed_total, buffer_gets_total, SQL_FULLTEXT
from
(
select a.SQL_FULLTEXT,
             s.sql_id,
             s.module,
             s.cpu_time_total / 1000000,
             s.iowait_total / 1000000,
             s.fetches_total,
             s.sorts_total,
             s.executions_total,
             s.loads_total,
             s.disk_reads_total,
             s.direct_writes_total / 1024,
             s.buffer_gets_total,
             s.rows_processed_total,
             (s.buffer_gets_total/DECODE(s.executions_total, 0, 1, s.executions_total)) bgets_total_per_execution,
             (s.rows_processed_total/DECODE(s.executions_total, 0, 1, s.executions_total)) rows_total_per_execution,
             s.elapsed_time_total / 1000000,
             s.apwait_total / 1000000,
             s.ccwait_total / 1000000,
             s.plsexec_time_total / 1000000,
             s.javexec_time_total / 1000000
        from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT h, v\$sqlarea a
       where s.executions_total != 0
         and s.INSTANCE_NUMBER = h.INSTANCE_NUMBER
         and s.snap_id = h.snap_id
         and a.SQL_ID = s.sql_id
         and h.begin_interval_time > timestamp'$DATE_BEGIN'
         and h.end_interval_time < timestamp'$DATE_END'
         order by buffer_gets_total desc
)where rownum <= 5;"

SQL_MEM_PER_EXEC="select SQL_ID, executions_total, rows_processed_total, buffer_gets_total, SQL_FULLTEXT
from
(
select a.SQL_FULLTEXT,
             s.sql_id,
             s.module,
             s.cpu_time_total / 1000000,
             s.iowait_total / 1000000,
             s.fetches_total,
             s.sorts_total,
             s.executions_total,
             s.loads_total,
             s.disk_reads_total,
             s.direct_writes_total / 1024,
             s.buffer_gets_total,
             s.rows_processed_total,
             (s.buffer_gets_total/DECODE(s.executions_total, 0, 1, s.executions_total)) bgets_total_per_execution,
             (s.rows_processed_total/DECODE(s.executions_total, 0, 1, s.executions_total)) rows_total_per_execution,
             s.elapsed_time_total / 1000000,
             s.apwait_total / 1000000,
             s.ccwait_total / 1000000,
             s.plsexec_time_total / 1000000,
             s.javexec_time_total / 1000000
        from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT h, v\$sqlarea a
       where s.executions_total != 0
         and s.INSTANCE_NUMBER = h.INSTANCE_NUMBER
         and s.snap_id = h.snap_id
         and a.SQL_ID = s.sql_id
         and h.begin_interval_time > timestamp'$DATE_BEGIN'
         and h.end_interval_time < timestamp'$DATE_END'
         order by (s.buffer_gets_total/DECODE(s.executions_total, 0, 1, s.executions_total)) desc
)where rownum <= 5;"

}


myexit() {
    # purge
    rm -f $MON_DB_ROLE $TEMPFILE
#    rm -f $OUTPUTFILE
#    rm -f $MAILFILE
    rm -f $LOCKFILE
}




############
### MAIN ###
############

# Args
SCRIPTNAME=$(basename $0)
ARG_INSTANCE_NAME=
while getopts i:dah option; do
    case "$option" in
        i) ARG_INSTANCE_NAME=${OPTARG} ;;
        a) DEBUG=0 ;;
        d) DEBUG=1 ;;
        h) printsyntax ;;
    esac
done

[ $(id -u) -eq 0 ] && { echo "Can't run under root privileges"; exit 1; }
[ -n "$ARG_INSTANCE_NAME" ] || { echo "Missing the oracle instance name parameter"; printsyntax ; exit 1; }
if [ $DEBUG -eq 0 ]; then
    EMAILALL=$EMAILALL_CUSTOMERS
else
    EMAILALL="m.ghazali@pixmania-group.com d.larquey@pixmania-group.com"
fi

export LANG=en_US.utf8
export TMPDIR=/tmp/${SCRIPTNAME%%.*}
export ORACLE_SID=`cat  /etc/oratab|grep -iv "#"|grep -iw $ARG_INSTANCE_NAME|cut -d: -f1`
export ORACLE_HOME=`cat /etc/oratab|grep -iv "#"|grep -iw $ARG_INSTANCE_NAME|cut -d: -f2`
[ -n "${ORACLE_SID}" ] || { echo "Can't set ORACLE_SID"; exit 1; }
[ -d "${ORACLE_HOME}" ] || { echo "Oracle Home soes not exist: ${ORACLE_HOME}"; exit 1; }
export PATH=$PATH:${ORACLE_HOME}/bin

# Files
LOCKFILE=${TMPDIR}/${SCRIPTNAME}_${ORACLE_SID}.lock
OUTPUTFILE=$TMPDIR/${SCRIPTNAME}_${ORACLE_SID}.output
TEMPFILE=$TMPDIR/${SCRIPTNAME}_${ORACLE_SID}.tmp
MAILFILE=$TMPDIR/${SCRIPTNAME}_${ORACLE_SID}.mail
lastexec_filename=$TMPDIR/${SCRIPTNAME}_${ORACLE_SID}.last_exec_time
MON_DB_ROLE=${TMPDIR}/${SCRIPTNAME}_${ORACLE_SID}.role

# email
EMAIL_OBJECT="[DBA_REPORTING][$ORACLE_SID] TOP 5 consuming requests"

# Output
mkdir -p $TMPDIR || { echo "Can't create directory: $TMPDIR"; exit 1; }
>$MAILFILE
exec >$OUTPUTFILE
exec 2>&1

# Lockfile
[ -f $LOCKFILE ] && { echo "Lock file already exists: $LOCKFILE"; exit 1; }
touch $LOCKFILE
trap myexit EXIT

which sqlplus >/dev/null 2>&1 || { echo "Can't find the binary sqlplus"; exit 1; }

# Check if primary database
do_check_only_if_primary_mode

# set start and end dates
if [ -f $lastexec_filename ]; then
    echo "Found last exec time file: $lastexec_filename"
    DATE_BEGIN=`date +'%Y-%m-%d %H' -d@$(stat -c %Y $lastexec_filename)`
else
    DATE_BEGIN=`date +'%Y-%m-%d %H' -d "12 hours ago"`
fi
DATE_END=`date +'%Y-%m-%d %H'`
DATE_BEGIN="${DATE_BEGIN}:00:00"
DATE_END="${DATE_END}:00:00"
echo
echo "+ DATE_BEGIN: $DATE_BEGIN"
echo "+ DATE_END: $DATE_END"

if [ "$DATE_BEGIN" == "$DATE_END" ]; then
    echo "Start and End date are the same. Nothing to do."
    echo "Deleting the last exec time file"
    echo "Please run it again."
    rm -f $lastexec_filename
    exit 1
fi

# Define sql requests
init_sql


# Let's GO
echo "+ DATE_BEGIN: $DATE_BEGIN" >$MAILFILE
echo "+ DATE_END: $DATE_END" >>$MAILFILE

# CPU usage
> $TEMPFILE
echo "\n\n############################## ~ top 5 CPU consuming requests ~ ##############################" >>$MAILFILE
echo "# Global statistics" >>$MAILFILE
sqlplus -s <<EOS
conn / as sysdba
$SQLPLUS_OPTS
spool $TEMPFILE;
$SQL_CPU
spool off;
quit;
EOS
echo $SQL_CPU|sed 's/ from .*//'|sed 's/select //'|tr ',' '\t\t'|tr '[a-z]' '[A-Z]' >>$MAILFILE
cat -s $TEMPFILE >>$MAILFILE

echo -e "\n# Per execution statistics" >>$MAILFILE
sqlplus -s <<EOS
conn / as sysdba
$SQLPLUS_OPTS
spool $TEMPFILE;
$SQL_CPU_PER_EXEC
spool off;
quit;
EOS
echo $SQL_CPU_PER_EXEC|sed 's/ from .*//'|sed 's/select //'|tr ',' '\t\t'|tr '[a-z]' '[A-Z]' >>$MAILFILE
cat -s $TEMPFILE >>$MAILFILE


# IO usage
> $TEMPFILE
echo -e "\n\n############################## ~ top 5 IO consuming requests ~ ##############################" >>$MAILFILE
echo "# Global statistics" >>$MAILFILE
sqlplus -s <<EOS
conn / as sysdba
$SQLPLUS_OPTS
spool $TEMPFILE;
$SQL_IO
spool off;
quit;
EOS
echo $SQL_IO|sed 's/ from .*//'|sed 's/select //'|tr ',' '\t\t'|tr '[a-z]' '[A-Z]' >>$MAILFILE
cat -s $TEMPFILE >>$MAILFILE

echo -e "\n# Per execution statistics" >>$MAILFILE
sqlplus -s <<EOS
conn / as sysdba
$SQLPLUS_OPTS
spool $TEMPFILE;
$SQL_IO_PER_EXEC
spool off;
quit;
EOS
echo $SQL_IO_PER_EXEC|sed 's/ from .*//'|sed 's/select //'|tr ',' '\t\t'|tr '[a-z]' '[A-Z]' >>$MAILFILE
cat -s $TEMPFILE >>$MAILFILE


# Memory usage
> $TEMPFILE
echo "\n\n############################## ~ top 5 memory consuming requests ~ ##############################" >>$MAILFILE
echo "# Global statistics" >>$MAILFILE
sqlplus -s <<EOS
conn / as sysdba
$SQLPLUS_OPTS
spool $TEMPFILE;
$SQL_MEM
spool off;
quit;
EOS
echo $SQL_MEM|sed 's/ from .*//'|sed 's/select //'|tr ',' '\t\t'|tr '[a-z]' '[A-Z]' >>$MAILFILE
cat -s $TEMPFILE >>$MAILFILE

echo -e "\n# Per execution statistics" >>$MAILFILE
sqlplus -s <<EOS
conn / as sysdba
$SQLPLUS_OPTS
spool $TEMPFILE;
$SQL_MEM_PER_EXEC
spool off;
quit;
EOS
echo $SQL_MEM_PER_EXEC|sed 's/ from .*//'|sed 's/select //'|tr ',' '\t\t'|tr '[a-z]' '[A-Z]' >>$MAILFILE
cat -s $TEMPFILE >>$MAILFILE

if [ $DEBUG -eq 1 ]; then
    echo -e "\n\n\n### DEBUG ###" >>$MAILFILE
    cat >>$MAILFILE <<EOF

SQL_CPU=$SQL_CPU
SQL_CPU_PER_EXEC=$SQL_CPU_PER_EXEC

SQL_IO=$SQL_IO
SQL_IO_PER_EXEC=$SQL_IO_PER_EXEC

SQL_MEM=$SQL_MEM
SQL_MEM_PER_EXEC=$SQL_MEM_PER_EXEC

EOF
fi


# send mail
send_mail

# update the last exec time file
touch $lastexec_filename

exit 0

