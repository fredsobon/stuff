#!/bin/bash

## this script aims to do some test in order to ensure unicity of records in "/etc/hosts" file record.

cat /etc/hosts |grep -viE "^#|test|:|eof|\[temp]|temporairesi|spare" |tr '\t' ' ' |tr ' ' '\n' |sed '/^$/d' |sort -g |uniq -c |grep -Ev "      1" |sort -rn

