#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et

# in memcached init script :
#python -c "import memcache; memcache.Client(['localhost:11211']).set('healthcheck', 'OK')"
#python -c "import memcache; memcache.Client(['localhost:11311']).set('healthcheck', 'OK')"

import getopt
import memcache
import sys

oid = '.1.3.6.1.4.1.38673.1.3.12'

def check_memcached(mc_instances):
    retcode = 0

    for mc_instance in mc_instances.split(','):
        if memcache.Client([mc_instance]).get('healthcheck') != 'OK':
            retcode = 1

    return retcode

def pass_return(mc_instances):
    print oid
    print 'integer'
    print check_memcached(mc_instances)

if __name__ == '__main__':
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'g:i:n')
    except getopt.GetoptError, e:
        print('%s' % e)
        print('usage: %s -g|-n <oid> -i host1:port1,host2:port2,hostN:portN' % sys.argv[0])
        sys.exit(1)

    mc_instances = None

    for opt, arg in opts:
        if opt == '-n':
            print('error: SNMP getnext() is not supported, please use get() only')
            sys.exit(1)
        elif opt == '-i':
            mc_instances = arg

    if mc_instances:
        pass_return(mc_instances)

sys.exit(0)
