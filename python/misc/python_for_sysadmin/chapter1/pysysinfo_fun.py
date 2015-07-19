#!/usr/bin/env python

# A system information gathering script
import subprocess

# command 1 

def kern():
    uname="uname"
    uname_arg="-a"
    print("Gathering information with %s command: \n")  % uname
    subprocess.call([uname,uname_arg])

 
# command 2 
def space():
    diskusage="df"
    disk_arg="-h"
    print("Get diskspace in human style with %s command: \n") %diskusage
    subprocess.call([diskusage,disk_arg])

# exactly possible to write calls like this :
#subprocess.call("df -h", shell=True)


def main():
    space()
    kern()

main()
