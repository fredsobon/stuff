#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Thu, 22 Dec 2011 12:59:48 +0100

import getopt
import os
import sys
import re

oid_base = '.1.3.6.1.4.1.38673.0.0'
mdfile = '/proc/mdstat'

def raidstatus():
    if not os.path.exists(mdfile):
        print >> sys.stderr, "%s file not found." % mdfile
        return [ 1, '%s file not found' % mdfile ]

    failed_count = 0
    failed_msg = ''
    device_num = 0
    i = 0

    fd = open(mdfile, 'r')
    file_lines = fd.readlines()

    while i < len(file_lines):
        line = file_lines[i]
        if line.startswith('md'):
            device_num = device_num + 1
            data = {
                'md': line.split(' ', 1)[0],
                'failed': [],
                'spare': [],
                'active': [],
                'total_num': 0,
                'up_num': 0,
                'status': '',
            }

            for block in line.split(' '):
                reg = re.match('(\w+)\[\d+\](\(.\))*', block)
                if not reg:
                    continue
                elif reg.group(2) == '(F)':
                    data['failed'].append(reg.group(1))
                elif reg.group(2) == '(S)':
                    data['spare'].append(reg.group(1))
                else:
                    data['active'].append(reg.group(1))

            i = i + 1
            next_line = file_lines[i]
            count = re.search('\[(\d+)\/(\d+)\]\s+\[(.*)\]', next_line)
            data['total_num'] = count.group(1)
            data['up_num'] = count.group(2)
            data['status'] = count.group(3)

            if data['total_num'] > data['up_num'] or data['failed']:
                failed_count = failed_count + 1
                failed_msg = failed_msg + "%s%s[%s][%s/%s] (active=%s failed=%s spare=%s)" % (
                    ':' if failed_msg else '',
                    data['md'],
                    data['status'],
                    data['up_num'],
                    data['total_num'],
                    ','.join(data['active']),
                    ','.join(data['failed']),
                    ','.join(data['spare']),
                )

        i = i + 1

    fd.close()

    if not device_num:
        return [1, "no device found"]
    else:
        return [failed_count, failed_msg]

    return

def pass_return(param):
    data = raidstatus()
    if param:
        print oid_base + '.1'
        print 'integer'
        print data[0]
    else:
        print oid_base + '.2'
        print 'string'
        print data[1]
    return

if __name__ == '__main__':
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'g:n:s')
    except getopt.GetoptError, e:
        print '%s' % e
        sys.exit(1)

    for opt, arg in opts:
        if (opt == '-g' and arg == oid_base + '.1') or (opt == '-n' and arg == oid_base):
            pass_return(True)
            sys.exit(0)
        elif (opt == '-g' and arg == oid_base + '.2') or (opt == '-n' and arg == oid_base + '.1'):
            pass_return(False)
            sys.exit(0)
        elif opt == '-s':
            print 'SET requests are not yet implemented'
            sys.exit(0)

sys.exit(0)
