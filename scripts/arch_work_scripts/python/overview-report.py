#!/usr/bin/env python

import getopt
import httplib
import json
import os
import pickle
import re
import sys


OVERVIEW_HOST = 'overview.e-merchant.net'

DATA_DIR = '/tmp'

REPLACE_RULES = (
    (r'(NAF .+ - .+: )Used\ .+', '\1Disk usage'),
    (r'((?:LOAD - )?SNMP .+ - )\*[0-9\.]+\* [0-9\.]+ [0-9\.]+', '\1Load average'),
    (r'(DF - SNMP .+ - )\*[0-9\.]+\* Disk usage.+', '\1Disk usage'),
)


def print_usage():
    print('''Usage: %s [OPTIONS]

Options:
   -f  force display
   -h  display this help and exit
   -i  search for specific groups (can be used multiple times)
   -c  set a cache file value
   -x  exclude specific groups (can be used multiple times)''' % os.path.basename(sys.argv[0]))


# Parse for command-line arguments
opt_force = False
opt_cache = ''
opt_exclude = []
opt_include = []

try:
    opts, args = getopt.gnu_getopt(sys.argv[1:], 'c:fhi:x:')

    for opt, arg in opts:
        if opt == '-f':
            opt_force = True
        elif opt == '-h':
            print_usage()
            sys.exit(0)
        elif opt == '-c':
            opt_cache = arg
        elif opt == '-i':
            opt_include.append(arg)
        elif opt == '-x':
            opt_exclude.append(arg)
except Exception as e:
    sys.stderr.write('Error: %s\n' % e)
    print_usage()
    sys.exit(1)

# Initialize states
state = set()
state_filepath = os.path.join(
    DATA_DIR,
    os.path.basename(sys.argv[0]) + '-' + opt_cache + '.cache'
)

if os.path.exists(state_filepath):
    last = pickle.load(open(state_filepath, 'rb'))
else:
    last = set()

# Get list of current issues
data = {
    'group': { 'exclude': ['nopage']},
    'state': [2, 3],
}

if opt_include:
    data['group']['include'] = opt_include

if opt_exclude:
    data['group']['exclude'] = opt_exclude

http = httplib.HTTPConnection(OVERVIEW_HOST)

http.request('POST', '/nagios/search', json.dumps(data), {
    'Content-Type': 'application/json'
})

response = http.getresponse()

if response.status != 200:
    sys.stderr.write('Error: unable to fetch data\n')

for entry in json.loads(response.read()).get('hosts', []):
    if 'nopage' in entry.get('groups'):
        continue

    if entry.get('state') > 0:
        state.add((entry.get('hostname'), 'STATE', 'DOWN'))

    for service_name, service in entry.get('services', {}).iteritems():
        if 'nopage' in service.get('groups'):
            continue

        output = service.get('output')

        for pattern, replacement in REPLACE_RULES:
            regexp = re.compile(pattern, re.I)

            output, count = regexp.subn(replacement, output)

            if count > 0:
                break

        state.add((entry.get('hostname'), service_name, output))

# Print changes output
if opt_force:
    if len(state) > 0:
        for entry in state:
            sys.stdout.write('%s: %s - %s\n' % entry)
    else:
        sys.stdout.write('ALL OK\n')
elif len(state) > 0:
    for entry in (state - last):
        sys.stdout.write('%s: %s - %s\n' % entry)
elif len(last) > 0:
    sys.stdout.write('ALL OK\n')

# Save state
pickle.dump(state, open(state_filepath, 'wb'), pickle.HIGHEST_PROTOCOL)
