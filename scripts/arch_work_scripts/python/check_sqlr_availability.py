#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# check_sqlr_unavail: SQLR availabtility check
#                         by Xavier Batoufflet <x.gastine@pixmania-group.com>
#

import getopt
import netsnmp
import os
import re
import sys


SNMP_VERSION = 2


def fetch_data(host, community):
    try:
        return zip(
            # E-MERCHANT::sqlrInstanceName
            snmp_walk(host, community, '.1.3.6.1.4.1.38673.1.2.0'),

            # E-MERCHANT::sqlrInstanceStatus
            [int(x) for x in snmp_walk(host, community, '.1.3.6.1.4.1.38673.1.2.1')],

        )
    except Exception, e:
        # Exit with UNKNOWN state
        sys.stdout.write('Error: %s\n' % str(e))
        sys.exit(3)


def print_usage(fd=sys.stdout):
    fd.write('''Usage: %(prog)s [OPTIONS]

SQLR instance unavail monitoring.

Options:
   -c  set critical threshold
   -C  set SNMP community
   -h  display this help and exit
   -H  set host address
   -w  set warning threshold
   -x  set critical exclusion pattern
''' % {'prog': os.path.basename(sys.argv[0])})


def snmp_walk(host, community, oid):
    session = netsnmp.Session(DestHost=host, Version=SNMP_VERSION, Community=community, Timeout=500000)
    return session.walk(netsnmp.VarList(netsnmp.Varbind(oid)))


if __name__ == '__main__':
    # Parse for command-line arguments
    opt_community = None
    opt_critical = None
    opt_exclude = None
    opt_host = None
    opt_warning = None

    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'c:C:hH:w:x:')

        for opt, arg in opts:
            if opt == '-h':
                print_usage()
                sys.exit(0)
            elif opt == '-c':
                opt_critical = int(arg)
            elif opt == '-C':
                opt_community = arg
            elif opt == '-H':
                opt_host = arg
            elif opt == '-w':
                opt_warning = int(arg)
            elif opt == '-x':
                opt_exclude = arg
    except Exception, e:
        sys.stderr.write('Error: %s\n' % e)
        print_usage(fd=sys.stderr)
        sys.exit(1)

    if not opt_host or not opt_community:
        sys.stderr.write('Error: host and community parameters are mandatory\n')
        print_usage(fd=sys.stderr)
        sys.exit(1)

    # Parse output
    stack_critical = []
    stack_warning = []

    if opt_exclude:
        pattern = re.compile(opt_exclude, re.I)

    for name, unavail in fetch_data(opt_host, opt_community):
        if opt_critical is not None and unavail > opt_critical and (not opt_exclude or opt_exclude and not pattern.search(name)):
            stack_critical.append('CRITICAL: %s %d%% available' % (name, 100 - unavail))
        elif opt_warning is not None and unavail > opt_warning and (not opt_exclude or opt_exclude and not pattern.search(name)):
            stack_warning.append('WARNING: %s %d%% available' % (name, 100 - unavail))

    sys.stdout.write('Critical: %d, Warning: %d\n\n' % (len(stack_critical), len(stack_warning)))
    sys.stdout.write('\n'.join(stack_critical + stack_warning))
    sys.stdout.write('\n')

    if len(stack_critical) > 0:
        sys.exit(2)
    elif len(stack_warning) > 0:
        sys.exit(1)
    else:
        sys.exit(0)
