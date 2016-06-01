#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import argparse
import netsnmp

STATE_OK = 0
STATE_WARN = 1
STATE_CRIT = 2
STATE_UNKN = 3

class SNMPSession:
    def __init__(self, host, version=2, community='pixro'):
        self._snmp = netsnmp.Session(Version=version, Community=community, DestHost=host, Timeout=50000)

    def __del__(self):
        if hasattr(self, '_snmp'):
            del self._snmp

    def get(self, oid_list):
        var_list = netsnmp.VarList()

        for oid in oid_list:
            var_list.append(netsnmp.Varbind(oid))

        return self._snmp.get(var_list)

    def walk(self, oid_list):
        var_list = netsnmp.VarList()

        for oid in oid_list:
            var_list.append(netsnmp.Varbind(oid))

        return self._snmp.walk(var_list)

parser = argparse.ArgumentParser()
parser.add_argument('host', nargs=1, help='host to query')
parser.add_argument('-v', '--version', default=2, type=int, help='SNMP version (default: 2)')
parser.add_argument('-C', '--community', required=True, help='SNMP community')
parser.add_argument('-o', '--override', action='append', help='override thresholds for specific vhost')
parser.add_argument('-t', '--timespan', type=int, help='timespan (minutes) to focus on (5, 15 or 30)')
parser.add_argument('-w', '--warning', type=float, help='warning threshold (%%) (ex: 0.5)')
parser.add_argument('-c', '--critical', type=float, help='critical threshold (%%) (ex: 2)')
parser.add_argument('-x', '--exclude', action='append', help='vhost to exclude')
args = parser.parse_args()

# Check parameters
if not args.warning and not args.critical:
    print("error: you must provide at least warning (-w) or critical (-c) thresholds")
    sys.exit(3)

if args.timespan and args.timespan not in (5, 15, 30):
    print("error: --timespan parameter must be either 5, 15 or 30")
    sys.exit(3)

snmp = SNMPSession(args.host[0], args.version, args.community)
metric_multiplier = int(snmp.get(['.1.3.6.1.4.1.38673.1.12.1.3'])[0])

excludes = []
if args.exclude:
    for i in args.exclude:
        excludes.append(i)

# Check if there are overridden vhost thresholds
override = {}
if args.override:
    for i in args.override:
        overridden = i.split(':')
        if len(overridden) < 3:
            print('error: --override option format is <FQDN:warnning threshold:critical threshold>')
            sys.exit(STATE_UNKN)
        else:
            override[overridden[0]] = (overridden[1], overridden[2])

i = 1
vhosts = {}
for vhost in snmp.walk(['.1.3.6.1.4.1.38673.1.12.2']):
    vhosts[vhost] = i
    i += 1

exit_state = STATE_OK
exit_msg = []
for fqdn, idx in vhosts.iteritems():
    # Skip the excluded vhosts
    if fqdn in excludes:
        continue

    try:
        oids = '''
        .1.3.6.1.4.1.38673.1.12.10.%(vhost)d.5
        .1.3.6.1.4.1.38673.1.12.11.%(vhost)d.5
        .1.3.6.1.4.1.38673.1.12.12.%(vhost)d.5''' % {'vhost': idx}

        threshold_reached = False
        rate_5xx_5mn, rate_5xx_15mn, rate_5xx_30mn = snmp.get(oids.split())
        vhosts[fqdn] = (idx,
            (float(rate_5xx_5mn) / metric_multiplier) * 100,
            (float(rate_5xx_15mn) / metric_multiplier) * 100,
            (float(rate_5xx_30mn) / metric_multiplier) * 100)

        thr_warning = None
        thr_critical = None
    except Exception:
        print("UNKNOWN: inconsistent values for vhost %s" % fqdn)
        sys.exit(STATE_UNKN)
        continue

    # Use vhost-overridden threshold first, then global threshold
    if fqdn in override.keys():
        if override[fqdn][0]:
            thr_warning = override[fqdn][0]

        if override[fqdn][1]:
            thr_critical = override[fqdn][1]
    else:
        if args.warning:
                thr_warning = args.warning

        if args.critical:
                thr_critical = args.critical

    # Compare fetched values to thresholds
    if thr_warning:
        if (not args.timespan or args.timespan == 5) and vhosts[fqdn][1] > thr_warning:
            if exit_state < STATE_WARN:
                exit_state = STATE_WARN
            threshold_reached = True

        if (not args.timespan or args.timespan == 15) and vhosts[fqdn][2] > thr_warning:
            if exit_state < STATE_WARN:
                exit_state = STATE_WARN
            threshold_reached = True

        if (not args.timespan or args.timespan == 30) and vhosts[fqdn][3] > thr_warning:
            if exit_state < STATE_WARN:
                exit_state = STATE_WARN
            threshold_reached = True

    if thr_critical:
        if (not args.timespan or args.timespan == 5) and vhosts[fqdn][1] > thr_critical:
            exit_state = STATE_CRIT
            threshold_reached = True

        if (not args.timespan or args.timespan == 15) and vhosts[fqdn][2] > thr_critical:
            exit_state = STATE_CRIT
            threshold_reached = True

        if (not args.timespan or args.timespan == 30) and vhosts[fqdn][3] > thr_critical:
            exit_state = STATE_CRIT
            threshold_reached = True

    if threshold_reached:
        exit_msg.append('%s: 5xx response rate: %f%%, %f%%, %f%%'
            % (fqdn, vhosts[fqdn][1], vhosts[fqdn][2], vhosts[fqdn][3]))

if exit_state == STATE_OK:
    print('OK')
else:
    print('%s: %s' % ('WARNING' if exit_state == STATE_WARN else 'CRITICAL', ', '.join(exit_msg)))

sys.exit(exit_state)
