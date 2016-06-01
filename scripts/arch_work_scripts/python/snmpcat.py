#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''
Read file content aim to be used with snmpd pass option
Last Updated: Maxime Guillet - Fri, 29 Jun 2012 14:30:38 +0200
'''

import argparse
import sys
import os

def readfile(filename):
    '''
    Read a file and print first 4096 characters in one single line
    '''
    fhandle = open(filename, 'r')
    print fhandle.read(4096).replace('\r', '|').replace('\n', '|')
    fhandle.close()
    return

if __name__ == '__main__':

    # Parse command line
    parser = argparse.ArgumentParser(description='Content file reader for SNMPd pass option')

    parser.add_argument('-o', '--oidbase', dest='oidbase', help='define base oid', metavar='OID', required=True)
    parser.add_argument('-f', '--file', dest='filename', help='file to read', required=True)
    parser.add_argument('-g', '--get', dest='get', help='snmp pass get request', metavar='OID')
    parser.add_argument('-n', '--getnext', dest='getnext', help='snmp pass getnext request', metavar='OID')
    parser.add_argument('-s', '--set', dest='set', help='snmp pass set request', metavar='OID')

    args = parser.parse_args()

    # Append dot if oidbase not start with
    if not args.oidbase.startswith('.'):
        args.oidbase = '.' + args.oidbase

    # Exit if use set requets
    if args.set:
        print >> sys.stderr, 'snmp set requests are not implemented here'
        sys.exit(0)

    # Check file
    if not os.path.exists(args.filename) or not os.access(args.filename, os.R_OK):
        print >> sys.stderr, 'file %s not found or unreadable' % args.filename
        sys.exit(1)

    # Get filename
    if args.get == args.oidbase + '.0' or args.getnext == args.oidbase:
        print args.oidbase + '.0'
        print 'string'
        print args.filename

    # Get filename content
    elif args.get == args.oidbase + '.1' or args.getnext == args.oidbase + '.0':
        print args.oidbase + '.1'
        print 'string'
        readfile(args.filename)

    sys.exit(0)
