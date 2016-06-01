#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''
A script to generate the tnsnames.ora file for OCI and SQLRelay
Last Update by Maxime Guillet - Wed, 06 Nov 2013 05:33:09 +0100
'''

import os
import sys
import yaml


TMPL_LEGACY = '''
{alias} = (DESCRIPTION_LIST =
    (DESCRIPTION =(FAILOVER=ON)(LOAD_BALANCE=YES)(ADDRESS =(PROTOCOL = TCP)(HOST = {addresses[0]})(PORT = {ports[0]}))(CONNECT_DATA =(SERVICE_NAME= {service})(INSTANCE_NAME = {instances[0]})))
    (DESCRIPTION =(FAILOVER=ON)(LOAD_BALANCE=YES)(ADDRESS =(PROTOCOL = TCP)(HOST = {addresses[1]})(PORT = {ports[1]}))(CONNECT_DATA =(SERVICE_NAME= {service})(INSTANCE_NAME = {instances[1]})))
)
'''

TMPL_DG = '''
{alias} =
    (DESCRIPTION=(ADDRESS_LIST=(FAILOVER=on)(LOAD_BALANCE=off)
    (ADDRESS=(PROTOCOL=TCP)(HOST= {hostname}.db.core.prod.{primary-site}.e-merchant.net)(PORT= {port}))
    (ADDRESS=(PROTOCOL=TCP)(HOST= {hostname}.db.core.prod.{secondary-site}.e-merchant.net)(PORT= {port})))
    (CONNECT_DATA=(SERVICE_NAME= {service}))
)
'''

TMPL_MAA = '''
{alias} =
(DESCRIPTION=
    (ADDRESS=(PROTOCOL=TCP)(HOST=scan01-{maa}.db.core.prod.{site}.e-merchant.net)(PORT={port}))
    (ADDRESS=(PROTOCOL=TCP)(HOST=scan02-{maa}.db.core.prod.{site}.e-merchant.net)(PORT={port}))
    (ADDRESS=(PROTOCOL=TCP)(HOST=scan03-{maa}.db.core.prod.{site}.e-merchant.net)(PORT={port}))
    (LOAD_BALANCE = YES)(FAILOVER=ON)(CONNECT_TIMEOUT=1)
    (CONNECT_DATA=
        (SERVER=DEDICATED)
        (SERVICE_NAME= {service})
        (FAILOVER_MODE =
            (TYPE = SELECT)
            (METHOD = BASIC)
            (RETRIES = 3)
            (DELAY = 2)
        )
    )
)
'''

TMPL_STANDALONE = '''
{alias} =
(DESCRIPTION=
    (ADDRESS=(PROTOCOL=TCP)(HOST= {hostname}.db.core.prod.{primary-site}.e-merchant.net)(PORT={port}))
    (CONNECT_DATA=
        (SERVER=DEDICATED)
        (SERVICE_NAME= {service})
    )
)
'''

TMPL_DG_SBT = '''
{alias} =
    (DESCRIPTION=(ADDRESS_LIST=(FAILOVER=on)(LOAD_BALANCE=off)
    (ADDRESS=(PROTOCOL=TCP)(HOST= {primary-hostname}.db.core.prod.{primary-site}.e-merchant.net)(PORT= {port}))
    (ADDRESS=(PROTOCOL=TCP)(HOST= {secondary-hostname}.db.core.prod.{secondary-site}.e-merchant.net)(PORT= {port})))
    (CONNECT_DATA=(SERVICE_NAME= {service}))
)
'''

TMPL_ERAC_12 = '''
{alias} =
    (DESCRIPTION=(ADDRESS_LIST=(FAILOVER=on)(LOAD_BALANCE=off)
    (ADDRESS=(PROTOCOL=TCP)(HOST= vip00-scan-{erac}.db.core.prod.e-merchant.net)(PORT= {port}))
    (CONNECT_DATA=
        (SERVER=DEDICATED)
        (SERVICE_NAME= {service})
    )
)
'''

TMPL_ERAC_10 = '''
{alias} =
(DESCRIPTION=
    (ADDRESS=(PROTOCOL=TCP)(HOST=scan01-{erac}.db.core.prod.e-merchant.net)(PORT={port}))
    (ADDRESS=(PROTOCOL=TCP)(HOST=scan02-{erac}.db.core.prod.e-merchant.net)(PORT={port}))
    (ADDRESS=(PROTOCOL=TCP)(HOST=scan03-{erac}.db.core.prod.e-merchant.net)(PORT={port}))
    (LOAD_BALANCE = YES)(FAILOVER=ON)(CONNECT_TIMEOUT=1)
    (CONNECT_DATA=
        (SERVER=DEDICATED)
        (SERVICE_NAME= {service})
        (FAILOVER_MODE =
            (TYPE = SELECT)
            (METHOD = BASIC)
            (RETRIES = 3)
            (DELAY = 2)
        )
    )
)
'''


TNSNAMES_FILE = 'tnsnames.ora'

if '__main__' == __name__:
    YAML = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'tnsnames.yaml')

    try:
        fhandle = open(YAML, 'r')
        conf = yaml.load(fhandle)
        fhandle.close()

        maa_config = conf['maa_config']
        db_config = conf['db_config']
        alias_config = conf['alias_config']
    except IOError, e:
        print('error: unable to load configuration file (%s)' % e)
        sys.exit(1)

    db_template = {}

    for db in db_config:
        if db_config[db]['arch'] == 'legacy':
            instances = list()
            addresses = list()
            ports = list()
            for instance in sorted(db_config[db]['instances']):
                instances.append(instance)
                addresses.append(db_config[db]['instances'][instance]['address'])
                ports.append(db_config[db]['instances'][instance]['port'])

            db_template[db] = {
                'template': TMPL_LEGACY,
                'format': {
                    'addresses': addresses,
                    'ports': ports,
                    'instances': instances,
                }
            }
        elif db_config[db]['arch'] == 'dataguard':
            db_template[db] = {
                'template': TMPL_DG,
                'format': {
                    'hostname': db_config[db]['hostname'],
                    'port': db_config[db]['port'],
                    'primary-site': db_config[db]['primary-site'],
                    'secondary-site': db_config[db]['secondary-site'],
                }
            }
        elif db_config[db]['arch'] == 'dg_sbt':
            db_template[db] = {
                'template': TMPL_DG_SBT,
                'format': {
                    'primary-hostname': db_config[db]['primary-hostname'],
					'secondary-hostname': db_config[db]['secondary-hostname'],
                    'port': db_config[db]['port'],
                    'primary-site': db_config[db]['primary-site'],
                    'secondary-site': db_config[db]['secondary-site'],
                }
            }			
        elif db_config[db]['arch'].startswith('maa'):

            db_template[db] = {
                'template': TMPL_MAA,
                'format': {
                    'maa': db_config[db]['arch'],
                    'site': db_config[db]['site'],
                    'port': maa_config[db_config[db]['arch']]['port'],
                }
            }
        elif db_config[db]['arch'] == 'standalone':
            db_template[db] = {
                'template': TMPL_STANDALONE,
                'format': {
                    'hostname': db_config[db]['hostname'],
                    'port': db_config[db]['port'],
                    'primary-site': db_config[db]['primary-site']
                }
            }
        elif db_config[db]['arch'] == 'extended_rac_10':
            db_template[db] = {
                'template': TMPL_ERAC_10,
                'format': {
                    'erac': db_config[db]['erac'],
                    'port': db_config[db]['port']
                }
            }
        elif db_config[db]['arch'] == 'extended_rac_12':
            db_template[db] = {
                'template': TMPL_ERAC_12,
                'format': {
                    'erac': db_config[db]['erac'],
                    'port': db_config[db]['port']
                }
            }

    tns_handle = open(TNSNAMES_FILE, 'wb')

    for alias in sorted(alias_config):
        formatting = db_template[alias_config[alias]['base']]['format'].copy()
        formatting.update(alias=alias, service=alias_config[alias]['service_name'])
        tns_handle.write(db_template[alias_config[alias]['base']]['template'].format(**formatting).replace('\r\n', '\n'))
        del(formatting)

    tns_handle.close()

# vim: ts=4 sw=4 et
