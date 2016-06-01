#!/usr/bin/python

import os, sys, socket, re

host = os.environ['HM_SRV_IPADDR']
port = int(os.environ['HM_SRV_PORT'])
#send_string = sys.argv[1]
#receive_string = sys.argv[2]
send_string = '\x00\x00\x00\x0bsupervision\x00\x00\x00\x08xiHoogu0'
receive_string = '^\x00\x01\x00\x00$'

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    #s.settimeout(5)
    s.connect((host, port))
    s.send(send_string)
    response = s.recv(4096)
except OSError as e:
    sys.exit(-1)

if(re.search(r"%s" % receive_string, response) != None):
    sys.exit(0)
else:
    sys.exit(1)
