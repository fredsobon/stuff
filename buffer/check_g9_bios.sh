#!/usr/bin/env bash

# main goal : retrieve cpu performance settings on "ProLiant Gen 9" servers  : this requires the uses of conrep (which belongs to hp-scripting-tools package )

### Adding more directory to PATH
PATH=$PATH:/opt/puppetlabs/bin

## var : 

## check mandatory tool presence : facter  

if [ ! -x "$(which facter)" ];then
  echo "The tool < facter > seems not to be available. Please check" && exit 3
fi

# main test : to be processed only on g9 servers : 

# testif gen9
facter productname | grep "Gen9" >/dev/null 2>&1
if [ $? -ne 0 ];then
 echo "this server is not a Gen9" &&  exit 3
fi

## check mandatory tool presence :  conrep 
    
if [ ! -x "$(which conrep)" ];then
  echo "The tool < conrep > seems not to be available. Please check" && exit 3
fi

# bios info to be retrieved : 
conrep -s -f - | grep -iq "Maximum performance"
if [ $? -ne 0 ] ; then
    echo "< Maximum performance > bios setting is not configured on this server please check " && exit 2
else
    echo "ALLOK" && exit 0
fi

