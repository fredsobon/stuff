#!/usr/bin/env python
# cat check_memcached_rates.py

# Launch with -h for help, or -v for verbose.

import socket, os, sys, getopt, subprocess, pickle, time

# overridable defaults
prefix  = '/tmp/__memcached_rates_'
group   = 'memcache'
metric  = 'evictions'
verbose = False
warn    = 10
error   = 100

def memcached_stats(server, metric, verbose, port = 11211):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((server, port))
        sock.send('stats\n')
        res = sock.recv(10240)
        return int([x.split(' ')[2] for x in res.split('\n') if 'STAT ' + metric in x][0])
    except Exception, err:
        if verbose: print server + ' : ' + str(err)
        return None

def load_cache(prefix, group, metric):
    if os.path.isfile(prefix + group + metric):
        return pickle.load(open(prefix + group + metric, 'rb'))
    return {}

def dump_cache(prefix, group, metric, stats):
    pickle.dump(stats, open(prefix + group + metric, 'wb'))

def collect(servers, metric, verbose, previous):
    stats = {}
    for i in servers:
        print i
        evs  = memcached_stats(i, metric, verbose)
        stats[i] = {
            'value': evs,
            'fail' : evs is None,
            'time' : time.time(),
            'rate' : 0
        }
        if i in previous and previous[i]['value']:
            stats[i]['rate'] = (stats[i]['value'] - previous[i]['value']) / \
                (stats[i]['time'] - previous[i]['time'])
    return stats

def servers(group):
    cmd = ['/server/list', 'list',  '-g', group]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    return proc.stdout.read().strip().split(' ')

def alert(stats, warn, error):
    servs = dict((x, stats[x]) for x in stats if not os.path.isfile('/server/list/exclude.' + x))
    failures = [x for x in servs if servs[x]['fail'] or (servs[x]['rate'] > error)] or ['none']
    warnings = [x for x in servs if servs[x]['rate'] > warn] or ['none']
    print 'SERVER_IN_WARNING='  + ' '.join(warnings)
    print 'SERVER_IN_ERROR='    + ' '.join(failures)
    if failures != ['none']: return 1
    if warnings != ['none']: return 2
    return 0

def usage():
    print sys.argv[0] + ' [-v] [-m metric] [-g distrib_group] [-w warning_rate] [-e error_rate]'
    print 'Alerts when a memcached stat metric, increase above the specified rate (per second).'
    print 'default metric: %s, default group: %s, default warning: %s, default error: %s' % \
          (metric, group, str(warn), str(error))
    sys.exit(2)

try:
    opts, args = getopt.getopt(sys.argv[1:], 'vhm:g:e:w:', ['help'])
except getopt.GetoptError:
    usage()

for opt, arg in opts:
    if opt in ('-h', '--help'): usage()
    elif opt == '-m': metric  = arg
    elif opt == '-g': group   = arg
    elif opt == '-e': error   = float(arg)
    elif opt == '-w': warn    = float(arg)
    elif opt == '-v': verbose = True

stats = collect(servers(group), metric, verbose, load_cache(prefix, group, metric))
dump_cache(prefix, group, metric, stats)

if verbose:
   from pprint import pprint
   pprint(stats)

sys.exit(alert(stats, warn, error))

