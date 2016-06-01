#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# check_snmp_table.py: SNMP monitoring - Table check
#                        by Sébastien LIENARD <s.lienard@pixmania-group.com>
#
# TODO: Specify data type as argument (int, string, ...)

import fnmatch
import getopt
import netsnmp
import os
import re
import sys


SNMP_VERSION = 2

def fetch_data():
    try:
        result = {
            'unknown': [],
            'critical': [],
            'warning': [],
            'ok': [],
        }

        # Get instances
        instances = snmp_walk(opt_host, opt_community, opt_base + 'InstanceName')

        if not instances:
            sys.stdout.write("Error: No instance\n")
            sys.exit(3)

        # Get data
        data = snmp_walk(opt_host, opt_community, opt_base + opt_check)

        if not data:
            sys.stdout.write("Error: No data\n")
            sys.exit(3)

        for i, instance_name in enumerate(instances):
            if opt_exclusion and re.search(opt_exclusion, instance_name):
                continue

            matched = False
            if opt_critical:
                for pattern, threshold in opt_critical:
                     if fnmatch.fnmatch(instance_name, pattern):
                         if int(data[i]) >= threshold:
                             result['critical'].append('CRITICAL: ' + instance_name + ' = ' + data[i])
                             matched = True
                         break
                if matched:
                    continue
                
            if opt_warning:
                for pattern, threshold in opt_warning:
                     if fnmatch.fnmatch(instance_name, pattern):
                         if int(data[i]) >= threshold:
                             result['warning'].append('WARNING: ' + instance_name + ' = ' + data[i])
                             matched = True
                         break
                if matched:
                    continue

            result['ok'].append('OK: ' + instance_name + ' = ' + data[i])

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
    elif not opt_base or not opt_check:
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
