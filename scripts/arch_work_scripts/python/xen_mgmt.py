#!/usr/bin/env python

#
# Xen Virtual Machines Management
#
# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/usrlocal/files/common/tool/virt/bin/xen_mgmt.py $
#


# ================================================
#   Modules
# ================================================

import os, sys, socket, re
import argparse
import commands




# ================================================
#   Class : Utils (static methods)
# ================================================

class Utils :
  # Get file's content
  # ------------------
  @staticmethod
  def readFile(filename) :
    data = []
    try :
      f = open(filename, 'r')
      data = f.readlines()
      f.close()
    except :
      print "* Error : '%s' does not exist or can not be read. *" % filename
      sys.exit(1)
    return data


  # Write content to file
  # ---------------------
  @staticmethod
  def writeFile(filename, content) :
    try :
      f = open(filename, 'w')
      f.write(content + "\n")
      f.close()
      return True
    except :
      print "* Error : failed to create file '%s'. *" % filename
      return False


  # Check if FQDN exists
  # --------------------
  @staticmethod
  def checkFQDN(fqdn = '') :
    fqdn = fqdn.replace('\n', '')
    if not re.match('(^#|^$)', fqdn) :
      try :
        if socket.gethostbyname(fqdn) :
          return fqdn
      except :
        return None


  # Get MAC address from FQDN
  # - Xen ID : 00:16:3e
  # - Host ID : ex. (10.)3.235.112 ==> 03:eb:70
  # -------------------------------------------
  @staticmethod
  def getMACaddr(fqdn) :
    ip = socket.gethostbyname(fqdn)
    mac = '00:16:3e:' + ':'.join([ hex(int(x))[2:].zfill(2) for x in ip.split('.')[1:4]])
    return mac


  # Delete file
  # -----------
  @staticmethod
  def deleteFile(filename) :
    try :
      os.remove(filename)
      return True
    except :
      return False


  # Return commandline status
  # -------------------------
  @staticmethod
  def cmdStatus(cmd) :
    return True if 0 == commands.getstatusoutput(cmd)[0] else False




# ================================================
#   Class : LVM
# ================================================

class LVM :
  # Check if LV exists
  # ------------------
  def lvscan(self, vg, lv) :
    cmd = "lvdisplay /dev/%s/%s" % (vg, lv)
    return True if Utils.cmdStatus(cmd) else False


  # Create a LV
  # -----------
  def create_lv(self, vg, lv, size) :
    # Exits if LV exists
    if self.lvscan(vg, lv) :
      print "'%s' already exists." % lv
      return False
    # Create LV
    cmd = "lvcreate -L %s -n %s %s" % (size, lv, vg)
    if not Utils.cmdStatus(cmd) :
      print "Failed to create LV '/dev/%s/%s'" % (vg, lv)
      return False
    return True


  # Remove LV
  # ---------
  def remove_lv(self, vg, lv, force) :
    # Exits if LV does not exist
    if not self.lvscan(vg, lv) :
      return False
    # Ask before deleting if no '-F/--force' option
    if not force :
      choice = raw_input("Confirm '%s' removal [y/n] :" % ('/dev/' + vg + '/' + lv))
      if 'y' == choice or 'Y' == choice :
        pass
      else :
        return False
    cmd = "lvremove --force /dev/%s/%s" % (vg, lv)
    return True if Utils.cmdStatus(cmd) else False




# ================================================
#   Class : VirtualMachine management
# ================================================

