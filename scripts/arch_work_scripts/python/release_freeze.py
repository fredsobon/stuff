#!/usr/bin/env python

# This programm use Bamboo rest api
# it enable or disable all the prod plan
#

import requests
import argparse
import sys
import json
import getpass
import logging

# parse the args
parser = argparse.ArgumentParser()
parser.add_argument('--user', action='store', dest='user',
                            help='bamboo username')
parser.add_argument('action', choices=('block', 'unblock'), action='store',
        help='action you want to perform')
parser.add_argument('-v', '--verbose', action="store_const", dest="loglevel", const=logging.DEBUG, default=logging.INFO,
         help="Increase verbosity")

# init vars and get it from args
inputargs = parser.parse_args()
user = inputargs.user
action = inputargs.action
password = getpass.getpass('Password:')
# init counters for stats
allPlansCount = blockedPlansCount = activePlansCount = inactivePlansCount = unblockedPlansCount = 0

logging.basicConfig(level=inputargs.loglevel)
logging.debug('DEBUG mode')
logging.getLogger("requests").setLevel(logging.WARNING)

# login to bamboo using basic auth
server = 'https://lapin
url = server + '/server?os_authType=basic'
headers = {
    'Accept': 'application/json'
          }

login = requests.get(url, headers = headers, auth = (user, password))
# now we are logged in and have a cookie

# fetch all the Bamboo plans
url = server + '/plan?max-results=250'
r = requests.get(url, headers = headers, cookies = login.cookies)
plans = r.json()
        
logging.info('action wanted is: ' + action)

for plan in plans['plans']['plan']:
    allPlansCount += 1
    logging.info("\n" + plan['key'])
    url = server + '/plan/' + plan['key']
    r = requests.get(url, headers = headers, cookies = login.cookies)
    planDetails = r.json()
    planStatus = planDetails['enabled']
    # BLOCKing mode
    if action == 'block':
        # we skip the already disabled plans
        if planStatus is True:
            activePlansCount += 1
            logging.debug('This plan is ENABLED, determining if we should block it')
            url = server + '/plan/' + plan['key'] + '/label'
            r = requests.get(url, headers = headers, cookies = login.cookies)
            planLabels = r.json()
            if any(label['name'] in ('prod', 'production') for label in planLabels['labels']['label']):
                logging.debug('This plan is PRODUCTION, we must block it')
                r = requests.post(url, headers = { 'Content-type': 'application/json' }, data = '"blocked"', cookies = login.cookies)
                logging.debug('added "blocked" label')
                url = server + '/plan/' + plan['key'] + '/enable'
                r = requests.delete(url, headers = headers, cookies = login.cookies)
                logging.info('plan status is now: DISABLED')
                blockedPlansCount += 1
            else:
                logging.debug('this plan is NOT production')
                logging.info('nothing done')
        else:
            logging.debug('this plan is already DISABLED')
            logging.info('nothing done')
    # UNBLOCK mode
    if action == 'unblock':
        if planStatus is False:
            inactivePlansCount += 1
            logging.debug('This plan is DISABLED, determining if we should unblock it !')
            url = server + '/plan/' + plan['key'] + '/label'
            r = requests.get(url, headers = headers, cookies = login.cookies)
            planLabels = r.json()
            if  (
                    any(label['name'] in ('prod', 'production') for label in planLabels['labels']['label']) and
                    any(label['name'] == 'blocked' for label in planLabels['labels']['label'])
                ):
                logging.debug('This plan is PRODUCTION and was blocked through this script, we must unblock it !')
                url = server + '/plan/' + plan['key'] + '/label/blocked'
                r = requests.delete(url, headers = headers, cookies = login.cookies)
                logging.debug('removed "blocked" label')
                url = server + '/plan/' + plan['key'] + '/enable'
                r = requests.post(url, headers = headers, cookies = login.cookies)
                logging.info('plan status is now: ENABLED')
                unblockedPlansCount += 1
            else:
                logging.debug('this plan is NOT production NOR blocked by this script')
                logging.info('nothing done')
        else:
            logging.debug('this plan is already ENABLED')
            logging.info('nothing done')

print 'stats:'
print 'Total plans: ' + str(allPlansCount)
print 'Active plans: ' + str(activePlansCount)
print 'InActive plans: ' + str(inactivePlansCount)
print 'Blocked plans: ' + str(blockedPlansCount)
print 'UnBlocked Plans plans: ' + str (unblockedPlansCount)
                
sys.exit(0)
