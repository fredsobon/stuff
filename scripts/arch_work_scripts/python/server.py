# -*- coding: utf-8 -*-
'''
Created on 9 oct. 2012

@author: jmmasson
'''

import socket
import json
import time
import thread
from syslog import syslog, LOG_ERR, LOG_INFO
from threading import Thread
from string import atoi
from tnsnames import TnsNames
from configuration import Configuration

PORT = 10200
TIMEOUT = 5.0
MAX_RETRY = 2


class Server(Thread):
    ''' SQLRelay server '''
    def __init__(self, address, port=PORT,
                 delay=2, timeout=TIMEOUT, listener=None):
        Thread.__init__(self)
        self.listener = listener
        self.a_lock = thread.allocate_lock()
        self.address = address
        self.port = port
        self.timeout = timeout
        self.socket = None
        self.running = True
        self.status = None
        self.configuration = None
        self.tnsnames = None
        self.tns_nodes = {}
        self.ora_nodes = {}
        self.link_tns = {}
        self.delay = delay

    def connect(self):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.setblocking(1)
        self.socket.settimeout(5.0)
        try:
            self.socket.connect_ex((self.address, self.port))
        except Exception:
            self.socket = None
        return self.socket != None

    def close(self):
        print "close %s" % self.address
        if self.socket:
            self.socket.close()
        self.socket = None

    def recv(self):
        reponse = ''
        try:
            strg = ''
            while True:
                c = self.socket.recv(1)
                if c == '\n' or c == '':
                    break
                else:
                    strg += c
            if c == '':
                return '(null)'
            try:
                size = atoi(strg)
            except:
                return "ERROR DATA %s" % strg
            while len(reponse) < size:
                reponse += self.socket.recv(4096)
        except Exception as e:
            syslog(LOG_ERR, str(e))
            self.socket = None
        return reponse

    def login(self):
        result = False
        try:
            self.recv().strip()
            self.socket.send("login sqlrelay sqlrelay\n")
            result = self.recv().strip() == 'OK'
        except Exception as e:
            syslog(LOG_ERR, str(e))
            self.socket = None
        return result

    def load_status(self):
        response = None
        try:
            self.socket.send("status\n")
            response = self.recv()
        except Exception as e:
            syslog(LOG_ERR, '%s %s' % (self.address, e))
            self.socket = None

        if response:
            status = None
            try:
                status = json.loads(response, encoding='ascii')
            except Exception as e:
                syslog(LOG_ERR, "%s [%s] %s" % (self.address, response, e))

            if status:
                self.a_lock.acquire()
                self.status = status
                self.a_lock.release()
                if self.listener:
                    self.listener.on_status(self)

    def load_configuration(self):
        ''' lecture du fichier sqlrelay.conf
            recuperation du ora_sid
        '''
        self.socket.send("conf\n")
        response = self.recv()
        self.configuration = Configuration()
        self.configuration.loads(response)
        self.create_link_tns()
        if self.listener:
            self.listener.on_configuration(self)

    def create_link_tns(self):
        self.link_tns = {}
        for instance in self.configuration.instances.itervalues():
            tnsname = instance['database_connection']['string']['oracle_sid'].upper()
            if tnsname in self.tnsnames.tns:
                if tnsname in self.link_tns:
                    self.link_tns[tnsname].append(instance['id'])
                else:
                    self.link_tns[tnsname] = [instance['id']]
                ora_node = self.tns_nodes[tnsname]
                if not ora_node in self.ora_nodes:
                    self.ora_nodes[ora_node] = [instance['id']]
                else:
                    self.ora_nodes[ora_node].append(instance['id'])
            else:
                syslog(LOG_ERR, "%s ERROR oracle_sid : %s %s" % (self.address, instance['id'], tnsname))
                if tnsname in self.link_tns:
                    self.link_tns[tnsname].append(instance['id'])
                else:
                    self.link_tns[tnsname] = [instance['id']]
                ora_node = '(None)'
                self.tns_nodes[tnsname] = ora_node
                if not ora_node in self.ora_nodes:
                    self.ora_nodes[ora_node] = [instance['id']]
                else:
                    self.ora_nodes[ora_node].append(instance['id'])

    def load_tnsnames(self):
        self.socket.send("tns\n")
        response = self.recv()
        self.tnsnames = TnsNames()
        self.tnsnames.loads(response)
        for tns_name, tns in self.tnsnames.tns.iteritems():
            names = []
            for desclist in tns.description_list:
                for desc in desclist['descriptions']:
                    if 'instance_name' in desc.connect_data:
                        names.append(desc.connect_data['instance_name'])
                    elif 'sid' in desc.connect_data:
                        names.append(desc.connect_data['sid'])
                    elif 'service_name' in desc.connect_data:
                        names.append(desc.connect_data['service_name'])
            if names:
                name = ','.join(names)
                self.tns_nodes[tns_name] = name
#                if not name in self.ora_nodes:
#                    self.ora_nodes[name] = []
        if self.listener:
            self.listener.on_tnsnames(self)

    def run(self):
        self.running = True
        count = 0
        while self.running:
            if self.socket:
                self.load_status()
            else:
                if self.connect():
                    count += 1
                    syslog(LOG_INFO,
                           "%s connnected (%d)" % (self.address, count))
                    if self.login():
                        if not self.tnsnames:
                            self.load_tnsnames()
                        if not self.configuration:
                            self.load_configuration()
                        self.load_status()
            time.sleep(self.delay)
        self.close()
        syslog(LOG_INFO, '%s end' % self.address)

    def stop(self):
        self.running = False
        self.close()

    def get_status(self):
        self.a_lock.acquire()
        try:
            result = self.status
        finally:
            self.a_lock.release()
        return result

    def get_configuration(self):
        return self.configuration.instances

    def get_tnsnames(self):
        return self.tnsnames.data
