#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Thu, 22 Dec 2011 12:59:06 +0100

import pycurl
import snmp_passpersist as snmp
import sys
import time
import traceback

polling_interval = 30
oid_base = '.1.3.6.1.4.1.38673.1.1'
oid_table = {
    'Total Accesses':  ['0', 'int'],
    'Total kBytes':    ['1', 'int'],
    'CPULoad':         ['2', 'str'],
    'Uptime':          ['3', 'int'],
    'ReqPerSec':       ['4', 'str'],
    'BytesPerSec':     ['5', 'str'],
    'BytesPerReq':     ['6', 'str'],
    'BusyWorkers':     ['7', 'int'],
    'IdleWorkers':     ['8', 'int'],

    '_':  ['9.0', 'int'],
    'S':  ['9.1', 'int'],
    'R':  ['9.2', 'int'],
    'W':  ['9.3', 'int'],
    'K':  ['9.4', 'int'],
    'D':  ['9.5', 'int'],
    'C':  ['9.6', 'int'],
    'L':  ['9.7', 'int'],
    'G':  ['9.8', 'int'],
    'I':  ['9.9', 'int'],
    '.':  ['9.10', 'int']
}


class ApacheStats:
    def __init__(self):
        self.stats = {}
        self.cache_ttl = 2.0
        self.time = time.time() - self.cache_ttl - 1.0
        self.contents = ''

    def body_callback(self, buf):
        self.contents = self.contents + buf

    def update_stats(self):
        now = time.time()
        if now - self.time < self.cache_ttl:
            return

        c = pycurl.Curl()
        c.setopt(pycurl.URL, "http://127.0.0.1/server-status?auto")
        self.contents = ''
        c.setopt(c.WRITEFUNCTION, self.body_callback)
        try:
            c.perform()
        except:
            return

        if c.getinfo(pycurl.HTTP_CODE) != 200:
            return

        c.close()

        # dice up the data
        scoreboardkey = [ '_', 'S', 'R', 'W', 'K', 'D', 'C', 'L', 'G', 'I', '.' ]

        for line in self.contents.splitlines():
            fields = line.split(':')
            fields[1] = fields[1].lstrip()

            if fields[0] == 'Scoreboard':
                # count up the scoreboard
                for state in scoreboardkey:
                    self.stats[state] = 0
                for state in fields[1]:
                    self.stats[state] += 1
            elif fields[0] == 'Total kBytes':
                # turn into base (byte) value
                self.stats[fields[0]] = int(fields[1])*1024
            else:
                # just store everything else
                self.stats[fields[0]] = fields[1]

        self.time = now
        return

    def get_stats(self):
        self.update_stats()
        return self.stats


def update_def():
    stats.update_stats()
    for key in oid_table:
        if not key in stats.stats:
            continue

        if hasattr(pp, 'add_' + oid_table[key][1]):
            getattr(pp, 'add_' + oid_table[key][1])(oid_table[key][0], stats.stats[key])
        else:
            pp.add_str(oid_table[key][0], stats.stats[key])

if __name__ == '__main__':
    try:
        stats = ApacheStats()

        pp = snmp.PassPersist(oid_base)

        try:
            pp.start(update_def, polling_interval)
        except KeyboardInterrupt:
            print >> sys.stderr, "Exiting on user request."
            sys.exit(0)
        except IOError:
            pass
    except SystemExit:
        pass
    except:
        from os.path import basename, splitext
        traceback.print_exc(file=open('/tmp/%s.error' % splitext(basename(sys.argv[0]))[0], 'w'))
        sys.exit(1)
