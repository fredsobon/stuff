#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-
# vim: ft=python sw=4 et ts=4

# Monitoring script to check custom applicative status using Mysql Database

# Author: David Larquey
# Last modified: Wed Jul 29 17:35:29 CEST 2015


import os, sys, re
import argparse
import MySQLdb

STATE_UNKNOWN = 3
STATE_CRIT = 2
STATE_WARN = 1
STATE_OK = 0

DEBUG = False


def isset(var):
    try:
        eval(var)
    except NameError:
        return False
    else: return True

def error(str, *ecode):
    if ecode: ecode = ecode[0]
    print >> sys.stderr, "Error: %s" % str
    sys.exit(ecode)



####################################################
# + ------------------- Class ------------------- +#
####################################################


class MonitoringCheck:

    def __init__(self, check_name):
        self.check_name = check_name
        self.ecode = 0 # exit code
        self.msg_crit = []
        self.msg_unk = []
        self.msg_warn = []
        self.msg_ok = []

    def set_ecode(self, ecode):
        self.ecode = ecode

    def error(self, str, *ecode):
        if ecode: self.ecode = ecode[0]
        print >> sys.stderr,"Error: %s" % str
        sys.exit(self.ecode)

    def debug(self, msg):
        if DEBUG == True:
            print "DEBUG: %s" % msg

    def output(self):
        print "--- %s" % self.check_name.title()
        for msg in (self.msg_unk, self.msg_crit, self.msg_warn, self.msg_ok):
            if len(msg) > 0:
                print "\n".join(msg)

    def exit(self):
        nr_unk = len(self.msg_unk)
        nr_crit = len(self.msg_crit)
        nr_warn = len(self.msg_warn)
        nr_ok = len(self.msg_ok)

        if nr_crit > 0:
            self.ecode = STATE_CRIT
        elif nr_warn > 0:
            self.ecode = STATE_WARN
        elif nr_unk > 0:
            self.ecode = STATE_UNKNOWN
        else: self.ecode = STATE_OK

        sys.exit(self.ecode)


# The Mysql Class inherits from the class MonitoringCheck
class Mysql(MonitoringCheck):
    def __init__(self, host, user, password, database):
        self.host = host
        self.user = user
        self.password = password
        self.database = database
        self.connect()

    def connect(self):
        try:
            self.conn = MySQLdb.connect(host=self.host, user=self.user, passwd=self.password, db=self.database)
        except:
            self.conn = None
            self.error("Can't connect to the database: %s@%s" % (self.database, self.host), STATE_UNKNOWN)
            return False
        return self.conn

    def __del__(self):
        if self.conn:
            self.conn.close()

    def exec_sql(self, sql):
        if self.conn.open:
            self.debug("Executing sql: %s" % sql)
            try:
                self.mycurs = self.conn.cursor()
                self.mycurs.execute(sql)
                result = self.mycurs.fetchall()
                if result.__class__.__name__ != 'tuple':
                    self.error("Invalid result while executing sql: '%s'" % sql, STATE_UNKNOWN)
                return result
            except:
                self.error("Can't execute sql: '%s'" % sql, STATE_UNKNOWN)
                return False
        else:
            self.error("Can't open a connection to Mysql server: %s" % self.host, STATE_UNKNOWN)
            return False;

    def sql_rowcount(self):
        if self.conn.open:
            return self.mycurs.rowcount
        else:
            return 0



#####################################################
# + ------------------- Checks ------------------- +#
#####################################################

"""
- TaskManager Queue - TASK_QUEUE
check_TaskManager_1: Number of tasks in the queue
"""
def check_TaskManager_1(host, database):
    db_host = host
    db_name = database

    check = MonitoringCheck('check_TaskManager_1_' + db_name)
    conn = Mysql(db_host, DB_USER, DB_PASSWD, db_name)

    result = conn.exec_sql('SHOW TABLES')
    regex = re.compile('(^gearman_cron[0-9]+_[a-z0-9]+$)', re.IGNORECASE)
    queue_tables = [m.group(1) for m in [regex.match(row[0]) for row in result if row[0]] if m]
    if len(queue_tables) == 0:
        check.msg_unk.append("Can't find queue tables in database: %s" % db_name)
    else:
        for table in queue_tables:
            sql1 = "SELECT count(*) from %s" % table
            result = conn.exec_sql(sql1)
            value = result[0][0]
            if th_critical is not None and value >= th_critical:
                check.msg_crit.append("CRITICAL: Queue '%s' has %i entries" % (table,value))
            elif th_warning is not None and value >= th_warning:
                check.msg_warn.append("WARNING: Queue '%s' has %i entries" % (table,value))
            else:
                check.msg_ok.append("OK: Queue '%s' has %i entries" % (table,value))

    check.output()
    check.exit()



