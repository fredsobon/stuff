# -*- coding: utf-8 -*-
'''
Created on 29 oct. 2012

@author: jmmasson
'''

import xml.dom.minidom


class Configuration:

    attribut_names = ['id', 'addresses', 'port', 'socket', 'mysql',
                      'mysqladdresses', 'mysqlport', 'mysqlsocket', 'dbase',
                      'connections', 'maxconnections', 'maxqueuelength',
                      'growby', 'ttl', 'maxsessioncount', 'endofsession',
                      'sessiontimeout', 'runasuser', 'runasgroup', 'cursors',
                      'maxcursors', 'cursors_growby', 'authtier', 'handoff',
                      'deniedips', 'allowedips', 'debug', 'maxquerysize',
                      'maxstringbindvaluelength', 'maxlobbindvaluelength',
                      'idleclienttimeout', 'maxlisteners', 'listenertimeout',
                      'reloginatstart', 'timequeriessec', 'timequeriesusec',
                      'fakeinputbindvariables', 'translatebindvariables',
                      'isolationlevel', 'ignoreselectdatabase',
                      'waitfordowndatabase']

    def __init__(self):
        self.instances = {}

    def loads(self, string):
        conf = xml.dom.minidom.parseString(string)
        for item in conf.documentElement.getElementsByTagName('instance'):
            if item.nodeType == item.ELEMENT_NODE:
                instance = {}
                self.instances[item.getAttribute('id').encode('ascii')] = instance
                for attribut, value in item.attributes.items():
                    instance[attribut.encode('ascii')] = value.encode('ascii')
                nodeUsers = item.getElementsByTagName('users')[0]
                nodeUser = nodeUsers.getElementsByTagName('user')[0]
                instance['user'] = {'name': nodeUser.getAttribute('user').encode('ascii'),
                                    'password': nodeUser.getAttribute("password").encode('ascii')}
                nodeCons = item.getElementsByTagName('connections')[0]
                nodeCon = nodeCons.getElementsByTagName('connection')[0]
                db_conn = {}
                instance['database_connection'] = db_conn
                for attribut, value in nodeCon.attributes.items():
                    if attribut == 'string':
                        params = {}
                        for fields in value.split(';'):
                            field = fields.split('=')
                            params[field[0].encode('ascii')] = field[1].encode('ascii')
                        db_conn[attribut.encode('ascii')] = params
                    else:
                        db_conn[attribut.encode('ascii')] = value.encode('ascii')
