#!/usr/bin/python -u
# -*- coding: utf-8 -*-
#
# goldengate-check.py: Oracle GoldenGate check
#                      by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#

import glob
import os
import random
import snmp_passpersist as snmp
import socket
import sys


OID_BASE = '.1.3.6.1.4.1.38673.1.25'

POLLING_INTERVAL = 30

DATA_DIR = '/var/lib/snmp-oracle'


def update_def():
    # Update processes states
    file_path = os.path.join(DATA_DIR, 'ggprocess')

    if not os.path.exists(file_path):
        snmp.add_int('0.0', 1)
        snmp.add_str('0.1', "Error: missing `ggprocess' file.")
    else:
        entries = [x.strip() for x in open(file_path, 'r').readlines()]
        entries_set = set(entries)

        if len(entries_set) > 1 or 'RUNNING' not in entries_set:
            snmp.add_int('0.0', 1)
        else:
            snmp.add_int('0.0', 0)

        snmp.add_str('0.1', ', '.join(entries))

    # Update lags states
    file_path = os.path.join(DATA_DIR, 'gglag')

    if not os.path.exists(file_path):
        snmp.add_int('1.0', 1)
        snmp.add_str('1.1', "Error: missing `gglag' file.")
    else:
        entries = [x.strip() for x in open(file_path, 'r').readlines()
            if x.strip().isdigit()]

        if len([x for x in entries if int(x) >= 30]) > 0:
            snmp.add_int('1.0', 1)
        else:
            snmp.add_int('1.0', 0)

        snmp.add_str('1.1', ', '.join(entries))


if __name__ == '__main__':
    try:
        snmp = snmp.PassPersist(OID_BASE)
        snmp.start(update_def, POLLING_INTERVAL)
    except KeyboardInterrupt, SystemExit:
        sys.exit(0)
    except:
        import os.path
        import traceback

        traceback.print_exc(file=open('/tmp/%s.err' %
            os.path.splitext(os.path.basename(sys.argv[0]))[0], 'w'))
        sys.exit(1)

# vim: ts=4 sw=4 et
