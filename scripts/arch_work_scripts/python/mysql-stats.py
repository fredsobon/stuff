#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Wed, 14 Nov 2012 11:52:31 +0100

import getopt
import MySQLdb
import snmp_passpersist as snmp
import sys
import time
import traceback

db_host             = 'localhost'
db_user             = 'monitor'
db_passwd           = 'M0nit0R'
db_name             = ''
q_showstatus        = 'SHOW GLOBAL STATUS'
q_showslavestatus   = 'SHOW SLAVE STATUS'
polling_interval    = 10
oid_base            = '.1.3.6.1.4.1.38673.1.6'
oid_table = {
    # .1 : commands
    'Com_admin_commands':   ['1.1',    'cnt_32bit'],
    'Com_begin':            ['1.2',    'cnt_32bit'],
    'Com_commit':           ['1.3',    'cnt_32bit'],
    'Com_create_table':     ['1.4',    'cnt_32bit'],
    'Com_drop_table':       ['1.5',    'cnt_32bit'],
    'Com_delete':           ['1.6',    'cnt_32bit'],
    'Com_grant':            ['1.7',    'cnt_32bit'],
    'Com_flush':            ['1.8',    'cnt_32bit'],
    'Com_insert':           ['1.9',    'cnt_32bit'],
    'Com_rollback':         ['1.10',   'cnt_32bit'],
    'Com_select':           ['1.11',   'cnt_32bit'],
    'Com_set_option':       ['1.12',   'cnt_32bit'],
    'Com_update':           ['1.13',   'cnt_32bit'],
    'Com_drop_db':          ['1.14',   'cnt_32bit'],

    # .2 : handler
    'Handler_commit':           ['2.1',    'cnt_32bit'], # internal COMMIT statements
    'Handler_read_first':       ['2.2',    'cnt_32bit'], # number of times the first entry in an index was read
    'Handler_read_key':         ['2.3',    'cnt_32bit'], # requests reading a row based on a key
    'Handler_read_next':        ['2.4',    'cnt_32bit'], # requests reading the next row in key order
    'Handler_read_rnd':         ['2.5',    'cnt_32bit'], # requests reading a row based on a fixed position
    'Handler_read_rnd_next':    ['2.6',    'cnt_32bit'], # requests reading the next row in the data file
    'Handler_update':           ['2.7',    'cnt_32bit'], # requests updating a row in a table
    'Handler_write':            ['2.8',    'cnt_32bit'], # requests inserting a row in a table
    'Handler_rollback':         ['2.9',    'cnt_32bit'], # internal ROLLBACK statements

    # .3 : query cache
    'Qcache_not_cached':        ['3.1',    'int'], # Noncached queries
    'Qcache_inserts':           ['3.2',    'int'], # Queries added to the query cache
    'Qcache_hits':              ['3.3',    'int'], # Query cache hits
    'Qcache_lowmem_prunes':     ['3.4',    'int'], # Queries deleted from the query cache because of low memory
    'Qcache_queries_in_cache':  ['3.5',    'int'], # Queries registered in the query cache

    # .4 : threads
    'Threads_cached':       ['4.1',    'int'], # Threads in the thread cache
    'Threads_connected':    ['4.2',    'int'], # Currently open connections
    'Threads_created':      ['4.3',    'int'], # Threads created to handle connections
    'Threads_running':      ['4.4',    'int'], # Threads that are not sleeping

    # .5 : traffic
    'Bytes_received':   ['5.1',    'cnt_32bit'], # Bytes received from all clients
    'Bytes_sent':       ['5.2',    'cnt_32bit'], # Bytes sent to all clients

    # .6 : replication
    'Slave_lag':     ['6.1',    'int'], # Seconds behind master
    'Slave_running': ['6.2',    'int'], # Slave replication running
}


class MySQL:
    def __init__(self, host, user, password, database, is_master):
        self.stats = {}
        self.cache_ttl = 2.0
        self.time = time.time() - self.cache_ttl - 1.0
        self.host = host
        self.user = user
        self.password = password
        self.database = database
        self.conn = None
        self.is_master = is_master

        # Initialize connection
        self.make_connection()

    def make_connection(self):
        try:
            self.conn = MySQLdb.connect(host=self.host, user=self.user, passwd=self.password, db=self.database)
        except:
            self.conn = None
            return False
        return True

    def __del__(self):
        if self.conn:
            self.conn.close()

    def update_stats(self):
        now = time.time()
        if now - self.time < self.cache_ttl:
            return

        if not self.conn:
            if not self.make_connection():
                return

        metrics = oid_table.keys()
        cursor = self.conn.cursor()
        cursor.execute(q_showslavestatus)

        slave_lag = cursor.fetchone()

        if self.is_master:
            self.stats['Slave_lag'] = 0
        else:
            if not slave_lag or (slave_lag and len(slave_lag) < 31):
                self.stats['Slave_lag'] = 0
            else:
                self.stats['Slave_lag'] = int(slave_lag[32])

        cursor.execute(q_showstatus)
        for i in cursor.fetchall():
            if i[0] in metrics:
                if i[0] == 'Slave_running':
                    if i[1] == 'ON':
                        self.stats[i[0]] = 0
                    else:
                        self.stats[i[0]] = 1
                else:
                    self.stats[i[0]] = int(i[1])

        self.time = now
        return

    def get_stats(self):
        self.update_stats()
        return self.stats


def update_def():
    stats.update_stats()

    for key in oid_table:
        if not key in stats.stats:
            continue

        if hasattr(pp, 'add_' + oid_table[key][1]):
            getattr(pp, 'add_' + oid_table[key][1])(oid_table[key][0], stats.stats[key])
        else:
            pp.add_str(oid_table[key][0], stats.stats[key])

if __name__ == '__main__':
    is_master = False
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'm')
    except getopt.GetoptError, e:
        print('%s' % e)
        print('usage: %s [-m]' % sys.argv[0])
        print('options:\n\t-m\tIs MySQL master (do not check replication lag)')
        sys.exit(1)

    for opt, arg in opts:
        if opt == '-m':
            is_master = True

    try:
        stats = MySQL(db_host, db_user, db_passwd, db_name, is_master)

        pp = snmp.PassPersist(oid_base)

        try:
            pp.start(update_def, polling_interval)
        except KeyboardInterrupt:
            print >> sys.stderr, "Exiting on user request."
            sys.exit(0)
        except IOError:
            pass
    except SystemExit:
        pass
    except:
        from os.path import basename, splitext
        traceback.print_exc(file=open('/tmp/%s.error' % splitext(basename(sys.argv[0]))[0], 'w'))
        sys.exit(1)
