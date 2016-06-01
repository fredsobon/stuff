#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# check_oracle_table.py: Oracle monitoring - Table check
#                        by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#

import fnmatch
import getopt
import netsnmp
import os
import re
import sys


SNMP_VERSION = 2

SNMP_DEF = {
    'TablespaceUsage': ((
        ('name', str),
        ('type', str),
        ('total', int),
        ('used', int),
        ('free', int),
        ('limit', int),
        ('percent', int),
    ), ('name', 'percent')),
    'DiskgroupUsage': ((
        ('name', str),
        ('used', int),
        ('total', int),
        ('percent', int),
    ), ('name', 'percent')),
    'MVLogRefreshAge': ((
        ('age', int),
        ('desc', str),
    ), ('desc', 'age')),
    'StatsSessionsWaits': ((
        ('count', int),
        ('name', str),
    ), ('name', 'count')),
    'FlashbackUsage': ((
        ('name', str),
        ('allocated', int),
        ('used', int),
        ('reclaimable', int),
        ('nofile', int),
        ('pct_reclaimable', int),
        ('pct_reclaimable_limit', int),
        ('pct_used', int),
    ), ('name', 'pct_used')),
    'AppliBtoolsFraudbuster': ((
        ('count', int),
        ('name', str),
        ('state', str),
    ), ('name', 'count')),
}


def fetch_data():
    try:
        result = {
            'unknown': [],
            'critical': [],
            'warning': [],
            'ok': [],
        }

        instances = snmp_walk(opt_host, opt_community, opt_base + 'InstanceName')

        if not instances:
            sys.stdout.write("Error: No instance\n")
            sys.exit(3)

        for instance_name in instances:
            if opt_exclusion and re.search(opt_exclusion, instance_name):
                continue

            # STATE
            state = snmp_walk(opt_host, opt_community, opt_base + opt_check + 'State.' +
                '.'.join([str(len(instance_name))] + [str(ord(x)) for x in instance_name]))

            if not state:
                result['unknown'].append('UNKNOWN: %s (No state)' % (instance_name))
                continue

            # DATA
            data = list(snmp_walk(opt_host, opt_community, opt_base + opt_check + 'Data.' +
                '.'.join([str(len(instance_name))] + [str(ord(x)) for x in instance_name])))

            if not data:
                # If there's no data, check state because this is the only way to have a result
                if int(state[0]) == 0:
                    result['ok'].append('OK: %s - %s' % (instance_name, state[1]))
                else:
                    result['unknown'].append('UNKNOWN: %s - %s (code: %s)' % (instance_name, state[1], state[0]))

            else:
                if int(state[0]) != 0:
                    result['unknown'].append('UNKNOWN: %s - %s (code: %s)' % (instance_name, state[1], state[0]))
                    continue

                keys = tuple(x[0] for x in SNMP_DEF[opt_check][0])
                types = tuple(x[1] for x in SNMP_DEF[opt_check][0])
    
                count = int(data.pop(0))
                chunks = []
    
                if count == 0:
                    result['ok'].append('OK: %s - %s' % (instance_name, state[1]))
                    continue
    
                for index, start in enumerate(xrange(0, len(data), count)):
                    chunks.append([types[index](x) for x in data[start:start+count]])
    
                for chunk in zip(*chunks):
                    entry = dict((x, y) for x, y in zip(keys, chunk))
    
                    if opt_critical:
                        for pattern, threshold in opt_critical:
                            if fnmatch.fnmatch(entry[SNMP_DEF[opt_check][1][0]], pattern):
                                if entry[SNMP_DEF[opt_check][1][1]] >= threshold:
                                    result['critical'].append('CRITICAL: (' + instance_name + ') ' + opt_format % entry)
    
                                break
    
                    if opt_warning:
                        for pattern, threshold in opt_warning:
                            if fnmatch.fnmatch(entry[SNMP_DEF[opt_check][1][0]], pattern):
                                if entry[SNMP_DEF[opt_check][1][1]] >= threshold:
                                    result['warning'].append('WARNING: (' + instance_name + ') ' + opt_format % entry)
    
                                break

                    result['ok'].append('OK: (' + instance_name + ') ' + opt_format % entry)

        return result
    except Exception, e:
        # Exit with UNKNOWN state
        sys.stdout.write('Error: %s\n' % str(e))
        sys.exit(3)


