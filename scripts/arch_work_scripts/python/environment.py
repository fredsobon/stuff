# -*- coding: utf-8 -*-
'''
Created on 18 oct. 2012

@author: jmmasson
'''

import thread
from server import Server


class Environment:
    ''' environment '''
    def __init__(self, configuration):
        self.name = configuration["name"]
        self.servers = {}
        self.ora_nodes = {}
        self.status = []
        for address in configuration["servers"]:
            address = address.encode('ascii')
            self.servers[address] = Server(address, listener=self)
        self.a_lock = thread.allocate_lock()

    def start(self):
        ''' start '''
        for server in self.servers.itervalues():
            server.start()

    def stop(self):
        ''' stop '''
        for server in self.servers.itervalues():
            server.stop()

    def intialize(self, server):
        for name, nodes in server.ora_nodes.iteritems():
            if name in self.ora_nodes:
                ora_node = self.ora_nodes[name]
            else:
                ora_node = {}
                self.ora_nodes[name] = ora_node
                self.status.append({'name': name,
                                    'nodes': []})
            for instance in nodes:
                if not instance in ora_node:
                    ora_node[instance] = {}
                ora_node[instance][server.address] = {}

    def on_tnsnames(self, server):
        self.a_lock.acquire()
        try:
            self.intialize(server)
        finally:
            self.a_lock.release()

    def on_configuration(self, server):
        self.a_lock.acquire()
        try:
            self.intialize(server)
        finally:
            self.a_lock.release()

    def on_status(self, server):
        self.a_lock.acquire()
        try:
            for instance_name, status in server.status.iteritems():
                if instance_name == 'time':
                    continue
                tns_name = server.configuration.instances[instance_name]['database_connection']['string']['oracle_sid'].upper()
                ora_name = server.tns_nodes[tns_name]
                self.ora_nodes[ora_name][instance_name][server.address] = status
        except Exception as e:
            print e
            print instance_name
        finally:
            self.a_lock.release()

    def get_server(self, name):
        if name in self.servers:
            return self.servers[name]
        else:
            return None

    def get_status(self):
        self.a_lock.acquire()
        try:
#            status = []
#            for ora_name, ora_nodes  in self.ora_nodes.iteritems():
#                nodes = []
#                status.append({"name": ora_name,
#                               "instances": nodes})
#                for instance_name, instance in ora_nodes.iteritems():
#                    servers = []
#                    nodes.append({"name": instance_name,
#                                  "servers": servers})
#                    for server in instance.iteritems():
#                        servers.append({"name": server,
#                                        "attributes": []})
            status = self.ora_nodes
        except Exception as e:
            print e
        finally:
            self.a_lock.release()
#        return { "status": status }
        return status
