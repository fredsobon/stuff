#!/usr/bin/python -u
# -*- coding: utf8 -*-
'''
Created on 6 oct. 2011

Last update : 21 10 2013
- add check uptime
Last update : 17 10 2013
- cache_ttl 15 secondes
- remove Ping

@author: jmmasson
'''

import sys
import time
import signal
from subprocess import Popen, PIPE
from json import loads

oid_base = '.1.3.6.1.4.1.38673.1.2'
cache_ttl = 15.0            # secondes

ATTR_NAME = 0               # nom de l'instance
ATTR_STATUS = 1             # status : charge de l'instance de 0 a 100 %
ATTR_SESSIONS = 2           # compteur de sessions
ATTR_CONNECTIONS = 3        # compteur de connections db
ATTR_LISTENERS = 4          # nombre de clients en file d'attente
ATTR_QUERIES = 5            # compteur de requetes
ATTR_ERRORS = 6             # compteur d'erreurs
ATTR_OPEN_SESSIONS = 7      # sessions actuellement ouverte
ATTR_OPEN_CONNECTIONS = 8   # connections actuellement ouverte

ATTR_COUNT = 9

# SQLRelay STATUS
INSTANCE_PORT = 0
INSTANCE_STATUS = 1
INSTANCE_UPTIME = 2
INSTANCE_SESSIONS = 4
INSTANCE_CONNECTIONS_LOADED = 6
INSTANCE_CONNECTIONS_MAX = 8
INSTANCE_QUEUE_COUNT = 11
INSTANCE_QUEUE_MAX = 13
INSTANCE_TOTAL_SESSIONS = 14
INSTANCE_TOTAL_CONNECTIONS = 15
INSTANCE_TOTAL_QUERIES = 16
INSTANCE_TOTAL_ERRORS = 17

CONNECTION_STATE_UPTIME = 4


class Instance:

    def __init__(self, name):
        self.name = name
        self.port = 0
        self.status = False
        self.attributs = [name, 0, 0, 0, 0, 0, 0, 0, 0]

    def get_uptime(self, status):
        uptime = status[u'attributes'][INSTANCE_UPTIME]
        connections = status[u'connections']
        for connection in connections:
            if uptime > connection[CONNECTION_STATE_UPTIME]:
                uptime = connection[CONNECTION_STATE_UPTIME]
        return uptime

    def load_status(self, status):
        self.status = False
        load = 100
        try:
            attributes = status[u'attributes']
            self.port = attributes[INSTANCE_PORT]

            self.attributs[ATTR_SESSIONS] = attributes[INSTANCE_TOTAL_SESSIONS]
            self.attributs[ATTR_CONNECTIONS] = attributes[INSTANCE_TOTAL_CONNECTIONS]
            self.attributs[ATTR_QUERIES] = attributes[INSTANCE_TOTAL_QUERIES]
            self.attributs[ATTR_ERRORS] = attributes[INSTANCE_TOTAL_ERRORS]
            self.attributs[ATTR_LISTENERS] = attributes[INSTANCE_QUEUE_COUNT]
            self.attributs[ATTR_OPEN_SESSIONS] = attributes[INSTANCE_SESSIONS]
            self.attributs[ATTR_OPEN_CONNECTIONS] = attributes[INSTANCE_CONNECTIONS_LOADED]

            if u'connections' in status:
                if attributes[INSTANCE_STATUS] == u'ERROR':
                    if self.get_uptime(status) <= 10:
                        attributes[INSTANCE_STATUS] = u'WARNING'
                else:
                    if attributes[INSTANCE_QUEUE_COUNT] > 0:
                        if self.get_uptime(status) > 20:
                            attributes[INSTANCE_STATUS] = u'ERROR'
                if attributes[INSTANCE_STATUS] != u'ERROR':
                    self.status = True
                    c_max = float(attributes[INSTANCE_CONNECTIONS_MAX] + attributes[INSTANCE_QUEUE_MAX])
                    value = float(attributes[INSTANCE_SESSIONS] + attributes[INSTANCE_QUEUE_COUNT])
                    if value < c_max:
                        load = int((value / c_max) * 100.0)
                        if load == 100:
                            self.status = False
                    else:
                        load = 100
                        self.status = False
            self.attributs[ATTR_STATUS] = load
        except:
            self.status = False
            self.attributs[ATTR_STATUS] = 100


class SQLRelay:

    def __init__(self):
        self.instances = {}
        self.ports = []
        self.time = time.time() - cache_ttl-1.0

    def load_status(self):
        now = time.time()
        if now - self.time < cache_ttl:
            return
        self.time = now
        status = loads(Popen(['sudo','sqlr-status','-json'],
                             stdout=PIPE, stderr=PIPE).communicate()[0])
        instances = {}
        for name, inst_stats in status.iteritems():
            if not type(inst_stats) is int:
                if name in self.instances:
                    instance = self.instances[name]
                else:
                    instance = Instance(name)
                instance.load_status(inst_stats)
                instances[instance.port] = instance
        self.instances = instances
        self.ports = sorted(self.instances)

    def get_next_port(self, port):
        self.load_status()
        for p in self.ports:
            if p > port:
                return p
        return -1

    def get_instance(self, port):
        self.load_status()
        if port in self.instances:
            return self.instances[port]
        else:
            return None

    def execute(self, oid, attribut, port):
        instance = self.get_instance(port)
        if instance:
            if attribut < 0 or attribut >= ATTR_COUNT:
                return ['NONE']
            value = instance.attributs[attribut]
            if type(value) is int:
                return [oid, 'integer', value]
            else:
                return [oid, 'string', value]
        else:
            return ['NONE']

class TimeoutException(Exception):
    pass

def shutdown(sig, frame):
    global run
    run = False
    raise TimeoutException

if __name__ == '__main__':

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGPIPE, shutdown)

    sqlrelay = SQLRelay()
    
    run = True
    try:
        while run:
            cmd = sys.stdin.readline().strip()
            result = ['NONE']
            if cmd.startswith('PING'):
                result = ['PONG']
            else:
                if cmd == 'set':
                    oid = sys.stdin.readline().strip()
                    result = ['wrong-type']
                elif cmd == 'get':
                    oid = sys.stdin.readline().strip()
                    if oid.startswith(oid_base):
                        fields = oid[len(oid_base):].split('.')
                        if len(fields) == 3:
                            result = sqlrelay.execute(oid, 
                                                      int(fields[1]), 
                                                      int(fields[2]))
                elif cmd == 'getnext':
                    oid = sys.stdin.readline().strip()
                    if oid.startswith(oid_base):
                        attribut = 0
                        port = 0
                        fields = oid[len(oid_base):].split('.')
                        count = len(fields)
                        if count > 1 and fields[1]:
                            attribut = int(fields[1])
                        if count > 2 and fields[2]:
                            port = int(fields[2])
                        next_port = -1
                        while next_port == -1 and attribut <= ATTR_COUNT:
                            next_port = sqlrelay.get_next_port(port)
                            port = 0
                            attribut += 1
                        port = next_port
                        attribut -= 1
                        oid = '%s.%d.%d' % (oid_base, attribut, port)
                        result = sqlrelay.execute(oid, attribut, port)
            for line in result:
                print line
    except TimeoutException:
        pass
    finally:
        sys.stdin.close()
        sys.exit(0)
