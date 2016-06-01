#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# check_oracle_counter.py: Oracle monitoring - Counter check
#                          by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#                          by Sébastien Liénard <s.lienard@pixmania-group.com>
#

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
            data = snmp_walk(opt_host, opt_community, opt_base + opt_check + 'Data.' +
                '.'.join([str(len(instance_name))] + [str(ord(x)) for x in instance_name]))

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

                # VALUE
                value = int(data[0])

                if opt_critical and value >= opt_critical:
                    result['critical'].append('CRITICAL: %s - ' % (instance_name) + '\n'.join(data))
                elif opt_warning and value >= opt_warning:
                    result['warning'].append('WARNING: %s - ' % (instance_name) + '\n'.join(data))
                else:
                    result['ok'].append('OK: %s - ' % (instance_name) + '\n'.join(data))

        return result
    except Exception, e:
        # Exit with UNKNOWN state
        sys.stdout.write('Error: %s\n' % str(e))
        sys.exit(3)


def print_usage(fd=sys.stdout):
    fd.write('''Usage: %(prog)s [OPTIONS]

Oracle monitoring.

Options:
   -B  base OID
   -c  critical threshold
   -C  SNMP community
   -h  display this help and exit
   -H  host address
   -N  check name
   -w  warning threshold
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
    opt_critical = None
    opt_host = None
    opt_warning = None
    opt_exclusion = None

    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'B:c:C:hH:N:w:x:')

        for opt, arg in opts:
            if opt == '-B':
                opt_base = arg
            elif opt == '-h':
                print_usage()
                sys.exit(0)
            elif opt == '-c':
                opt_critical = int(arg)
            elif opt == '-C':
                opt_community = arg
            elif opt == '-H':
                opt_host = arg
            elif opt == '-N':
                opt_check = arg
            elif opt == '-w':
                opt_warning = int(arg)
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
        sys.stderr.write('Error: base OID and check name parameters are mandatory\n')
        print_usage(fd=sys.stderr)
        sys.exit(1)

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
