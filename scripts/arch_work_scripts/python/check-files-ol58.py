#!/usr/bin/env python26
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Wed, 14 Nov 2012 11:40:34 +0100
# Similar to check-files.py but with python26 explicitly specified

import getopt
import os
import os.path
import pickle
import sys
import time
import yaml

oid_base = '.1.3.6.1.4.1.38673.1.10'
checkfile_list = '/etc/snmp/check-filelist.yaml'
cache_file = '/tmp/check-fileslist.cache'

def filecheck():
    if os.path.exists(cache_file) and time.time() - os.stat(cache_file).st_ctime <= 2:
        data_return = pickle.load(open(cache_file, 'rb'))
        return data_return

    try:
        yaml_file = open(checkfile_list, 'r')
        conf = yaml.load(yaml_file)
        yaml_file.close()
    except (yaml.scanner.ScannerError, yaml.parser.ParserError, yaml.composer.ComposerError, IOError):
        return [1, 'error while loading yaml config file: %s' % checkfile_list]

    return_code = [0]
    return_msg = list()

    if not conf:
        return [0, 'yaml config file %s is empty' % checkfile_list]

    for entry in conf:
        if not os.path.exists(entry['path']):
            if 'mustexists' in entry and entry['mustexists']:
                return_code.append(retcode(entry['status']))
                return_msg.append('file %s not exists' % entry['path'])
            continue

        if entry['check'] == 'size':
            if check_size(entry['path'], entry['threshold']):
                return_code.append(retcode(entry['status']))
                return_msg.append('file %s is %s than %s' % (
                    entry['path'],
                    'bigger' if entry['threshold'][0] == '+' else 'smaller',
                    entry['threshold'][1:].upper()))
        elif entry['check'] == 'age':
            if check_age(entry['path'], entry['threshold']):
                return_code.append(retcode(entry['status']))
                return_msg.append('file %s is %s than %s' % (
                    entry['path'],
                    'older' if entry['threshold'][0] == '+' else 'newer',
                    entry['threshold'][1:].lower()))
        else:
            continue

    data_return = [sorted(return_code)[-1], ' / '.join(return_msg)]

    try:
        pickle.dump(data_return, open(cache_file, 'wb'))
    except IOError:
        pass

    return data_return


def check_size(path, threshold):
    (order, value) = convert_threshold(threshold, True)

    size = os.path.getsize(path)

    if (order == '+' and size >= value) or (order == '-' and size < value):
        return 1
    else:
        return 0

def check_age(path, threshold):
    (order, value) = convert_threshold(threshold, False)

    diff = time.time() - os.stat(path).st_ctime

    if (order == '+' and diff >= value) or (order == '-' and diff < value):
        return 1
    else:
        return 0

def retcode(status):
    error_plan = {
        'ok': 0,
        'warning': 1,
        'critical': 2,
    }

    if not status in error_plan:
        status = 'warning'

    return error_plan[status]

def convert_threshold(threshold, by_size = True):
    order = threshold[0]
    value = int(threshold[1:-1])
    unit = threshold[-1].lower()

    if by_size and unit in ['b', 'k', 'm', 'g', 't']:
        if unit == 'b':
            pass
        elif unit == 'k':
            value =  value * 1024
        elif unit == 'm':
            value =  value * 1024 ** 2
        elif unit == 'g':
            value =  value * 1024 ** 3
        elif unit == 't':
            value =  value * 1024 ** 4

    elif not by_size and unit in ['s', 'm', 'h', 'd']:
        if unit == 's':
            pass
        elif unit == 'm':
            value =  value * 60
        elif unit == 'h':
            value =  value * 60 ** 2
        elif unit == 'd':
            value =  value * 60 ** 2 * 24

    return [order, value]

def pass_return(param):
    data = filecheck()
    if param:
        print(oid_base + '.0')
        print('integer')
        print(data[0])
    else:
        print(oid_base + '.1')
        print('string')
        print(data[1])
    return

if __name__ == '__main__':
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'g:n:s')
    except getopt.GetoptError, e:
        print('%s' % e)
        sys.exit(1)

    for opt, arg in opts:
        if (opt == '-g' and arg == oid_base + '.0') or (opt == '-n' and arg == oid_base):
            pass_return(True)
            sys.exit(0)
        elif (opt == '-g' and arg == oid_base + '.1') or (opt == '-n' and arg == oid_base + '.0'):
            pass_return(False)
            sys.exit(0)
        elif opt == '-s':
            print('SET requests are not yet implemented')
            sys.exit(0)

sys.exit(0)
