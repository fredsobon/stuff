#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# redirect-check.py: Check HTTP redirects
#                    by Vincent Batoufflet <vbatoufflet@e-merchant.net>
#

import csv
import os
import pycurl
import sys
import urlparse


class Response:
    def __init__(self):
        self.headers = {}

    def write(self, data):
        if ': ' in data:
            chunks = data.strip().split(': ', 1)
            self.headers[chunks[0]] = chunks[1]


# Check for command-line arguments
if len(sys.argv) != 3:
    print('''Usage: %s HOST FILE

Parameters:
   HOST  server on which tests will be ran
   FILE  path to CSV file (with comma delimiter)''' %
        os.path.basename(sys.argv[0]))

    sys.exit(1)

# Check for input file
if not os.path.exists(sys.argv[2]):
    sys.stderr.write("Error: can't find %s file\n" % sys.argv[2])
    sys.exit(1)

# Parse input file and check for redirections
fh = open(os.devnull, 'w')

for src, dst in csv.reader(open(sys.argv[2], 'r'), delimiter=','):
    url = list(urlparse.urlsplit(src))
    domain = url[1]
    url[1] = sys.argv[1]

    response = Response()

    c = pycurl.Curl()
    c.setopt(pycurl.URL, urlparse.urlunsplit(url))
    c.setopt(pycurl.HTTPHEADER, ['Host: %s' % domain])
    c.setopt(pycurl.HEADERFUNCTION, response.write)
    c.setopt(pycurl.WRITEFUNCTION, fh.write)
    c.perform()
    c.close()

    # Check differences between locations
    location = response.headers.get('Location')

    if not location or location != dst:
        print('''
URL:       %s
Reference: %s
Current:   %s''' % (src, dst, location))

fh.close()
