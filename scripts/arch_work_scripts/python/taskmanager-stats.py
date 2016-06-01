#!/usr/bin/python -u
# -*- coding: utf-8 -*- 
'''
Created on 26 déc. 2013

@author: jmmasson <jmmasson@e-merchant.com>
'''

import snmp_passpersist as snmp
import sys
import time
import traceback
from taskmanager import status


configfile = '/etc/taskmanager/taskmanager.conf'

polling_interval = 10

oid_base = '.1.3.6.1.4.1.38673.1.28'

oid_table = {
    'workers_running': ['1.1', 'gau'],
    'workers_max': ['1.2', 'gau'],
    'tasks_total': ['2.1', 'cnt_32bit'],
    'tasks_errors': ['2.2', 'cnt_32bit']
}

status_table = {'workers': 'workers_running',
                'max': 'workers_max',
                'tasks': 'tasks_total',
                'errors': 'tasks_errors'}


class Taskmanager():

    def __init__(self):
        self.stats = {}
        self.cache_ttl = 2.0
        self.time = time.time() - self.cache_ttl - 1.0

    def update_stats(self):
        now = time.time()
        if now - self.time > self.cache_ttl:
            data = status.get_workers(configfile)
            self.stats = {}
            for item in data:
                for key in item:
                    if key in status_table:
                        oid_name = status_table[key]
                        if oid_name in self.stats:
                            self.stats[oid_name] += item[key]
                        else:
                            self.stats[oid_name] = item[key]
        self.time = now


def update_def():
    stats.update_stats()
    for key in oid_table:
        if not key in stats.stats:
            continue

        name = 'add_' + oid_table[key][1]
        if hasattr(pp, name):
            getattr(pp, name)(oid_table[key][0], stats.stats[key])
        else:
            pp.add_str(name, stats.stats[key])


if __name__ == '__main__':
    try:
        stats = Taskmanager()

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

