#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Thu, 22 Dec 2011 13:00:03 +0100

import snmp_passpersist as snmp
import socket
import sys
import time
import traceback

polling_interval = 10
memcached_nodes = ['127.0.0.1:11211', '127.0.0.1:11311']
oid_base = '.1.3.6.1.4.1.38673.1.3'
oid_table = {
    'uptime': ['1.1', 'timeticks'],
    'time': ['1.2', 'int'],
    'version': ['1.3', 'str'],
    'pointer_size': ['1.4', 'int'],
    'limit_maxbytes': ['1.5', 'str'],
    'pid': ['1.6', 'str'],

    'rusage_system': ['2.1', 'cnt_32bit'],
    'rusage_user': ['2.2', 'cnt_32bit'],

    'threads': ['3.1', 'gau'],

    'connection_structures': ['4.1', 'int'],

    'total_items': ['5.1', 'gau'],
    'curr_items': ['5.2', 'gau'],
    'bytes': ['5.3', 'gau'],

    'curr_connections': ['7.1', 'gau'],
    'total_connections': ['7.2', 'cnt_32bit'],

    'get_hits': ['8.1', 'cnt_32bit'],
    'get_misses': ['8.2', 'cnt_32bit'],
    'evictions': ['8.3', 'cnt_32bit'],

    'cmd_get': ['9.1', 'cnt_32bit'],
    'cmd_set': ['9.2', 'cnt_32bit'],

    'bytes_read': ['10.1', 'cnt_32bit'],
    'bytes_written': ['10.2', 'cnt_32bit'],

    'Mbytes_read': ['11.1', 'cnt_32bit'],
    'Mbytes_written': ['11.2', 'cnt_32bit'],
}


class Memcached:
    def __init__(self):
        self.nodes = ['127.0.0.1:11211']
        self.stats = {}
        self.cache_ttl = 2.0
        self.time = time.time() - self.cache_ttl - 1.0

    def update_stats(self):
        now = time.time()
        if now - self.time < self.cache_ttl:
            return

        node_id = 0

        for node in self.nodes:
            data = ''
            (host, port) = node.split(':')
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.connect((host, int(port)))
                s.send('stats\n')
                data = s.recv(4096)
                s.send('quit\n')
                s.close()
            except socket.error:
                s.close()

            if data:
                for line in data.splitlines():
                    fields = line.split()
                    if fields[0] == 'STAT':
                        if not fields[1] in self.stats:
                            self.stats[fields[1]] = {}

                        if fields[2]:
                            self.stats[fields[1]][node_id] = fields[2]

                for virtual in ['Mbytes_read', 'Mbytes_written']:
                    if not virtual in self.stats:
                        self.stats[virtual] = {}

                self.stats['Mbytes_read'][node_id] = int(self.stats['bytes_read'][node_id]) / 1024 / 1024
                self.stats['Mbytes_written'][node_id] = int(self.stats['bytes_written'][node_id]) / 1024 / 1024

            node_id += 1

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
        stats = Memcached()
        stats.nodes = memcached_nodes

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
