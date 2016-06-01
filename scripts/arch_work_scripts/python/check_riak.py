#!/usr/bin/env python
# -*- coding: utf-8 -*-


"""riak recuperation des valeurs depuis api
   test presence pid"""

import argparse
import json
import netsnmp
import os
import re
import time
import requests
import subprocess
import sys


STATE_OK = 0
STATE_WARN = 1
STATE_CRIT = 2
STATE_UNKN = 3

riak_actif = 0

OID = '.1.3.6.1.2.1.25.4.2.1.2'
#OID = 'HOST-RESOURCES-MIB::hrSWRunName'

valeurs = ['riak_core_stat_ts', 'goldrush_version', 'erlang_js_version',
		'riak_kv_version', 'riak_pipe_version', 'compiler_version',
		'sys_smp_support', 'cluster_info_version', 'webmachine_version',
		'sys_threads_enabled', 'basho_stats_version', 'sys_heap_type',
		'stdlib_version', 'ring_ownership', 'bitcask_version',
		'riak_core_version', 'sys_driver_version', 'sys_otp_release',
		'riak_control_version', 'ring_members', 'runtime_tools_version',
		'lager_version', 'sys_system_version', 'sasl_version',
		'kernel_version', 'connected_nodes', 'public_key_version',
		'erlydtl_version', 'riak_search_version', 'syntax_tools_version',
		'riak_api_version', 'nodename', 'merge_index_version',
		'inets_version', 'sys_system_architecture', 'ssl_version',
		'mochiweb_version', 'riak_sysmon_version', 'storage_backend'
]

snmpcmd = {}
snmpcmd['HOST'] = None
snmpcmd['Community'] = 'pixro'
#snmpcmd['secname'] = None
snmpcmd['Version'] = 2
#snmpcmd['authpassword'] = None
#snmpcmd['authprotocol'] = None
#snmpcmd['privpassword'] = None
#snmpcmd['privprotocol'] = None
#snmpcmd['port'] = 161

parser = argparse.ArgumentParser()
parser.add_argument("-H", "--HOST" , help="host target")
parser.add_argument("-v", "--verbose", help="activation verbose mode", action="store_true")
args = parser.parse_args()

if args.HOST:
		snmpcmd['HOST'] = args.HOST

def main():
	is_runninng()

	if riak_actif > 0:
		print("OK")
		exit(STATE_OK)
	else:
		print("KO")
		exit(STATE_CRIT)

	API="http://" + args.HOST + ":8098"

	if args.verbose:
		req = requests.get(url='%s/stats' % API, params={})
		statistics=json.loads(req.content)
		for metric, valeur in statistics.iteritems():
			for probe in valeurs:
				if re.match(probe, metric):
					print("%s ==> %s" % (metric, valeur))

def is_runninng():
	global riak_actif
	try:
		session = netsnmp.Session( DestHost=snmpcmd['HOST'], Version=snmpcmd['Version'],
			Community=snmpcmd['Community'], UseNumeric=1 )
		session.UseLongNames = 1
	except TypeError:
		parser.print_help()
		exit(STATE_UNKN)

	oid = netsnmp.VarList(netsnmp.Varbind(OID))
	resultat = session.walk(oid)

	for i in resultat:
		if re.search('beam.smp', i):
			riak_actif += 1

	return riak_actif

if __name__ == "__main__":
	main()
