#!/usr/bin/python -u

"""
$HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/snmp/files/plugins/check-xen-domains.py $

Description
  Get informations on Xen running domains
Usage :
  $ ./check-xen-domains.py [-l] [-h]
Syntax snmp :
  pass_persist .1.3.6.1.4.1.38673.1.29.2 /usr/lib/snmp/check-xen-domains.py

"""




import sys, re
import argparse
import snmp_passpersist as snmp
import socket
import subprocess
from XenAPI import Session




oid_base      = '.1.3.6.1.4.1.38673.1.29.2'
poll_refresh  = 30




class XenTop() :
  host_stats = {}
  vms_stats = []
  api = None

  def xen_api(self) :
    api_port      = 9363
    api_user      = 'root'
    api_pswd      = ''
    api_url       = 'http://localhost:%d' % api_port

    session = Session(api_url)
    try :
      self.api = session.xenapi
      self.api.login_with_password(api_user, api_pswd)
    except :
      pass
    finally :
      session.logout()


  def get_host_stats(self) :
    self.xen_api()
    host_uuid = self.api.host_metrics.get_all()[0]
    records = self.api.host_metrics.get_all_records()[host_uuid]
    self.host_stats['mem_free']  = int(records['memory_free']) / 1024
    self.host_stats['mem_total'] = int(records['memory_total']) / 1024
    self.host_stats['mem_used']  = self.host_stats['mem_total'] - self.host_stats['mem_free']


  def get_vms_stats(self) :
    self.vms_stats  = []
    cmd         = 'sudo /usr/sbin/xentop --batch --full-name --iterations 1 --networks --repeat-header'
    output      = []
    states      = {'r':'running', 'b':'blocked', 'p':'paused', 's':'shutdown', 'c':'crashed', 'd':'dying' }

    # Execute command
    try :
      p = subprocess.Popen(cmd , shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
      out, err = p.communicate()
      output = out.split('\n')
    except Exception as e :
      print '* Error : %s *' % e
      sys.exit(1)

    # Format raw output
    headers = []
    for idx,line in enumerate(output) :
      if 0 != len(line) :
        if re.match(r'.*Domain-0.*', line) :
          output.insert(idx+1, 'Net0 RX: -1 -1 -1 -1 TX: -1 -1 -1 -1')
        line = re.sub('(no limit|n/a)', '-1', line)
        line = re.split(' *', line.lstrip())

        # Headers
        if ( 'NAME' == line[0] ) :
          merged = {}
          headers = line

        # Stats
        elif ( 'NAME' != line[0] and len(line) == len(headers) ) :
          values = line
          merged = dict(zip(headers, values))
          merged['STATE'] = states[re.sub('-', '', merged['STATE'])]

        # Net stats
        elif ( 'Net0' == line[0] ) :
          line = [ re.sub(r'[a-zA-Z]', '', val) for val in line ]
          merged['rx_bytes'] = line[2]
          merged['rx_drop']  = line[5]
          merged['rx_err']   = line[4]
          merged['rx_pkts']  = line[3]
          merged['tx_bytes'] = line[7]
          merged['tx_drop']  = line[10]
          merged['tx_err']   = line[9]
          merged['tx_pkts']  = line[8]
          # Save stats
          self.vms_stats.append(merged)


  def update_snmp(self) :
    self.get_host_stats()
    self.get_vms_stats()

    # Host
    snmp_pp.add_str('1.1',  socket.getfqdn())
    snmp_pp.add_int('1.2',  self.host_stats['mem_total'])
    snmp_pp.add_int('1.3',  self.host_stats['mem_used'])
    snmp_pp.add_int('1.4',  self.host_stats['mem_free'])
    snmp_pp.add_int('1.5',  len([ vm['STATE'] for vm in self.vms_stats if vm['STATE'] == 'running' ]))
    snmp_pp.add_int('1.6',  len([ vm['STATE'] for vm in self.vms_stats if vm['STATE'] == 'blocked' ]))
    snmp_pp.add_int('1.7',  len([ vm['STATE'] for vm in self.vms_stats if vm['STATE'] == 'paused' ]))
    snmp_pp.add_int('1.8',  len([ vm['STATE'] for vm in self.vms_stats if vm['STATE'] == 'crashed' ]))
    snmp_pp.add_int('1.9',  len([ vm['STATE'] for vm in self.vms_stats if vm['STATE'] == 'dying' ]))
    snmp_pp.add_int('1.10', len([ vm['STATE'] for vm in self.vms_stats if vm['STATE'] == 'shutdown' ]))

    # Domains
    for vm in self.vms_stats :
      vm_oid = sum([ ord(c) for c in vm['NAME']])
      snmp_pp.add_int('2.1.%d' % vm_oid, vm['CPU(sec)'])
      snmp_pp.add_gau('2.2.%d' % vm_oid, vm['CPU(%)'])
      snmp_pp.add_int('2.3.%d' % vm_oid, vm['MAXMEM(k)'])
      snmp_pp.add_gau('2.4.%d' % vm_oid, vm['MAXMEM(%)'])
      snmp_pp.add_int('2.5.%d' % vm_oid, vm['MEM(k)'])
      snmp_pp.add_gau('2.6.%d' % vm_oid, vm['MEM(%)'])
      snmp_pp.add_str('2.7.%d' % vm_oid, vm['NAME'])
      snmp_pp.add_int('2.8.%d' % vm_oid, vm['rx_bytes'])
      snmp_pp.add_int('2.9.%d' % vm_oid, vm['rx_drop'])
      snmp_pp.add_int('2.10.%d' % vm_oid, vm['rx_err'])
      snmp_pp.add_int('2.11.%d' % vm_oid, vm['rx_pkts'])
      snmp_pp.add_str('2.12.%d' % vm_oid, vm['STATE'])
      snmp_pp.add_int('2.13.%d' % vm_oid, vm['tx_bytes'])
      snmp_pp.add_int('2.14.%d' % vm_oid, vm['tx_drop'])
      snmp_pp.add_int('2.15.%d' % vm_oid, vm['tx_err'])
      snmp_pp.add_int('2.16.%d' % vm_oid, vm['tx_pkts'])
      snmp_pp.add_int('2.17.%d' % vm_oid, vm['VBDS'])
      snmp_pp.add_int('2.18.%d' % vm_oid, vm['VBD_RD'])
      snmp_pp.add_int('2.19.%d' % vm_oid, vm['VBD_RSECT'])
      snmp_pp.add_int('2.20.%d' % vm_oid, vm['VBD_WR'])
      snmp_pp.add_int('2.21.%d' % vm_oid, vm['VBD_WSECT'])
      snmp_pp.add_int('2.22.%d' % vm_oid, vm['VCPUS'])




if __name__ == "__main__" :
  # Variables
  xt            = XenTop()
  snmp_pp       = snmp.PassPersist(oid_base)

  # Arguments
  parser = argparse.ArgumentParser(description='Xen domains monitoring', add_help=True)
  parser.add_argument('-l', '--list', help='Display OID-tree', action='store_true')
  args = parser.parse_args()

  # Display OID-tree
  if True == args.list :
    print '''OID Tree
  xen (.1.3.6.1.4.1.38673.1.29)
  `-- XenTop (2)
      |-- Host (1)
      |   |-- xenTopHostname      (1)
      |   |-- xenTopHostMemTotal  (2)
      |   |-- xenTopHostMemUsed   (3)
      |   |-- xenTopHostMemFree   (4)
      |   |-- xenTopDomsRunning   (5)
      |   |-- xenTopDomsBlocked   (6)
      |   |-- xenTopDomsPaused    (7)
      |   |-- xenTopDomsCrashed   (8)
      |   |-- xenTopDomsDying     (9)
      |   |-- xenTopDomsShutdown  (10)
      `-- Domains (2)
          |-- xenTopCpuPerSec     (1)
          |-- xenTopCpuPercent    (2)
          |-- xenTopMaxMem        (3)
          |-- xenTopMaxMemPercent (4)
          |-- xenTopMem           (5)
          |-- xenTopMemPercent    (6)
          |-- xenTopName          (7)
          |-- xenTopRXBytes       (8)
          |-- xenTopRXDrop        (9)
          |-- xenTopRXErr         (10)
          |-- xenTopRXPkts        (11)
          |-- xenTopState         (12)
          |-- xenTopTXBytes       (13)
          |-- xenTopTXDrop        (14)
          |-- xenTopTXErr         (15)
          |-- xenTopTXPkts        (16)
          |-- xenTopVBDS          (17)
          |-- xenTopVBDSRd        (18)
          |-- xenTopVBDSRSect     (19)
          |-- xenTopVBDSWr        (20)
          |-- xenTopVBDSWSect     (21)
          `-- xenTopVcpus         (22)
    '''
    sys.exit(0)

  # SNMP update
  try :
    snmp_pp.start(xt.update_snmp, poll_refresh)
  except KeyboardInterrupt :
    sys.exit(0)

