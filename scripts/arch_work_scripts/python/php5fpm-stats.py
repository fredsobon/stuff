#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Thu, 22 Dec 2011 13:00:21 +0100

import glob
import pycurl
import snmp_passpersist as snmp
import sys
import time
import traceback

polling_interval = 10
oid_base = '.1.3.6.1.4.1.38673.1.5'
oid_table = {
    'accepted conn': ['1.1', 'cnt_32bit'],
    'pool': ['1.2', 'str'],
    'process manager': ['1.3', 'str'],

    'idle processes': ['2.1', 'gau'],
    'active processes': ['2.2', 'gau'],
    'total processes': ['2.3', 'gau'],
    'max children reached': ['2.4', 'gau'],
}

class PhpFpm:
    def __init__(self):
        self.stats = {}
        self.cache_ttl = 2.0
        self.time = time.time() - self.cache_ttl - 1.0
        self.contents = ''

        self.vhost = []

    def get_vhosts(self):
        self.vhost = []
        vhost_sockets = glob.glob('/var/run/fpm-*.socket')
        for vhost_socket in vhost_sockets:
            self.vhost.append(vhost_socket.split('-', 1)[1].rsplit('.', 1)[0].replace('_', '-'))

    def body_callback(self, buf):
        self.contents = self.contents + buf

    def update_stats(self):
        now = time.time()
        if now - self.time < self.cache_ttl:
            return

        self.get_vhosts()
        node = 0

        c = pycurl.Curl()
        c.setopt(pycurl.URL, "http://127.0.0.1/fpm-status")
        for vhost in self.vhost:
            self.contents = ''
            c.setopt(pycurl.HTTPHEADER, ["Host: " + vhost])
            c.setopt(c.WRITEFUNCTION, self.body_callback)
            c.perform()

            for line in self.contents.splitlines():
                fields = line.split(':')
                if not fields[0] in self.stats:
                    self.stats[fields[0]] = {}
                self.stats[fields[0]][node] = fields[1].lstrip()

            node += 1

        c.close()
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

        oid_firstlvl = oid_table[key][0]

        for oid_nextlvl in stats.stats[key]:
            if hasattr(pp, 'add_' + oid_table[key][1]):
                getattr(pp, 'add_' + oid_table[key][1])(oid_firstlvl + '.' + str(oid_nextlvl), stats.stats[key][oid_nextlvl])
            else:
                pp.add_str(oid_firstlvl + '.' + str(oid_nextlvl), stats.stats[key][oid_nextlvl])

if __name__ == '__main__':
    try:
        stats = PhpFpm()

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
