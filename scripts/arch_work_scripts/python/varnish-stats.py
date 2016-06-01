#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et

import re
import snmp_passpersist as snmp
import os.path
import subprocess
import sys
import time
import traceback
import getopt

CONFIG = {
    # Varnishstat command path (without arguments)
    'varnishstat_path':  '/usr/bin/varnishstat',

    # SNMP PassPersist pollin,g interval
    'polling_interval': 10,

    # Base OIDs
    'instances_count_oid': '1.0',
    'values_base_oid':     '2.1', 
    # These are under 'values_base_oid'
    'instance_index_oid':      '1',
    'instance_name_oid':       '2',

    # Configuration of metrics OIDs
    'oid_table': {

        # OIDs tree
        # .1.0 : instances count ^^^
        # .2.1.1 : instance index ^^^
        # .2.1.2 : instance name ^^^

        # The following are under 'values_base_oid'
        # .2.1.x : ...

        # Format:
        # metric_from_varnishstat: [ OID, Data_type ]
        # client connections

        'client_conn':      ['3',    'cnt_64bit'],    # Client connections accepted
        'client_req':       ['4',    'cnt_64bit'],    # Client requests received

        # backend connections
        'backend_conn':         ['5',    'cnt_64bit'], # Backend conn. success
        'backend_unhealthy':    ['6',    'cnt_64bit'], # Backend conn. not attempted
        'backend_busy':         ['7',    'cnt_64bit'], # Backend conn. too many
        'backend_fail':         ['8',    'cnt_64bit'], # Backend conn. failures
        'backend_reuse':        ['9',    'cnt_64bit'], # Backend conn. reuses
        'backend_recycle':      ['10',    'cnt_64bit'], # Backend conn. recycles

        # totals
        's_sess':   ['11',    'cnt_64bit'], # Total Sessions
        's_req':    ['12',    'cnt_64bit'], # Total Requests
        's_pass':   ['13',    'cnt_64bit'], # Total pass
        's_fetch':  ['14',    'cnt_64bit'], # Total fetch

        # worker threads
        'n_wrk':        ['15',    'int'], # Worker threads

        # objects
        'n_object':     ['16',    'int'], # Objects stored in cache

        # bytes
        's_hdrbytes':     ['17',    'cnt_64bit'], # Total header bytes
        's_bodybytes':    ['18',    'cnt_64bit'], # Total body bytes

        # cache
        'cache_hit':        ['19',    'cnt_64bit'],    # Cache hits
        'cache_hitpass':    ['20',    'cnt_64bit'],    # Cache hits-for-pass
        'cache_miss':       ['21',    'cnt_64bit'],    # Cache misses
        'cache_hitratio':   ['22',    'int'],          # Cache hit ratio
    }
}

class Varnish:
    def __init__(self, varnishstat, oid_table, instances):
        self.varnishstat = varnishstat
        self.oid_table = oid_table
        self.instances = instances

        self.stats = {}
        self.cache_ttl = 2.0
        self.time = time.time() - self.cache_ttl - 1.0
        self.cmd = self.varnishstat + " -1 -f " + ','.join(self.oid_table)

        # Initialize each instance dictionary
        for instance in self.instances:
            self.stats[instance] = {}

    def update_stats(self):
        now = time.time()
        if now - self.time < self.cache_ttl:
            return

        if not os.path.exists(self.varnishstat):
            return

        for instance in self.instances:
            cmd = self.cmd + " -n " + instance
            raw_stats = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
    
            # Parse buffer
            pairs = []
            for line in (raw_stats.communicate()[0].strip()).splitlines():
                r = re.search('^(\w*)\s+(\d+)', line)
                (stat_key, stat_value) = (r.group(1), r.group(2))
                pairs.append([stat_key, stat_value])
    
            metrics = self.oid_table.keys()
            for (key, value) in pairs:
                if key in metrics:
                    self.stats[instance][key] = int(value)
    
            # Calculate cache hit ratio
            if self.stats[instance]['cache_hit'] == 0 and self.stats[instance]['cache_miss'] == 0:
                # Avoid dividing by zero
                self.stats[instance]['cache_hitratio'] = 0
            else:
                self.stats[instance]['cache_hitratio'] = int(self.stats[instance]['cache_hit'] * 100 / (self.stats[instance]['cache_hit'] + self.stats[instance]['cache_miss']))
    
        self.time = now
        return

def update_def():
    varnish.update_stats()

    # Define instances count OID
    snmp_pp.add_int(CONFIG['instances_count_oid'], len(varnish.instances))

    for index, instance in enumerate(varnish.instances):

        # index should start at 1
        index = index + 1

        snmp_pp.add_int('.'.join([CONFIG['values_base_oid'], CONFIG['instance_index_oid'], str(index)]), index)
        snmp_pp.add_str('.'.join([CONFIG['values_base_oid'], CONFIG['instance_name_oid'], str(index)]), instance)

        for key in CONFIG['oid_table']:

            # Ignore missing stats
            if not key in varnish.stats[instance]:
                continue
    
            # Construct OID and data type from configuration (CONFIG['oid_table'])
            oid = '.'.join([CONFIG['values_base_oid'], CONFIG['oid_table'][key][0], str(index)])
            type = CONFIG['oid_table'][key][1]

            if hasattr(snmp_pp, 'add_' + type):
                # If configured data type exists in SNMP PassPersist module, try to use it...
                getattr(snmp_pp, 'add_' + type)(oid, varnish.stats[instance][key])
            else:
                # ... else, use "string" type
                snmp_pp.add_str(oid, varnish.stats[instance][key])

def print_usage(output=sys.stdout):
    output.write('''Usage: %(program)s -b BASE_OID -i COMMA_SEPARATED_LIST

Options:
  -b  specify base OID
  -i  specify Varnish instances (comma separated list)
  -h  display this help and exit
''' % {'program': os.path.basename(sys.argv[0])})

if __name__ == '__main__':
    opt_base = None
    opt_instances = []

    # Parse command-line arguments
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'b:i:')
    except getopt.GetoptError, e:
        sys.stderr.write('Error: %s\n' % e)
        print_usage(output=sys.stderr)
        sys.exit(1)

    # Get values from command-line arguments
    for opt, arg in opts:
        if opt == '-b':
            opt_base = arg
        elif opt == '-i':
            opt_instances = sorted(arg.split(','))
        elif opt == '-h':
            print_usage()
            sys.exit(0)

    # Check arguments
    if not opt_base:
        sys.stderr.write('Error: you must specify base OID\n')
        print_usage(output=sys.stderr)
        sys.exit(1)
    elif not opt_instances:
        sys.stderr.write('Error: you must specify Varnish instances\n')
        print_usage(output=sys.stderr)
        sys.exit(1)

    # Let's go
    try:
        varnish = Varnish(CONFIG['varnishstat_path'], CONFIG['oid_table'], opt_instances)

        snmp_pp = snmp.PassPersist(opt_base)

        try:
            snmp_pp.start(update_def, CONFIG['polling_interval'])
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
