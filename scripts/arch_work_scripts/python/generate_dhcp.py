#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

try:
    import MySQLdb
except:
    sys.stderr.write('Package python-mysqldb is not present, you must install it.\n')
    sys.exit(1)


def subnet_natsort(a, b):
    chunks_a = [int(x) for x in a.split('.')]
    chunks_b = [int(x) for x in b.split('.')]

    return cmp(chunks_a[0], chunks_b[0]) + cmp(chunks_a[1], chunks_b[1]) + cmp(chunks_a[2], chunks_b[2])

if '__main__' == __name__:
    DB_HOST = 'inventory.e-merchant.net'
    DB_USER = 'systools'
    DB_PASSWD = 'syst00ls'
    DB_NAME = 'systools'
    DB_TABLE = 'V_hosts_macaddresses_base'

    DHCP_FOLDER_TMPL = '%s'
    DHCP_FILE_TMPL = 'dhcpd.%s.conf'

    try:
        conn = MySQLdb.connect(host=DB_HOST, user=DB_USER, passwd=DB_PASSWD, db=DB_NAME)
    except:
        sys.stderr.write('Failed to connect to MySQL database.\n')
        sys.exit(1)

    output_dict = dict()
    subnet_used = dict()

    cursor = conn.cursor()

    cursor.execute('SELECT * FROM ' + DB_TABLE + ' WHERE hostname LIKE "%.e-merchant.net"   ORDER BY ip ASC, position ASC, iface ASC')

    field_names = [i[0] for i in cursor.description]

    for values in cursor.fetchall():
        data = dict(zip(field_names, values))
        if 'ipmi' == data['iface']:
            data['hostname'] = 'ipmi.' + data['hostname']
	try:
	    (site, row) = data['position'].lower().split()[:2]
	except:
	    site = data['hostname'].split('.')[-3]
	    row = "VMs" 
        subnet = data['ip'].rsplit('.', 1)[0]

        filename = DHCP_FILE_TMPL % (row.replace('-', ''))

        if not site in output_dict:
            output_dict[site] = dict()

        if not filename in output_dict[site]:
            output_dict[site][filename] = ''

        if not site in subnet_used:
            subnet_used[site] = list()

        if not subnet in subnet_used[site]:
            subnet_used[site].append(subnet)

        if 'ipmi' == data['iface']:
            output_dict[site][filename] += '''host %(hostname)s {
    hardware ethernet %(mac)s;
    fixed-address %(ip)s;
}

''' % (data)

        else:
            output_dict[site][filename] += '''# %(position)s %(serial)s %(model)s
host %(hostname)s {
    hardware ethernet %(mac)s;
    fixed-address %(ip)s;
}

''' % (data)

    for site in subnet_used:
        for subnet in sorted(subnet_used[site], subnet_natsort):
            (begin, end) = subnet.rsplit('.', 1)

            if '252' == end:
                continue

            if not DHCP_FILE_TMPL % 'subnet' in output_dict[site]:
                output_dict[site][DHCP_FILE_TMPL % 'subnet'] = ''

            if end == '240':

                output_dict[site][DHCP_FILE_TMPL % 'subnet'] += '''subnet %(begin)s.240.0 netmask 255.255.252.0 {
    option routers %(begin)s.243.254;
}

''' % ({'begin': begin})

            elif end in ['241', '242', '243']:
                pass
            else:
                output_dict[site][DHCP_FILE_TMPL % 'subnet'] += '''subnet %(subnet)s.0 netmask 255.255.255.0 {
    option routers %(subnet)s.254;
}

''' % ({'subnet': subnet})

    for site in output_dict:
        for filename in output_dict[site]:
            full_filename = os.path.join(
                os.path.dirname(os.path.realpath(__file__)),
                DHCP_FOLDER_TMPL % site,
                filename
            )
            if not os.path.exists(os.path.dirname(full_filename)):
                os.makedirs(os.path.dirname(full_filename))

            with open(full_filename, 'w') as fhandle:
                print 'Generating [%s] %s...' % (site, filename)
                fhandle.write(output_dict[site][filename])
