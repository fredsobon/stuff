# -*- coding: utf-8 -*-
'''
Created on 19 oct. 2012

@author: jmmasson
'''


class Node:
    ''' tns object '''
    def __init__(self):
        self.name = None
        self.nodes = []
        self.value = None

    def parse(self, data, left=0, indent=''):
        ''' parse '''
        right = data.find('=', left)
        self.name = data[left:right].upper()
        left = right + 1
        if data[left] == '(':
            while data[left] == '(':
                left += 1
                node = Node()
                self.nodes.append(node)
                left = node.parse(data, left, indent + '-')
                if left >= len(data):
                    return left
            if data[left] == ')':
                return left + 1
            else:
                return left
        else:
            right = data.find(')', left)
            self.value = data[left:right]
            return right + 1

    def get_boolean(self):
        value = self.value.lower()
        return value == 'on' or value == 'yes' or value == 'true'


class Description:
    def __init__(self):
        self.address_list = []
        self.connect_data = None
        self.failover = None
        self.load_balance = None

    def decode(self, nodes):
        for node in nodes:
            if node.name == 'ADDRESS_LIST':
                self.decode_address_list(node.nodes)
            elif node.name == 'ADDRESS':
                self.decode_address(self.create_address_list(), node.nodes)
            elif node.name == 'CONNECT_DATA':
                self.decode_connect_data(node.nodes)
            elif node.name == 'LOAD_BALANCE':
                self.load_balance = node.get_boolean()
            elif node.name == 'FAILOVER':
                self.failover = node.get_boolean()

    def decode_address_list(self, nodes):
        address_list = self.create_address_list()
        for node in nodes:
            if node.name == 'ADDRESS':
                self.decode_address(address_list, node.nodes)
            elif node.name == 'LOAD_BALANCE' or node.name == 'FAILOVER':
                address_list[node.name.lower()] = node.get_boolean()

    def decode_address(self, address_list, nodes):
        address = {}
        if not 'addresses' in address_list:
            address_list['addresses'] = [address]
        else:
            address_list['addresses'].append(address)
        for node in nodes:
            if node.value:
                address[node.name.lower()] = node.value

    def create_address_list(self):
        address_list = {}
        self.address_list.append(address_list)
        return address_list

    def decode_connect_data(self, nodes):
        self.connect_data = {}
        for node in nodes:
            if node.value:
                self.connect_data[node.name.lower()] = node.value

    def __str__(self):
        lines = ['(DESCRIPTION =']
        if self.load_balance != None:
            lines.append(' (LOAD_BALANCE = %s)' % str(self.load_balance).lower())
        if self.failover != None:
            lines.append(' (FAILOVER = %s)' % str(self.failover).lower())

        if len(self.address_list) == 1 \
                and not 'load_balance' in self.address_list[0] \
                and not 'failover' in self.address_list[0] \
                and len(self.address_list[0]['addresses']) == 1:
            indent = ''
        else:
            indent = ' '

        for address_list in self.address_list:
            if indent:
                lines.append(' (ADDRESS_LIST =')
                if 'load_balance' in address_list:
                    lines.append('%s (LOAD_BALANCE = %s)' % (indent, str(address_list['load_balance']).lower()))
                if 'failover' in address_list:
                    lines.append('%s (FAILOVER = %s)' % (indent, str(address_list['failover']).lower()))
            for address in address_list['addresses']:
                lines.append('%s (ADDRESS = (PROTOCOL = %s)(HOST = %s)(PORT = %s))' % (indent,
                                                                                       address['protocol'],
                                                                                       address['host'],
                                                                                       address['port']))
            if indent:
                lines.append(' )')

        fields = []
        for key, value in self.connect_data.iteritems():
            if value:
                fields.append('(%s = %s)' % (key.upper(), value))
        lines.append(' (CONNECT_DATA = %s)' % ''.join(fields))

        lines.append(')')
        return '\n'.join(lines)


class Tns(Node):
    def __init__(self):
        Node.__init__(self)
        self.description_list = []
        self.load_balance = None
        self.failover = None

    def parse(self, data, left):
        result = Node.parse(self, data, left)
        for node in self.nodes:
            if node.name == 'DESCRIPTION_LIST':
                self.decode_description_list(node.nodes)
            elif node.name == 'DESCRIPTION':
                self.decode_description(self.create_description_list(),
                                        node.nodes)
        return result

    def data(self):
        data = {}
        if self.load_balance != None:
            data['load_balance'] = self.load_balance
        if self.failover != None:
            data['failover'] = self.failover
        data['descriptions'] = []
        for description_list in self.description_list:
            descriptions = []
            for description in description_list['descriptions']:
                data_list = {'address_list': description.address_list,
                            'connect_data': description.connect_data}
                if description.failover != None:
                    data_list['failover'] = description.failover
                if description.load_balance != None:
                    data_list['load_balance'] = description.load_balance
                descriptions.append(data_list)
            data_list = {'descriptions': descriptions}
            if 'failover' in description_list:
                data_list['failover'] = description_list['failover']
            if 'load_balance' in description_list:
                data_list['load_balance'] = description_list['load_balance']
            data['descriptions'].append(data_list)
        return data

    def create_description_list(self):
        description_list = {'descriptions': []}
        self.description_list.append(description_list)
        return description_list

    def decode_description_list(self, nodes):
        description_list = self.create_description_list()
        for node in nodes:
            if node.name == 'DESCRIPTION':
                self.decode_description(description_list, node.nodes)
            elif node.value:
                description_list[node.name.lower()] = node.get_boolean()

    def decode_description(self, description_list, nodes):
        description = Description()
        description_list['descriptions'].append(description)
        description.decode(nodes)

    def __str__(self):
        lines = ['%s =' % self.name]
        if len(self.description_list) == 1 \
                and not 'load_balance' in self.description_list[0] \
                and not 'failover' in self.description_list[0]:
            indent = ''
        else:
            indent = ' '

        for description_list in self.description_list:
            if indent:
                lines.append('(DESCRIPTION_LIST =')
                if 'load_balance' in description_list:
                    lines.append(' (LOAD_BALANCE = %s)' % str(description_list['load_balance']).lower())
                if 'failover' in description_list:
                    lines.append(' (FAILOVER = %s)' % str(description_list['failover']).lower())
            for description in description_list['descriptions']:
                if indent:
                    for line in str(description).split('\n'):
                        lines.append(' %s' % line)
                else:
                    lines.append(str(description))
            if indent:
                lines.append(')')
        lines.append('')
        return '\n'.join(lines)


class TnsNames:
    ''' tnsnames '''
    def __init__(self):
        self.tns = {}
        self.data = {}

    def load(self, filename):
        lines = []
        for line in open(filename, 'r'):
            line = line.strip()
            if line.startswith('#'):
                continue
            lines.append(line.replace(' ', ''))
        self.parse(''.join(lines))

    def loads(self, string):
        lines = []
        for line in string.split('\n'):
            line = line.strip()
            if line.startswith('#'):
                continue
            lines.append(line.replace(' ', ''))
        self.parse(''.join(lines))

    def parse(self, data):
        left = 0
        while left < len(data):
            tns = Tns()
            left = tns.parse(data, left)
            self.tns[tns.name] = tns
            self.data[tns.name] = tns.data()

    def __str__(self):
        lines = []
        for tns in self.tns.itervalues():
            lines.append(str(tns))
        return '\n'.join(lines)
