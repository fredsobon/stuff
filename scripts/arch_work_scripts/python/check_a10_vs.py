#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# check_ax-bigip_pool.py: A10 Networks virtual servers monitoring
#                         by Sébastien LIENARD <s.lienard@pixmania-group.com>
#
# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/nagios/files/default/scripts/check_a10_pool.py $
#

import getopt
import netsnmp
import os
import re
import sys


SNMP_VERSION = 2

AX_VS_PORT_TYPES = ['0', 'Firewall', 'TCP', 'UDP' , '4', 'Others', '6', '7', 'RTSP', 'FTP', 'MMS', 'SIP', 'FastHTTP', '13', 'HTTP', 'HTTPS', 'SSLProxy', 'SMTP', 'SIP-TCP', 'SIPS', 'TCPProxy', 'Diameter', 'DNS-UDP', 'TFTP', 'DNS-TCP', 'MySQL', 'MSSQL', 'FIX', 'SMPP-TCP', 'SPDY', 'SPDYS', 'RADIUS']


### FUNCTION ###
def print_usage(fd=sys.stdout):
    fd.write('''Usage: %(prog)s [OPTIONS]

A10 Networks Virtual Servers monitoring.

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

def vsp_format(state, name, port, type, service_group, nodes_total, nodes_active, nodes):
    lines = []
    lines.append('%s: %s:%s/%s %d/%d node%s online' % (state, name, port, type, nodes_active, nodes_total, 's' if nodes_active > 1 else ''))
    lines.append('          \\_ %s' % service_group)
    for node in nodes:
        lines.append('             \\_ %s' % node)
    return lines


### MAIN ###
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
    count_critical = 0
    count_warning = 0
    count_ok = 0
    count_disabled = 0

    # Prepare exclusion pattern
    if opt_exclude:
        pattern = re.compile(opt_exclude, re.I)

    # Prepare custom checks
    custom_checks = list()
    if opt_custom:
        for scheme in opt_custom.split(';'):
            cust_chunks = scheme.split(',')

            regexp = re.compile(cust_chunks[0], re.I)

            if len(cust_chunks) < 2 or not cust_chunks[1]:
                cust_chunks[1] = opt_critical

            custom_checks.append([regexp, int(cust_chunks[1])])

    # Get Virtual Server Port infos
    # A10-AX-MIB::axVirtualServerPort is an SNMP table
    # For each attribute, we get the values list
    # Each Virtual Server Port should have its attributes as the same index in each list
    # This allow us to walk all the list at the same time to walk VSP
    # A10-AX-MIB::axVirtualServerPortName
    # A10-AX-MIB::axVirtualServerPortType
    # A10-AX-MIB::axVirtualServerPortNum
    vsp_names = snmp_walk(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.4.3.1.1.1')
    vsp_types = snmp_walk(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.4.3.1.1.2')
    vsp_ports = snmp_walk(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.4.3.1.1.3')

    # Loop on each Virtual Server Port (name, type and port)
    for vsp_name, vsp_type, vsp_port in zip(vsp_names, vsp_types, vsp_ports):

        # Build VSP index OID
        vsp_index = '%s.%s.%s.%s' % (len(vsp_name), '.'.join([ str(ord(c)) for c in vsp_name ]), vsp_type, vsp_port)

        # VSP enabled state (A10-AX-MIB::axVirtualServerPortEnabled)
        vsp_enabled_state = snmp_get(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.4.3.1.1.5.%s' % vsp_index)

        # Skip if VS is disabled
        if vsp_enabled_state == '0':
            count_disabled += 1
            continue
        
        # VSP display status (A10-AX-MIB::axVirtualServerPortDisplayStatus)
        vsp_display_status = snmp_get(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.4.3.1.1.23.%s' % vsp_index)

        # Skip if VS is Disabled(0) or allUp(1)
        if vsp_display_status == '0':
            count_disabled += 1
            continue
        elif vsp_display_status == '1':
            count_ok += 1
            continue

        # VSP Service Group (Pool) (A10-AX-MIB::axVirtualServerPortServiceGroup)
        vsp_service_group = snmp_get(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.4.3.1.1.6.%s' % vsp_index)

        # Extract partition name from Virtual Server Port name ("Partion:VS")
        vsp_part = vsp_name.split(":", 1)[0]

        # Build the Service Group name ("Partition:SG") and convert it to hex
        vsp_sg = '%s:%s' % (vsp_part, vsp_service_group)
        vsp_sg_hex = '%s.%s' % (len(vsp_sg), '.'.join([ str(ord(c)) for c in vsp_sg ]))

        # Get services group's nodes infos
        # A10-AX-MIB::axServerNameInServiceGroupMember
        # A10-AX-MIB::axServerPortNumInServiceGroupMember
        # A10-AX-MIB::axServerPortStatusInServiceGroupMember
        sg_nodes_names = snmp_walk(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.3.3.1.1.3.%s' % vsp_sg_hex)
        sg_nodes_ports = snmp_walk(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.3.3.1.1.4.%s' % vsp_sg_hex)
        sg_nodes_status = snmp_walk(opt_host, opt_community, '.1.3.6.1.4.1.22610.2.4.3.3.3.1.1.6.%s' % vsp_sg_hex)
        
        # Gather service group
        vsp_nodes = []
        vsp_nodes_total = 0
        vsp_nodes_active = 0

        # Loop on each Service Group's node (name, port, status)
        for node_name, node_port, node_status in zip(sg_nodes_names, sg_nodes_ports, sg_nodes_status):

            if node_status != '0':
                # Node is not disabled(0), add it to total
                vsp_nodes_total += 1

                if node_status == '1':
                    # Node is Up(1)
                    vsp_nodes_active += 1
                elif node_status == '2':
                    # Node is Down(2)
                    vsp_nodes.append('%s:%s' % (node_name, node_port))

        ### Check data ###
        # Skip if pool has no enabled nodes
        if vsp_nodes_total == 0:
            count_ok += 1
            continue

        # Skip if pool has all its members "up"
        if vsp_nodes_total == vsp_nodes_active:
            count_ok += 1
            continue
    
        # Set Virtual Server Port Type text 
        # A10-AX-MIB::axVirtualServerPortType is an integer presented as a string
        # First we convert it to integer
        # And then we try to get the corresponding text from AX_VS_PORT_TYPES[]
        # Maybe we should replace this by SNMP translate
        vsp_type_int = int(vsp_type)
        if vsp_type_int >= len(AX_VS_PORT_TYPES):
            # Value is out of range, set the value as text, this will display the number
            vsp_type_txt = str(vsp_type_int)
        else:
            vsp_type_txt = AX_VS_PORT_TYPES[vsp_type_int]

        # Compute percent
        percent = (vsp_nodes_active * 100 / vsp_nodes_total) if vsp_nodes_total >= vsp_nodes_active else 0

        # Custom checks (-o)
        if custom_checks:
            found = False
            for custom in custom_checks:
                if custom[0].search(vsp_name):
                    if percent < custom[1] and (not opt_exclude or opt_exclude and not pattern.search(vsp_service_group)):
                        count_critical += 1
                        stack_critical.extend(vsp_format('CRITICAL', vsp_name, vsp_port, vsp_type_txt, vsp_service_group, vsp_nodes_total, vsp_nodes_active, vsp_nodes))
                    else:
                        count_ok += 1
                    found = True
                    break
            if found:
                continue

        # Standard checks (-w/-c)
        if opt_critical and percent < opt_critical and (not opt_exclude or opt_exclude and not pattern.search(vsp_service_group)):
            count_critical += 1
            stack_critical.extend(vsp_format('CRITICAL', vsp_name, vsp_port, vsp_type_txt, vsp_service_group, vsp_nodes_total, vsp_nodes_active, vsp_nodes))
        else:
            count_warning += 1
            stack_warning.extend(vsp_format('WARNING', vsp_name, vsp_port, vsp_type_txt, vsp_service_group, vsp_nodes_total, vsp_nodes_active, vsp_nodes))

    ### Resume ###
    sys.stdout.write('Critical: %d, Warning: %d, OK: %d, Disabled: %d\n\n' % (count_critical, count_warning, count_ok, count_disabled))
    sys.stdout.write('\n'.join(stack_critical + stack_warning))
    sys.stdout.write('\n')

    if count_critical > 0:
        sys.exit(2)
    elif count_warning > 0:
        sys.exit(1)
    else:
        sys.exit(0)
