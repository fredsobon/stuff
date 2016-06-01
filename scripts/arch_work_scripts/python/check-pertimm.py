#!/usr/bin/python -u
# -*- coding: utf-8 -*-
#
# check-pertimm.py: Pertimm check data exporter
#                   by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#

import codecs
import getopt
import json
import os
import snmp_passpersist as snmp
import sys
import urllib2


BASE_DIR = '/opt/pertimm'

OID_BASE = '.1.3.6.1.4.1.38673.1.30.2'

POLLING_INTERVAL = 30


def extract_id(string):
    try:
        return int(string.split('1', 1)[0])
    except:
        return False


def get_instances():
    instances = []

    for entry in sorted(os.listdir(os.path.join(BASE_DIR, 'projects'))):
        chunks = entry.split('-', 1)
        instances.append((int(chunks[0]), chunks[1]))

    return instances


def poll():
    instances = get_instances()

    snmp.add_int('1', len(instances))

    for index, instance in enumerate(instances):
        # Define base instance information
        snmp.add_int('2.%d' % index, instance[0])
        snmp.add_str('3.%d' % index, instance[1])

        # Request statistics data
        request = urllib2.urlopen('http://localhost:8080/%03d-%s/api/check/stats.php?instance=%s' %
            (instance + ('search',)))

        total = 0.0
        data = json.load(request)

        for entry in data[0]['stats']['load']['request_per_10_sec']:
            total += float(entry['nb_requests_per_sec'])

        snmp.add_str('4.%d' % index, total)


def print_usage(output=sys.stdout):
    output.write('''Usage: %(program)s [OPTIONS]

Options:
  -h  display this help and exit
''' % {'program': os.path.basename(sys.argv[0])})


if __name__ == '__main__':
    # Parse command-line arguments
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'b:f:hl')
    except getopt.GetoptError, e:
        sys.stderr.write('Error: %s\n' % e)
        print_usage(output=sys.stderr)
        sys.exit(1)

    for opt, arg in opts:
        if opt == '-h':
            print_usage()
            sys.exit(0)

    log = codecs.open('/tmp/%s.err' %
        os.path.splitext(os.path.basename(sys.argv[0]))[0], 'w', 'utf-8')

    try:
        snmp = snmp.PassPersist(OID_BASE)
        snmp.start(poll, POLLING_INTERVAL)

        log.close()
    except KeyboardInterrupt, SystemExit:
        log.close()
        sys.exit(0)
    except:
        import traceback
        traceback.print_exc(file=log)

        log.close()
        sys.exit(1)

# vim: ts=4 sw=4 et
