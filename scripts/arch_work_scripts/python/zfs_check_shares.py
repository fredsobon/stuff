#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
$HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/nagios/files/default/scripts/zfs_check_shares.py $

Description
  NFS Shares monitoring on ZFS filers
"""


import argparse
import netsnmp
import socket, sys


snmp_version = 2
snmp_community  = 'pixro'
oid_sharename   = '.1.3.6.1.4.1.42.2.225.1.6.1.6'
oid_space_total = '.1.3.6.1.4.1.42.2.225.1.6.1.10'
oid_space_used  = '.1.3.6.1.4.1.42.2.225.1.6.1.11'
warning = 1
critical = 2
unknown = 3


def get_values(fqdn, oid, idx = None) :
  session = netsnmp.Session( DestHost = fqdn, Version = snmp_version, Community = snmp_community, UseNumeric = 1 )
  if None == idx :
    return session.walk(netsnmp.VarList( netsnmp.Varbind(oid) ))
  else :
    return session.walk(netsnmp.VarList( netsnmp.Varbind(oid) ))[idx]

def check_fqdn(fqdn) :
  try :
    if socket.gethostbyname(fqdn) :
      return fqdn
  except :
    return None


def main() :
  # Arguments
  parser = argparse.ArgumentParser(description='NFS shares monitoring on ZFS filers', add_help=True)
  parser.add_argument('-H', '--HOST', dest='host', help='Host address', required=True)
  parser.add_argument('-w', '--warning', dest='warning_threshold', help='Warning threshold', type=int, required=True)
  parser.add_argument('-c', '--critical', dest='critical_threshold', help='Critical threshold', type=int, required=True)
  args = parser.parse_args()

  if None == check_fqdn(args.host) :
    sys.exit(1)

  nb_warning  = 0
  nb_critical = 0
  shares      = get_values(args.host, oid_sharename)

  for idx in range(0, len(shares)) :
    share       = shares[idx]
    space_total = get_values(args.host, oid_space_total, idx)
    space_used  = get_values(args.host, oid_space_used, idx)
    percent     = int(float(space_used) / float(space_total) * 100)
    if percent > args.critical_threshold :
      print 'CRITICAL :: Disk usage %s: %d%% used (%dM/%dM)(>%d%%)' % (share, percent, int(space_used)/1048576, int(space_total)/1048576, args.critical_threshold)
      nb_critical += 1
      continue
    elif percent > args.warning_threshold :
      print 'WARNING :: Disk usage %s: %d%% used (%dM/%dM)(>%d%%)' % (share, percent, int(space_used)/1048576, int(space_total)/1048576, args.warning_threshold)
      nb_warning += 1
      continue

  if nb_critical > 0 :
    sys.exit(2)
  elif nb_warning > 0 :
    sys.exit(1)
  else :
    print 'OK'


if __name__ == "__main__" :
  main()

