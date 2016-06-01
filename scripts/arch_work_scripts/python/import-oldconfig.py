#!/usr/bin/env python
# -*- coding: utf-8 -*-

import codecs
import os
import sys
import yaml

file_path = sys.argv[1]

if not os.path.exists(file_path):
    sys.exit(1)

data = yaml.load(codecs.open(file_path, 'r', 'utf-8').read())

for pool_name in sorted(data.get('services', [])):
    service_pool = {
        'services': {}
    }

    for service_name, service_entry in data['services'][pool_name].iteritems():
        service = {
            'notes': service_entry[1],
            'check_command': service_entry[0],
        }

        if len(service_entry) > 2:
            service['check_interval'] = service_entry[2]

        if len(service_entry) > 3:
            service['freshness_threshold'] = service_entry[3]

        service_pool['services'][service_name.replace(' ', '-')] = {'default': service}

    yaml.dump(service_pool, codecs.open(os.path.join(os.path.dirname(sys.argv[0]), 'resources', 'services',
        pool_name + '.yaml'), 'w', 'utf-8'), allow_unicode=True, default_flow_style=False, explicit_start=True)

for group_name in sorted(data.get('hosts', [])):
    for host_name, host_entry in data['hosts'][group_name].iteritems():
        host = {
            'services': {},
            'hostgroups': [],
        }

        for pool_name, pool_entry in host_entry.get('services', []).iteritems():
            host['services'][pool_name] = None

            if host_entry['services'][pool_name]:
                host['services'][pool_name] = None

            if pool_entry is not None:
                host['services'][pool_name] = {}

                for service_name in pool_entry:
                    host['services'][pool_name][service_name] = {
                        'default': {
                            'check_command': pool_entry[service_name]
                        }
                    }

        for group_name in host_entry.get('groups', []):
            host['hostgroups'].append(group_name)

        yaml.dump(host, codecs.open(os.path.join(os.path.dirname(sys.argv[0]), 'resources', 'rules', 'fqdn',
            host_name + '.yaml'), 'w', 'utf-8'), allow_unicode=True, default_flow_style=False, explicit_start=True)
