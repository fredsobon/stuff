#!/usr/bin/env python
# vim: ts=4 sw=4 et
# Maxime Guillet - Fri, 16 Nov 2012 17:05:32 +0100

import getopt
import os
import subprocess
import sys

OID_BASE = '.1.3.6.1.4.1.38673.0.1'

class VirtualDisk:
    def __init__(self):
        self.identifier = None
        self.level = None
        self.size = None
        self.state = ''

        self.pdisk = dict()
        self.pdisk_id = 0
        self.pdisk_id_next = 0

    def pdisk_add(self, num):
        self.pdisk_id = self.pdisk_id_next
        self.pdisk_id_next += 1
        self.pdisk[self.pdisk_id] = PhysicalDisk()
        self.pdisk[self.pdisk_id].identifier = num

    def pdisk_current(self):
        return self.pdisk[self.pdisk_id]

    def show_vdisk(self):
        print 'VDisk %s (RAID Level %s - %s - State: %s)' % (
            self.identifier,
            self.level,
            self.size,
            self.state
        )

    def show_pdisks(self):
        for num in self.pdisk.keys():
            self.pdisk[num].show_pdisk()

    def show_all(self):
        self.show_vdisk()
        self.show_pdisks()

    def get_short(self):
        pdisk_desc = list()

        if self.get_status() == 0:
            return ''
        else:
            for num in self.pdisk.keys():
                if self.pdisk[num].get_status() != 0:
                    pdisk_desc.append('PDisk %s failed' % self.pdisk[num].identifier)

            return 'VDisk %s %s (%s)' % (self.identifier, self.state.lower(), ', '.join(pdisk_desc))

    def get_status(self):
        if self.state.find('Optimal') == -1:
            return 1
        else:
            return 0

class PhysicalDisk:
    def __init__(self):
        self.identifier = None
        self.enclosure = None
        self.slot = None
        self.device_id = None
        self.size = None
        self.state = ''

    def show_pdisk(self):
        print ' . PDisk %s (%s - [E%s:S%s] - State: %s)' % (
            self.identifier,
            self.size,
            self.enclosure,
            self.slot,
            self.state,
        )

    def get_status(self):
        if self.state.find('Online, Spun Up') == -1:
            return 1
        else:
            return 0

def get_raid():
    vdisk = dict()
    vdisk_id = 0
    vdisk_id_next = 0

    try:
        megacli = subprocess.Popen([
            os.path.join(os.path.dirname(os.path.realpath(__file__)), 'MegaCli64'),
            '-LdPdInfo', '-aALL'],
            stdin=None, stdout=subprocess.PIPE, stderr=None)
        megacli_info = megacli.communicate()
    except (OSError, IOError):
        return None

    if os.path.exists('MegaSAS.log'):
        os.unlink('MegaSAS.log')

    for line in megacli_info[0].split('\n'):
        if line.startswith("Virtual Drive:"):
            vdisk_id = vdisk_id_next
            vdisk_id_next += 1
            vdisk[vdisk_id] = VirtualDisk()
            vdisk[vdisk_id].identifier = line.split()[2]

        elif line.startswith("RAID Level"):
            vdisk[vdisk_id].level = line.split()[3].replace('Primary-', '').rstrip(',')

        elif line.startswith("Size"):
            vdisk[vdisk_id].size = ' '.join(line.split()[2:4])

        elif line.startswith("State"):
            vdisk[vdisk_id].state = ' '.join(line.split()[2:])

        elif line.startswith('PD:'):
            vdisk[vdisk_id].pdisk_add(line.split()[1])

        elif line.startswith('Enclosure Device ID:'):
            vdisk[vdisk_id].pdisk_current().enclosure = line.split()[3]

        elif line.startswith('Slot Number:'):
            vdisk[vdisk_id].pdisk_current().slot = line.split()[2]

        elif line.startswith('Device Id:'):
            vdisk[vdisk_id].pdisk_current().device_id = line.split()[2]

        elif line.startswith('Coerced Size:'):
            vdisk[vdisk_id].pdisk_current().size = ' '.join(line.split()[2:4])

        elif line.startswith('Firmware state:'):
            vdisk[vdisk_id].pdisk_current().state = ' '.join(line.split()[2:])

    return vdisk

def snmp_return(raid_volumes, is_state = True):
    status = 0
    description = list()
    for vdisk in raid_volumes:
        state = raid_volumes[vdisk].get_status()
        if state != 0:
            status = 1
            description.append(raid_volumes[vdisk].get_short())

    if is_state:
        print(OID_BASE + '.1')
        print('integer')
        print(status)
    else:
        print(OID_BASE + '.2')
        print('string')
        if len(description):
            print(' / '.join(description))
        else:
            print(' ')

if __name__ == '__main__':
    try:
        OPTS, ARGS = getopt.gnu_getopt(sys.argv[1:], 'g:n:so')
    except getopt.GetoptError, e:
        print '%s' % e
        sys.exit(1)

    for opt, arg in OPTS:
        if opt == '-o':
            raid_vol = get_raid()
            for vd in raid_vol:
                raid_vol[vd].show_all()
            sys.exit(0)
        elif (opt == '-g' and arg == OID_BASE + '.1') or (opt == '-n' and arg == OID_BASE):
            snmp_return(get_raid(), True)
            sys.exit(0)
        elif (opt == '-g' and arg == OID_BASE + '.2') or (opt == '-n' and arg == OID_BASE + '.1'):
            snmp_return(get_raid(), False)
            sys.exit(0)
        elif opt == '-s':
            print 'SET requests are not yet implemented'
            sys.exit(0)

    sys.exit(0)