"""
- TaskManager - TASK_RUN
check_TaskManager_2: Number of tasks STARTED or STOPPED during last hour
Status:
0 : Pending
1 : Started
2 : Ended
"""
def check_TaskManager_2(host, database):
    db_host = host
    db_name = database
    time_period = 1 # in hours

    check = MonitoringCheck('check_TaskManager_2_' + db_name)
    conn = Mysql(db_host, DB_USER, DB_PASSWD, db_name)

    sql1="""
SELECT tel.status,
       CASE tel.status
          WHEN 1 THEN 'STARTED'
          WHEN 2 THEN 'CLOSED'
          ELSE 'UNKNOWN'
       END
          status_msg,
       COUNT(*)
  FROM taskmanager.task_exec_log tel
 WHERE tel.status IN (1, 2) AND tel.date >= NOW() - INTERVAL """ + str(time_period) + """ HOUR
group by tel.status;
"""
    result = conn.exec_sql(sql1)
    for (v_status, v_status_msg, v_count) in result:
        if (th_critical is not None and v_count >= th_critical) or (th_low_critical is not None and v_count <= th_low_critical):
            check.msg_crit.append("CRITICAL: %s tasks during last %i hours: %i" % (v_status_msg, time_period, v_count))
        elif (th_warning is not None and v_count >= th_warning) or (th_low_warning is not None and v_count <= th_low_warning):
            check.msg_warn.append("WARNING: %s tasks during last %i hours: %i" % (v_status_msg, time_period, v_count))
        else:
            check.msg_ok.append("OK: %s tasks during last %i hours: %i" % (v_status_msg, time_period, v_count))

    check.output()
    check.exit()


"""
- TaskManager - TASK_DUP
check_TaskManager_3: Number of duplicated tasks who were started during last day
Status:
0 : Pending
1 : Started
2 : Ended
"""
def check_TaskManager_3(host, database):
    db_host = host
    db_name = database
    time_period = 12 # in hours

    check = MonitoringCheck('check_TaskManager_3_' + db_name)
    conn = Mysql(db_host, DB_USER, DB_PASSWD, db_name)

    sql1="""
SELECT tel.cron_id, tel.job_scheduler_id, app.application_name, COUNT(*)
    , DATE_FORMAT(MIN(tel.date), '%d/%m/%y %H:%m:%S')
    , DATE_FORMAT(MAX(tel.date), '%d/%m/%y %H:%m:%S')
  FROM taskmanager.task_exec_log tel
    LEFT JOIN taskmanager.crontab c on c.cron_id=tel.cron_id
    LEFT JOIN taskmanager.application app on app.app_id=c.app_id
 WHERE tel.date >= NOW() - INTERVAL """ + str(time_period) + """ HOUR
AND tel.status = 0
GROUP BY tel.cron_id,tel.job_scheduler_id, app.application_name
HAVING COUNT(*) > 1
ORDER BY date desc
"""

    result = conn.exec_sql(sql1)
    for (v_cron_id, v_job_id, v_application, v_count, d_min, d_max) in result:
        if th_critical is not None and v_count >= th_critical:
            check.msg_crit.append("CRITICAL: CRON id <%s> (%s) was duplicated (%i last hours): %i (%s - %s)" % (v_cron_id, v_application, time_period, v_count, d_min, d_max))
        elif th_warning is not None and v_count >= th_warning:
            check.msg_warn.append("WARNING: CRON id <%s> (%s) was duplicated (%i last hours): %i (%s - %s)" % (v_cron_id, v_application, time_period, v_count, d_min, d_max))
    if len(check.msg_crit) == 0 and len(check.msg_warn) == 0: check.msg_ok.append("OK")

    check.output()
    check.exit()



###################################################
# + ------------------- MAIN ------------------- +#
###################################################

DB_USER="monitor"
DB_PASSWD="ooVah7iu"

if __name__ == '__main__':
    th_low_warning = None
    th_low_critical = None
    th_warning = None
    th_critical = None

    parser = argparse.ArgumentParser()
    parser.add_argument('-H','--host', nargs=1, required=True, help='mysql server to query')
    parser.add_argument('-n','--check-name', nargs=1, required=True, help='index of the check to do')
    parser.add_argument('-w', '--warning', type=int, help='warning threshold')
    parser.add_argument('-lw', '--low-warning', type=int, help='warning threshold')
    parser.add_argument('-c', '--critical', type=int, help='critical threshold')
    parser.add_argument('-lc', '--low-critical', type=int, help='critical threshold')
    args = parser.parse_args()

    th_low_warning = args.low_warning
    th_low_critical = args.low_critical
    th_warning = args.warning
    th_critical = args.critical

    check_name = args.check_name[0].upper()
    if      check_name == 'TASK_QUEUE': check_TaskManager_1(args.host[0], 'taskmanager_queue')
    elif    check_name == 'TASK_RUN': check_TaskManager_2(args.host[0], 'taskmanager')
    elif    check_name == 'TASK_DUP': check_TaskManager_3(args.host[0], 'taskmanager')
    else:
        error('Invalid check name: %s' % check_name, STATE_UNKNOWN)

