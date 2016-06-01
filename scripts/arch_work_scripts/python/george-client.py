#!/usr/bin/python

import sys
from socket import *

serve_addr = ('localhost', 4242)

if __name__ == '__main__':
    sock = socket(AF_INET, SOCK_DGRAM)
    for line in sys.stdin.readlines():
        sock.sendto(line.strip(), serve_addr)
    sock.close()
