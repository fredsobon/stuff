#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Thu, 02 Feb 2012 15:52:47 +0100

import getopt
import sys
import os

oid_base = '.1.3.6.1.4.1.38673.1.0'
pkg_monitored_file = '/etc/snmp/monitored_packages.list'
upgrade_file = '/var/cache/yum/upgradable.list'

try:
    import apt
    mode = 'apt'
except ImportError:
    try:
        import yum
        import yum.update_md
        mode = 'yum'
    except ImportError:
        print 'neither apt nor yum python modules available.'
        sys.exit(0)

def updatecheck():
    pkg_to_monitor = list()
    try:
        pkg_file = open(pkg_monitored_file, 'r')
        for line in pkg_file:
            pkg_to_monitor.append(line.rstrip())
        pkg_file.close()
    except IOError:
        return [1, 'file containing packages to monitor is absent.']

    packages = list()
    if mode == 'apt':
        cache = apt.Cache()

        for pkg in cache:
            if pkg.is_upgradable and pkg.name in pkg_to_monitor:
                packages.append(pkg.name)

    elif mode == 'yum':
        if os.path.exists(upgrade_file):
            upgrade_handle = open(upgrade_file, 'r')

            for line in upgrade_handle:
                if line.rstrip() in pkg_to_monitor:
                    packages.append(line.rstrip())

            upgrade_handle.close()
        else:
            ybase = yum.YumBase()
            yum.update_md.UpdateMetadata()

            ybase.localPackages = []
            ybase.updates = []
            ybase.doConfigSetup(init_plugins=False)
            ygh = ybase.doPackageLists('updates')

            for pkg in ygh.updates:
                if pkg.name in pkg_to_monitor:
                    packages.append(pkg.name)

    data_list = [ len(packages), ' '.join(packages) ]

    return data_list

def pass_return(param):
    data = updatecheck()
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
