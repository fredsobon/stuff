#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# Maxime Guillet - Thu, 22 Dec 2011 12:59:48 +0100
# Abdelaziz Lamjarhjarh - Thu, 17 Apr 2014 12:27:52 +0200

import getopt
import os
import os.path
import subprocess
import sys
import time


OID_BASE = '.1.3.6.1.4.1.38673.1.7'

FILE_MAX_AGE = 7200

CRON_FILE = '/etc/cron.d/puppet'
DISABLE_FILE = '/tmp/puppet.disabled'
LOCK_FILE = '/var/lib/puppet/state/puppetdlock'
STATE_FILE = '/var/lib/puppet/state/state.yaml'


def puppet_cron():
    if not os.path.exists(CRON_FILE):
        return False

    state = True

    fd = open(CRON_FILE, 'r')

    for line in fd.readlines():
        if 'puppetd agent' not in line:
            continue

        state = not line.strip().startswith('#')

    fd.close()

    return state


def puppet_disable():
    return not os.path.exists(DISABLE_FILE)


def puppet_lock():
    return not os.path.exists(LOCK_FILE) or time.time() - os.stat(LOCK_FILE).st_ctime < FILE_MAX_AGE


def puppet_state():
    return os.path.exists(STATE_FILE) and time.time() - os.stat(STATE_FILE).st_ctime < FILE_MAX_AGE


def check():
    if not puppet_cron() or not puppet_disable():
        return (1, 'puppet disabled')
    elif not puppet_lock():
        return (1, 'lock file absent or too old')
    elif not puppet_state():
        return (1, 'state file absent or too old')
    else:
        return (0, 'OK')


def pass_return(param):
    data = check()

    if param == 1:
        sys.stdout.write(OID_BASE + '.1\n')
        sys.stdout.write('integer\n')
        sys.stdout.write(str(data[0]) + '\n')
    else:
        sys.stdout.write(OID_BASE + '.2\n')
        sys.stdout.write('string\n')
        sys.stdout.write(data[1] + '\n')


if __name__ == '__main__':
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'g:n:s')
    except getopt.GetoptError, e:
        sys.stderr.write('Error: %s\n' % e)
        sys.exit(1)

    for opt, arg in opts:
        if (opt == '-g' and arg == OID_BASE + '.1') or (opt == '-n' and arg == OID_BASE):
            pass_return(1)
            sys.exit(0)
        elif (opt == '-g' and arg == OID_BASE + '.2') or (opt == '-n' and arg == OID_BASE + '.1'):
            pass_return(2)
            sys.exit(0)

        elif opt == '-s':
            sys.stdout.write('SET requests are not implemented\n')
            sys.exit(0)

sys.exit(0)

# vim: ts=4 sw=4 et

