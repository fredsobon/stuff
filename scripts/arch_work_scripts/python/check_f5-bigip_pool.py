#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# check_f5-bigip_pool.py: F5 Networks BIG-IP pool monitoring
#                         by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#
# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/nagios/files/default/scripts/check_f5-bigip_pool.py $
#

import getopt
import netsnmp
import os
import re
import sys


SNMP_VERSION = 2


def print_usage(fd=sys.stdout):
    fd.write('''Usage: %(prog)s [OPTIONS]

F5 Networks BIG-IP pool monitoring.

Options:
   -c  set critical threshold
   -C  set SNMP community
   -h  display this help and exit
   -H  set host address
   -w  set warning threshold
   -x  set critical exclusion pattern
   -o  set custom critical from regex
''' % {'prog': os.path.basename(sys.argv[0])})


def snmp_walk(host, community, oid):
    session = netsnmp.Session(DestHost=host, Version=SNMP_VERSION, Community=community, Timeout=50000)
    return session.walk(netsnmp.VarList(netsnmp.Varbind(oid)))

# DEBUG
def snmp_get(host, community, oid):
    session = netsnmp.Session(DestHost=host, Version=SNMP_VERSION, Community=community, Timeout=50000)
    return session.get(netsnmp.VarList(netsnmp.Varbind(oid)))[0]


if __name__ == '__main__':
    # Parse for command-line arguments
    opt_community = None
    opt_critical = None
    opt_exclude = None
    opt_host = None
    opt_warning = None
    opt_custom = None

    data = list()

    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'c:C:hH:w:x:o:')

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
            elif opt == '-o':
                opt_custom = arg
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

    custom_checks = list()
    if opt_custom:
        for scheme in opt_custom.split(';'):
            cust_chunks = scheme.split(',')

            regexp = re.compile(cust_chunks[0], re.I)

            if len(cust_chunks) < 2 or not cust_chunks[1]:
                cust_chunks[1] = opt_critical

            custom_checks.append([regexp, int(cust_chunks[1])])


    # Get all Virtual Servers (F5-BIGIP-LOCAL-MIB::ltmVirtualServName)
    for vs in snmp_walk(opt_host, opt_community, '.1.3.6.1.4.1.3375.2.2.10.1.2.1.1') :
        # Convert VS name into hexa in order to build OID
        vs_hexname = '%s.%s' % (len(vs), '.'.join([ str(ord(c)) for c in vs ]))

        # VS enabled state (F5-BIGIP-LOCAL-MIB::ltmVsStatusEnabledState)
        oid_vs_enabled_state = '.1.3.6.1.4.1.3375.2.2.10.13.2.1.3.%s' % vs_hexname

        # Exit loop if VS is disabled
        if '1' != snmp_get(opt_host, opt_community, oid_vs_enabled_state) :
            continue
        
        # VS's default pool (F5-BIGIP-LOCAL-MIB::ltmVirtualServDefaultPool)
        oid_pool = '.1.3.6.1.4.1.3375.2.2.10.1.2.1.19.%s' % vs_hexname
        pool = snmp_get(opt_host, opt_community, oid_pool)

        # Exit loop if VS has no reals
        if not pool :
            continue

        # Convert pool name into hexa in order to build OID
        pool_hexname = '%s.%s' % (len(pool), '.'.join([ str(ord(c)) for c in pool ]))

        # Active reals count (F5-BIGIP-LOCAL-MIB::ltmPoolActiveMemberCnt)
        oid_active = '.1.3.6.1.4.1.3375.2.2.5.1.2.1.8.%s' % pool_hexname
        active = int(snmp_get(opt_host, opt_community, oid_active))

        # Total reals count (F5-BIGIP-LOCAL-MIB::ltmPoolMemberCnt)
        oid_total = '.1.3.6.1.4.1.3375.2.2.5.1.2.1.23.%s' % pool_hexname
        total = int(snmp_get(opt_host, opt_community, oid_total))

        data.append((pool, active, total))
    
    for name, active, total in data :
        new_entry = True
        if active == total:
            continue

        percent = (active * 100 / total) if total >= active else 0

        if custom_checks:
            for custom in custom_checks:
                if custom[0].search(name):
                    new_entry = False
                    if percent < custom[1] and (not opt_exclude or opt_exclude and not pattern.search(name)):
                        stack_critical.append('CRITICAL: %s %d/%d node%s online' % (name, active, total, 's' if active > 1 else ''))
                        break

        if new_entry and opt_critical and percent < opt_critical and (not opt_exclude or opt_exclude and not pattern.search(name)):
            stack_critical.append('CRITICAL: %s %d/%d node%s online' % (name, active, total, 's' if active > 1 else ''))
        else:
            stack_warning.append('WARNING: %s %d/%d node%s online' % (name, active, total, 's' if active > 1 else ''))

    sys.stdout.write('Critical: %d, Warning: %d\n\n' % (len(stack_critical), len(stack_warning)))
    sys.stdout.write('\n'.join(stack_critical + stack_warning))
    sys.stdout.write('\n')

    if len(stack_critical) > 0:
        sys.exit(2)
    elif len(stack_warning) > 0:
        sys.exit(1)
    else:
        sys.exit(0)
