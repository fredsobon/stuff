#!/bin/bash
node="$1"
record_file="/home/boogie/Documents/work/work_doc/inventory/.csv"
grep -iE $node $record_file |awk -F"," '{print $9,"Location=>",$1 ,"=rack number=>",$4,"= rack position =>",$5,"= serial number =>" , $12 }'
