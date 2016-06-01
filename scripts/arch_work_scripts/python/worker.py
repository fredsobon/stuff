#! /usr/bin/python
# -*- coding: utf-8 -*-
'''
Created on 18 oct. 2012

@author: jmmasson
'''

import sys
import getopt
import ConfigParser
import os.path
import socket
import json
import signal
from syslog import syslog, LOG_ERR, LOG_INFO
from environment import Environment

BUFSIZE = 1024
CONFIGFILE = '/etc/overview/overview.conf'


class Worker():
    ''' worker '''
    def __init__(self, configfile=CONFIGFILE):
        self.configuration = None
        self.environments = {}
        self.running = False
        parser = ConfigParser.ConfigParser()
        parser.read([configfile])
        self.filename = parser.get('sqlrelay', 'servers')
        self.socketfile = parser.get('sqlrelay', 'socket')

    def load_configuration(self):
        ''' load '''
        self.configuration = json.load(open(self.filename, 'r'))
        self.environments = {}
        for conf_env in self.configuration["environment"]:
            if 'name' in conf_env:
                environment = Environment(conf_env)
                self.environments[environment.name] = environment

    def get_configuration(self):
        ''' get configuration '''
        return self.configuration

    def get_environment(self, name):
        if name in self.environments:
            return self.environments[name]
        else:
            return None

    def run(self):
        ''' start '''
        syslog(LOG_INFO, "worker sqlrelay starting...")
        try:
            signal.signal(signal.SIGINT, self.handler)
            signal.signal(signal.SIGTERM, self.handler)
            self.load_configuration()
            if not self.running:
                self.running = True
                for environment in self.environments.itervalues():
                    environment.start()
            self.listen()
        except Exception as interrupt:
            syslog(LOG_ERR, "error %s" % str(interrupt))

    def handler(self, signum, frame):
        ''' handler '''
        syslog(LOG_INFO, "worker sqlrelay stoping...")
        self.close()

    def listen(self):
        ''' start listener '''
        syslog(LOG_INFO, "worker sqlrelay listner starting...")
        if os.path.exists(self.socketfile):
            os.unlink(self.socketfile)
        soc = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        soc.bind(self.socketfile)
        soc.listen(0)
        while self.running:
            try:
                client, unused = soc.accept()
                query = client.recv(BUFSIZE)
                environment = None
                server = None
                fields = query.split()
                if len(fields) > 1:
                    environment = self.get_environment(fields[1])
                if len(fields) > 2 and environment:
                    server = environment.get_server(fields[2])
                if fields[0] == 'configuration':
                    if server:
                        response = server.get_configuration()
                    else:
                        response = self.get_configuration()
                elif fields[0] == 'tnsnames' and server:
                        response = server.get_tnsnames()
                elif fields[0] == 'status':
                    if server:
                        response = server.get_status()
                    elif environment:
                        response = environment.get_status()
                    else:
                        response = {'error': 'parameters invalid'}
                else:
                    response = {'error': 'command invalid'}
                client.send(json.dumps(response))
                client.close()
            except Exception as interrupt:
                syslog(LOG_ERR, "error %s" % str(interrupt))

    def close(self):
        ''' close '''
        self.running = False
        os.unlink(self.socketfile)
        for environment in self.environments.itervalues():
            environment.stop()
        syslog(LOG_INFO, "worker sqlrelay finished")


def main(argv):
    ''' main '''
    configfile = CONFIGFILE
    try:
        opts, args = getopt.getopt(argv, "c", ["config"])
    except getopt.GetoptError as err:
        print str(err)
        sys.exit(2)
    for opt, arg in opts:
        if opt in ("-c", "--config"):
            configfile = arg
    daemon = Worker(configfile)
    daemon.run()


if __name__ == "__main__":
    main(sys.argv[1:])