class VirtualMachine :
  vm_confdir  = '/etc/xen/vm'

  # Generate Xen HVM configuration file
  # -----------------------------------
  def genConfig(self, configFile, server, args) :
    mac         = Utils.getMACaddr(server)
    device      = 'xvda'

    #if re.findall('^oracle.*', args.image) :
    #  device = 'hda'

    content     = "# \n\
# Configuration file for the Xen instance {0} \n#\n\n\
name = '{0}' \n\n\
builder = 'hvm' \n\
device_model = '/usr/lib/xen-default/bin/qemu-dm' \n\
bootloader = '/usr/lib/xen-default/bin/pygrub' \n\
kernel = '/usr/lib/xen-default/boot/hvmloader' \n\n\
# Maximum number of VCPUs allocated \n\
vcpus = {1} \n\n\
# Memory \n\
memory = '{2}' \n\
# Maximum memory (limit) \n\
maxmem = '{3}' \n\n\
# Disks \n\
disk = [ 'phy:/dev/{4}/{0},{7},w' ]\n\n\
vif = [ 'bridge={5}, mac={6}' ] \n\n\
boot = 'nc' \nserial='pty' \nsdl = 0 \n\
on_poweroff = 'destroy' \non_reboot   = 'restart' \non_crash    = 'restart' \
    " . format(server, args.vcpus, args.memory, args.maxmem, args.volgroup, args.bridge, mac, device)

    Utils.writeFile(configFile, content)


  # Create a VM from the commandline
  # --------------------------------
  def create_VM(self, args) :
    fullServersList  = []
    undefServersList = []
    serversList      = []
    lvm              = LVM()
    srv_deploy       = 'deploy01.tool.common.prod.vit.e-merchant.net'
    cmd_genPXE       = ''

    # Missing arguments : no FQDN nor list of servers
    if None == args.fqdn and None == args.serversList :
      print '* Error : FQDN or list of servers missing ! *'
      sys.exit(1)

    # Getting FQDN from command line
    if None != args.fqdn :
      for server in args.fqdn :
        if Utils.checkFQDN(server) is not None :
          serversList.append(server)
        else :
          undefServersList.append(server)
    # Getting FQDN(s) from file
    else :
      filename = args.serversList
      data = Utils.readFile(filename)
      for server in data :
        if Utils.checkFQDN(server) is not None :
          serversList.append(server)
        else :
          undefServersList.append(server)

    # Generate MAC addresses for undefined FQDNs
    for server in undefServersList :
      print "* Error : '%s' does not exist. *" % server
      ip = raw_input('Enter VM\'s IP address : ')
      try :
        if socket.inet_aton(ip) :
          mac = Utils.getMACaddr(ip)
          print "Please add these entries in DNS & DHCP configurations before VM creation :\n \
- Hostname : %s\n - IP address : %s\n - MAC address : %s\n" % (server, ip, mac)
      except :
        print "* Error : illegal IP address '%s'. *" % ip

    for server in serversList :
      print "\n[  Xen HVM creation : %s  ]" % server

      # Next server if LV creation fails
      if not lvm.create_lv(args.volgroup, server, args.size) :
        continue

      # Generate Xen HVM configuration file
      configFile  = "%s/%s.cfg" % (self.vm_confdir, server)
      self.genConfig(configFile, server, args)

      # PXE configuration file
      # Oracle Linux 5.X
      if re.findall('^oracle-linux5.*', args.image) :
        cmd_genPXE = "ssh %s 'deploy -f %s --image %s -H 0 --xen -o xen-oraclelinux5" %(srv_deploy, server, args.image)
      # Oracle Linux 6.X
      elif re.findall('^oracle-linux6.*', args.image) :
        cmd_genPXE = "ssh %s 'deploy -f %s --image %s -H 0 --xen -o xen-oraclelinux6" %(srv_deploy, server, args.image)
      # Linux Ubuntu
      else :
        cmd_genPXE = "ssh %s 'deploy -f %s --image %s -H 0 --xen -o xen-precise'" %(srv_deploy, server, args.image)

      print "Command to execute in order to generate PXE configuration file :\n# %s" % cmd_genPXE

      # VM creation
      cmd_xmcreate = "xm create -c %s" % configFile
      print "Command to execute in order to create VM :\n# %s" % cmd_xmcreate

      # Summary
      print "\nSummary\n--------------------"
      print "Hostname           : %s" % server
      print "Distribution       : %s" % args.image
      print "Disk size          : %s" % args.size
      print "Memory             : %s" % args.memory
      print "Maximum memory     : %s" % args.maxmem
      print "VCPUs              : %s" % args.vcpus
      print "Bridge             : %s" % args.bridge
      print "IP address         : %s" % socket.gethostbyname(server)
      print "MAC address        : %s" % Utils.getMACaddr(server)
      print "Configuration file : %s" % configFile
      print "\n"


  # Shutdown a VM
  # -------------
  def shutdown_VM(self, server) :
    # If VM is running
    if Utils.cmdStatus("xm list %s" % server) :
      # Shutdown the VM 
      print True if Utils.cmdStatus("xm shutdown %s" % server) else False
    return True


  # Migrate a VM
  # ------------
  def migrate_VM(self, args) :
    lvm         = LVM()

    # Check if VM/LV exists
    if not lvm.lvscan(args.volgroup, args.fqdn) :
      print "* Error: VM '%s' does not exist. *" % args.fqdn
      return False

    # Check if destination hypervisor exists
    if not Utils.checkFQDN(args.hypervisor) :
      print "* Error: hypervisor '%s' does not exist. *" % args.hypervisor
      return False

    print '\n!! NOT HANDLED YET !!'


  # Delete a VM
  # -----------
  def delete_VM(self, args) :
    serversList = []
    lvm         = LVM()

    # Missing arguments : no FQDN nor list of servers
    if None == args.fqdn and None == args.serversList :
      print '* Error : FQDN or list of servers missing ! *'
      sys.exit(1)

    # Getting FQDN from command line
    # Getting FQDN from command line
    if None != args.fqdn :
      serversList = [ Utils.checkFQDN(l) for l in args.fqdn if Utils.checkFQDN(l) is not None ]

    # Getting FQDN(s) from file
    else :
      filename = args.serversList
      data = Utils.readFile(filename)
      serversList = [ Utils.checkFQDN(l) for l in data if Utils.checkFQDN(l) is not None ]

    # Execute commands for each VM
    for server in serversList :
      print "\n[  Xen HVM removal : %s  ]" % server

      # Summary
      print "Summary\n--------------------"
      print "Hostname           : %s" % server

      # Shutdown the VM
      if self.shutdown_VM(server) :
        print 'VM status          : shutdown'
      # Next server if shutdown fails
      else :
        print 'VM status          : still running'
        continue
      
      # Next server if LV removal fails
      if lvm.remove_lv(args.volgroup, server, args.force) :
        print "Removed LV         : %s" % ('/dev/' + args.volgroup + '/' + server)
      else :
        print "Remove LV          : '%s' does not exist" % ('/dev/' + args.volgroup + '/' + server)

      # Delete Xen HVM configuration
      configFile  = "%s/%s.cfg" % (self.vm_confdir, server)
      if Utils.deleteFile(configFile) :
        print "Deleted file       : %s" % configFile
      else :
        print "Deleted file       : '%s' does not exist" % configFile



