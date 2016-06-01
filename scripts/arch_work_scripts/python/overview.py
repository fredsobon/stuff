#!/usr/bin/python
# -*- coding: UTF-8 -*-
# vim: ft=python sw=4 ts=4 et bg=dark
#
# Author: Marc Falzon <m.falzon@pixmania-group.com>
# Requirements:
# - simpleJSON
# - livestatus


import os
import sys
import pprint
import traceback
import urlparse
import livestatus
import simplejson as json

#------------------------------------------------

HOST_STATE_UP           = 0
HOST_STATE_DOWN         = 1
HOST_STATE_UNREACHABLE  = 2
SERV_STATE_OK           = 0
SERV_STATE_WARNING      = 1
SERV_STATE_CRITICAL     = 2
SERV_STATE_UNKNOWN      = 3

#------------------------------------------------

def send_legacy(res_hosts, res_services):
    problems = 0
    for res in res_hosts:
        if len(res['downtimes']) > 0:
            continue
        else:
            print('%s: *DOWN* ;' % res['name'])
            problems += 1

    for res in res_services:
        if len(res['downtimes']) > 0:
            continue
        else:
            print('%s: %s ;' % (res['host_name'], res['description']))
            problems += 1

    if problems == 0:
        print('ALLOK')

def send_json(res_hosts, res_services):
    hosts = dict()
    services = list()

    # loop over services problems
    for res in res_services:
        # workaround for bug in module livestatus
        if res.keys() == res.values():
            continue

        if res['host_name'] not in hosts:
            hosts[res['host_name']] = dict()
            hosts[res['host_name']]['state'] = res['host_state']
            hosts[res['host_name']]['timestamp'] = 0
            hosts[res['host_name']]['services'] = dict()

        # assign to host the timestamp of the most recent of its services problems
        if res['last_state_change'] > hosts[res['host_name']]['timestamp']:
            hosts[res['host_name']]['timestamp'] = res['last_state_change']

        # if services has downtimes, set its state to 'acknowledged'
        if len(res['downtimes_with_info']) > 0:
            hosts[res['host_name']]['services'][res['description']] = [
                4,
                '%s: %s' % (res['downtimes_with_info'][0][1], res['downtimes_with_info'][0][2]),
                res['last_state_change'],
            ]
        else:
            hosts[res['host_name']]['services'][res['description']] = [
                res['state'],
                res['plugin_output'].partition('!')[0],
                res['last_state_change'],
            ]

        # append service to services list if not yet
        if res['description'] not in services and res['host_state'] == HOST_STATE_UP:
            services.append(res['description'])

    # loop over hosts problems
    for res in res_hosts:

        # workaround for bug in module livestatus
        if res.keys() == res.values():
            continue

        if not res['name'] in hosts.keys():
            hosts[res['name']] = dict()

        hosts[res['name']]['timestamp'] = res['last_state_change']

        # if host has downtimes, set state to 'acknowledged'
        if len(res['downtimes']) > 0:
            hosts[res['name']]['state'] = 3
        else:
            hosts[res['name']]['state'] = res['state']

    # sort hosts by timestamp
    hosts_sorted = list()
    for i in sorted(hosts, key=lambda x: hosts[x]['timestamp'], reverse=True):
        host = hosts[i]
        host['hostname'] = i
        hosts_sorted.append(host)

    print(json.dumps({
        'services': services,
        'hosts': hosts_sorted,
    }))

def main():
    qs = urlparse.parse_qs(os.environ['QUERY_STRING'])
    sites = {
        'legacy' : {
          'socket'     : 'tcp:mon-00.infra.aga.e-merchant.com:6557',
          'alias'      : 'legacy',
        },
        'NG' : {
          'socket'     : 'unix:/var/run/nagios3/livestatus.sock',
          'alias'      : 'NG',
        },
    }

    if 'display' in qs.keys() and qs['display'][0] == 'legacy': 
        ls = livestatus.SingleSiteConnection('unix:/var/run/nagios3/livestatus.sock')
        res_hosts = ls.query_table_assoc('''GET hosts
Columns: name state downtimes
Filter: state_type > 0
Filter: groups < nopage
Filter: state > %d' ''' % HOST_STATE_UP)

        res_services = ls.query_table_assoc('''GET services
Columns: host_name description state downtimes
Filter: state_type > 0
Filter: state > %d
Filter: groups < nopage
Filter: host_hard_state = %d''' % (SERV_STATE_WARNING, HOST_STATE_UP))

        print('Content-Type: text/plain\n')
        send_legacy(res_hosts, res_services)
    else:
        REQ_HOSTS = '''GET hosts
Columns: host_name state last_state_change downtimes
Filter: state_type > 0
Filter: state > %d''' % HOST_STATE_UP

        REQ_SERVICES = '''GET services
Columns: host_name host_state state description downtimes_with_info last_state_change plugin_output
Filter: state_type > 0
Filter: host_hard_state = %d
Filter: state > %d''' % (HOST_STATE_UP, SERV_STATE_OK)

        if 'noack' in qs.keys() and qs['noack'][0] == 'true': 
            REQ_HOSTS += '\nFilter: host_scheduled_downtime_depth = 0'
            REQ_SERVICES += '\nFilter: scheduled_downtime_depth = 0\nFilter: host_scheduled_downtime_depth = 0'

        ls = livestatus.MultiSiteConnection(sites)
        res_hosts = ls.query_table_assoc(REQ_HOSTS)
        res_services = ls.query_table_assoc(REQ_SERVICES)

        print('Content-Type: application/json\n')
        send_json(res_hosts, res_services)

if __name__ == '__main__':
    try:
        main()
    except:
        traceback.print_exc(file=open('/tmp/overview-errors.log', 'w'))
        sys.exit(1)

