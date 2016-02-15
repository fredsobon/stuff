#!/bin/sh

multipath -ll | grep dm- | awk '{print "s/" $3 "/" $1 "/"}' > /tmp/luns.txt

exec iostat $@ | sed -f /tmp/luns.txt