def parse_thresholds(input_list):
    default = None
    thresholds = []

    for entry in input_list:
        if ':' in entry:
            chunks = entry.rsplit(':', 1)
            thresholds.append((chunks[0], int(chunks[1])))
        else:
            default = int(entry)

    if default is not None:
        thresholds.append(('*', default))

    return thresholds


def print_usage(fd=sys.stdout):
    fd.write('''Usage: %(prog)s [OPTIONS]

Oracle monitoring table check.

Options:
   -B  base OID
   -c  critical threshold (pattern:threshold)
   -C  SNMP community
   -F  Display format
   -h  display this help and exit
   -H  host address
   -N  check name
   -w  warning threshold (pattern:threshold)
   -x  instance exclusion pattern
''' % {'prog': os.path.basename(sys.argv[0])})


def snmp_walk(host, community, oid):
    session = netsnmp.Session(DestHost=host, Version=SNMP_VERSION, Community=community, Timeout=1000000, Retries=3)
    return session.walk(netsnmp.VarList(netsnmp.Varbind(oid)))


if __name__ == '__main__':
    os.environ['MIBS'] = 'E-MERCHANT'

    # Parse for command-line arguments
    opt_base = None
    opt_check = None
    opt_community = None
    opt_critical = []
    opt_format = None
    opt_host = None
    opt_warning = []
    opt_exclusion = None

    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'B:c:C:F:hH:N:w:x:')

        for opt, arg in opts:
            if opt == '-B':
                opt_base = arg
            elif opt == '-h':
                print_usage()
                sys.exit(0)
            elif opt == '-c':
                opt_critical.append(arg)
            elif opt == '-C':
                opt_community = arg
            elif opt == '-F':
                opt_format = arg
            elif opt == '-H':
                opt_host = arg
            elif opt == '-N':
                opt_check = arg
            elif opt == '-w':
                opt_warning.append(arg)
            elif opt == '-x':
                opt_exclusion = arg
    except Exception, e:
        sys.stderr.write('Error: %s\n' % e)
        print_usage(fd=sys.stderr)
        sys.exit(1)

    if not opt_host or not opt_community:
        sys.stderr.write('Error: host and community parameters are mandatory\n')
        print_usage(fd=sys.stderr)
        sys.exit(1)
    elif not opt_base or not opt_check or not opt_format:
        sys.stderr.write('Error: base OID, check name and format parameters are mandatory\n')
        print_usage(fd=sys.stderr)
        sys.exit(1)

    # Parse thresholds
    opt_warning = parse_thresholds(opt_warning)
    opt_critical = parse_thresholds(opt_critical)

    # Parse output
    data = fetch_data()

    # Display status line
    sys.stdout.write('OK: %d, Unknown: %d, Warning: %d, Critical: %d\n' % (len(data['ok']), len(data['unknown']),
        len(data['warning']), len(data['critical']) ))

    # Display description
    if len(data['critical']) > 0 or len(data['warning']) > 0 or len(data['unknown']) > 0:
        output = data['unknown'] + data['critical'] + data['warning']
    else:
        output = data['ok']

    if len(output) > 0:
        sys.stdout.write('\n' + '\n'.join(output) + '\n')

    # Exit with alert level code
    if len(data['unknown']) > 0:
        sys.exit(3)
    elif len(data['critical']) > 0:
        sys.exit(2)
    elif len(data['warning']) > 0:
        sys.exit(1)
    elif len(data['ok']) == 0:
        sys.exit(3)
    else:
        sys.exit(0)
