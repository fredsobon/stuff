#!/usr/bin/python -u
# -*- coding: utf-8 -*-
#
# apc-stats.py: APC statistics SNMP script
#               last updated on Fri, 21 Sep 2012 17:02:20 +0200
#               by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#

import glob
import json
import random
import snmp_passpersist as snmp
import socket
import StringIO
import sys

from flup.client.fcgi_app import FCGIApp


OID_BASE = '.1.3.6.1.4.1.38673.1.14'

OID_TABLE = {
    'cache_files':  ('0.0', 'int'),
    'cache_hits':   ('0.1', 'int'),
    'cache_misses': ('0.2', 'int'),

    'memory_free':  ('1.0', 'int'),
    'memory_used':  ('1.1', 'int'),
}

POLLING_INTERVAL = 30

SCRIPT_PATH = '/usr/lib/snmp/apc-stats.php'

SOCKET_PATTERN = '/var/run/fpm-*.socket'


class APCStats():
    def __init__(self):
        # Perform FastCGI request
        self._environ = {
            'GATEWAY_INTERFACE': 'CGI/1.1',
            'REQUEST_METHOD': 'GET',
            'SCRIPT_FILENAME': SCRIPT_PATH,
            'SERVER_SOFTWARE': 'E-Merchant/APC check',
            'SERVER_NAME': socket.getfqdn(),
            'SERVER_PROTOCOL': 'HTTP/1.1',
            'CONTENT_TYPE': '',
            'CONTENT_LENGTH': '',
            'wsgi.errors': sys.stderr,
            'wsgi.input': StringIO.StringIO(''),
        }

    def update_stats(self):
        # Get random FPM socket
        self._socket = random.choice(glob.glob(SOCKET_PATTERN))

        # Update stats
        self._fcgi = FCGIApp(connect=self._socket, filterEnviron=False)
        self.data = json.loads(self._fcgi(self._environ, self.start_response)[0])


    def start_response(self, status, data):
        if not status.startswith('200 '):
            sys.stderr.write("Error: request return `%s' status message\n" % status)


def update_def():
    stats.update_stats()

    for key, value in OID_TABLE.iteritems():
        getattr(snmp, 'add_' + value[1], 'add_str')(value[0], stats.data.get(key, None))


if __name__ == '__main__':
    try:
        stats = APCStats()

        snmp = snmp.PassPersist(OID_BASE)
        snmp.start(update_def, POLLING_INTERVAL)
    except KeyboardInterrupt, SystemExit:
        sys.exit(0)
    except:
        import os.path
        import traceback

        traceback.print_exc(file=open('/tmp/%s.err' % os.path.splitext(os.path.basename(sys.argv[0]))[0], 'w'))
        sys.exit(1)

# vim: ts=4 sw=4 et