# ================================================
#   Main function
# ================================================

def main() :
  parser = argparse.ArgumentParser(description='Xen Virtual Machine (HVM) management', add_help=True)
  subparsers = parser.add_subparsers()


  # Sub-commands : create a virtual machine
  p_create = subparsers.add_parser('create', help='Create a VirtualMachine')
  p_create.add_argument(
    '--create', action='store_false', help=argparse.SUPPRESS)
  p_create.add_argument(
    '-f', '--fqdn', help='Name of the virtual machine to create', metavar='fqdn', action='append'
  )
  p_create.add_argument(
    '-l', '--serversList', help='List of virtual machines to create', metavar='serversList'
  )
  p_create.add_argument(
    '-i', '--image', help='Image name. Default if not given: \'precise-x86_64\'', metavar='image', default='precise-x86_64'
  )
  p_create.add_argument(
    '-g', '--volgroup', help='Volume group. Default if not given: \'mvg\'', metavar='volgroup', default='mvg'
  )
  p_create.add_argument(
    '-s', '--size', help='Size to allocate to the new disk image. Suffixes: \'M\' for megabytes, \'G\' for gigabytes,...', metavar='size', required=True
  )
  p_create.add_argument(
    '-m', '--memory', help='Amount of memory allocated. Size to give in Mb', metavar='memory', type=int, required=True
  )
  p_create.add_argument(
    '-M', '--maxmem', help='Amount of maximum memory (limit). Size to give in Mb', metavar='maxmem', type=int, required=True
  )
  p_create.add_argument(
    '-p', '--vcpus', help='Number of VCPUS', metavar='vcpus', type=int, required=True
  )
  p_create.add_argument(
    '-b', '--bridge', help='Bridge name (ex. xenbr235)', metavar='bridge', required=True
  )


  # Sub-commands : migrate a virtual machine
  p_migrate = subparsers.add_parser('migrate', help = 'Migrate a VirtualMachine')
  p_migrate.add_argument(
    '--migrate', action='store_false', help = argparse.SUPPRESS
  )
  p_migrate.add_argument(
    '-f', '--fqdn', help = 'Name of the virtual machine to migrate', metavar = 'fqdn', required = True
  )
  p_migrate.add_argument(
    '-H', '--hypervisor', help = 'Name of the destination hypervisor', metavar = 'hypervisor', required = True
  )
  p_migrate.add_argument(
   '-g', '--volgroup', help='Volume group', metavar='volgroup', default='mvg'
  )


  # Sub-commands : delete a virtual machine
  p_delete = subparsers.add_parser('delete', help = 'Delete a VirtualMachine')
  p_delete.add_argument(
    '--delete', action='store_false', help=argparse.SUPPRESS
  )
  p_delete.add_argument(
   '-f', '--fqdn', help='Name of the virtual machine to delete', metavar='fqdn', action='append'
  )
  p_delete.add_argument(
    '-l', '--serversList', help='List of virtual machines to delete', metavar='serversList'
  )
  p_delete.add_argument(
   '-g', '--volgroup', help='Volume group', metavar='volgroup', default='mvg'
  )
  p_delete.add_argument(
    '-F', '--force', help='Do not prompt', action='store_true'
  )

  args = parser.parse_args()

  vm = VirtualMachine()
  if 'create' in args :
    vm.create_VM(args)
  elif 'migrate' in args :
    vm.migrate_VM(args)
  elif 'delete' in args :
    vm.delete_VM(args)


if __name__ == "__main__" :
  main()

