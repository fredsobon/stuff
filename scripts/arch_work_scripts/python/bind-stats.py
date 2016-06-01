#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Thu, 22 Dec 2011 12:59:06 +0100

import pycurl
import snmp_passpersist as snmp
import StringIO
import sys
import time
import traceback
from lxml import objectify

polling_interval = 30
oid_base = '.1.3.6.1.4.1.38673.1.9'
oid_table = {
    # Requests
    'Requestv4':     ['1.1', 'cnt_32bit'],
    'Requestv6':     ['1.2', 'cnt_32bit'],
    'ReqEdns0':      ['1.3', 'cnt_32bit'],
    'ReqBadEDNSVer': ['1.4', 'cnt_32bit'],
    'ReqTSIG':       ['1.5', 'cnt_32bit'],
    'ReqSIG0':       ['1.6', 'cnt_32bit'],
    'ReqBadSIG':     ['1.7', 'cnt_32bit'],
    'ReqTCP':        ['1.8', 'cnt_32bit'],

    # Rejects
    'AuthQryRej':  ['2.1', 'cnt_32bit'],
    'RecQryRej':   ['2.2', 'cnt_32bit'],
    'XfrRej':      ['2.3', 'cnt_32bit'],
    'UpdateRej':   ['2.4', 'cnt_32bit'],

    # Responses
    'Response':       ['3.1', 'cnt_32bit'],
    'TruncatedResp':  ['3.2', 'cnt_32bit'],
    'RespEDNS0':      ['3.3', 'cnt_32bit'],
    'RespTSIG':       ['3.4', 'cnt_32bit'],
    'RespSIG0':       ['3.5', 'cnt_32bit'],

    # Queries
    'QryAuthAns':    ['4.1', 'cnt_32bit'],
    'QryNoauthAns':  ['4.2', 'cnt_32bit'],
    'QryReferral':   ['4.3', 'cnt_32bit'],
    'QryRecursion':  ['4.4', 'cnt_32bit'],
    'QryDuplicate':  ['4.5', 'cnt_32bit'],
    'QryDropped':    ['4.6', 'cnt_32bit'],
    'QryFailure':    ['4.7', 'cnt_32bit'],

    # Response codes
    'QrySuccess':   ['5.1', 'cnt_32bit'],
    'QryNxrrset':   ['5.2', 'cnt_32bit'],
    'QrySERVFAIL':  ['5.3', 'cnt_32bit'],
    'QryFORMERR':   ['5.4', 'cnt_32bit'],
    'QryNXDOMAIN':  ['5.5', 'cnt_32bit'],

    # Notify
    'NotifyOutv4':  ['6.1', 'cnt_32bit'],
    'NotifyOutv6':  ['6.2', 'cnt_32bit'],
    'NotifyInv4':   ['6.3', 'cnt_32bit'],
    'NotifyInv6':   ['6.4', 'cnt_32bit'],
    'NotifyRej':    ['6.5', 'cnt_32bit'],

    # SOA/AXFS/IXFS requests
    'SOAOutv4':   ['7.1', 'cnt_32bit'],
    'SOAOutv6':   ['7.2', 'cnt_32bit'],
    'AXFRReqv4':  ['7.3', 'cnt_32bit'],
    'AXFRReqv6':  ['7.4', 'cnt_32bit'],
    'IXFRReqv4':  ['7.5', 'cnt_32bit'],
    'IXFRReqv6':  ['7.6', 'cnt_32bit'],

    # Domain transfers
    'XfrSuccess':  ['8.1', 'cnt_32bit'],
    'XfrFail':     ['8.2', 'cnt_32bit'],

    # Generic resolver information
    'Queryv4':     ['9.1', 'cnt_32bit'],
    'Queryv6':     ['9.2', 'cnt_32bit'],
    'Responsev4':  ['9.3', 'cnt_32bit'],
    'Responsev6':  ['9.4', 'cnt_32bit'],

    # Received response codes
    'NXDOMAIN':    ['10.1', 'cnt_32bit'],
    'SERVFAIL':    ['10.2', 'cnt_32bit'],
    'FORMERR':     ['10.3', 'cnt_32bit'],
    'OtherError':  ['10.4', 'cnt_32bit'],
    'EDNS0Fail':   ['10.5', 'cnt_32bit'],

    # Received responses
    'Mismatch':   ['11.1', 'cnt_32bit'],
    'Truncated':  ['11.2', 'cnt_32bit'],
    'Lame':       ['11.3', 'cnt_32bit'],
    'Retry':      ['11.4', 'cnt_32bit'],

    # DNSSEC information
    'ValAttempt':  ['12.1', 'cnt_32bit'],
    'ValOk':       ['12.2', 'cnt_32bit'],
    'ValNegOk':    ['12.3', 'cnt_32bit'],
    'ValFail':     ['12.4', 'cnt_32bit'],

    # Queries
    'Query_A':     ['13.1', 'cnt_64bit'],
    'Query_NS':    ['13.2', 'cnt_64bit'],
    'Query_CNAME': ['13.3', 'cnt_64bit'],
    'Query_SOA':   ['13.4', 'cnt_64bit'],
    'Query_MX':    ['13.5', 'cnt_64bit'],
    'Query_TXT':   ['13.6', 'cnt_64bit'],
    'Query_AAAA':  ['13.7', 'cnt_64bit'],
    'Query_AXFR':  ['13.8', 'cnt_64bit'],
    'Query_ANY':   ['13.9', 'cnt_64bit'],
    'Query_PTR':   ['13.10', 'cnt_64bit'],
    'Query_SRV':   ['13.11', 'cnt_64bit'],
}


class BindStats:
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
        c.setopt(pycurl.URL, "http://127.0.0.1:8053/")
        self.contents = ''
        c.setopt(c.WRITEFUNCTION, self.body_callback)
        try:
            c.perform()
        except:
            return

        c.close()

        content = StringIO.StringIO(self.contents)

        tree = objectify.parse(content)
        root = tree.getroot()

        for nsstat in root.bind.statistics.server.nsstat:
            self.stats[str(nsstat.name)] = int(nsstat.counter)

        for zonestat in root.bind.statistics.server.zonestat:
            self.stats[str(zonestat.name)] = int(zonestat.counter)

        for view in root.bind.statistics.views.view:
            if view.name in ['_bind', '_meta']:
                continue

            for resstat in view.resstat:
                self.stats[str(resstat.name)] = int(resstat.counter)

        for query in getattr(root.bind.statistics.server, "queries-in").iterchildren():
            self.stats['Query_' + str(query.name)] = int(query.counter)

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
        stats = BindStats()

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
