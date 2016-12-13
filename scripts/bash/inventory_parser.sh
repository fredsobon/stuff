#!/bin/bash

usage() {
cat <<EOF
NAME
        $(basename $0) - inventory parser 

SYNOPSIS
        Usage: $(basename $0) <HOST> [<HOSTN> ....]

DESCRIPTION
        Query the csv file extracted from the original xls in order to retrieve nodes informations

        The csv file format is mandatory  this have to be exported from the original excel. (tools are available)
                                
EOF
}

[ $# -lt 1 ] && {
        echo "Missing argument."
        usage
        exit 1
}

node="$1"
record_file="*.csv"
real_path=$(readlink -f $record_file)
echo "===== File parsed :  $real_path ==="

for i in $@
do
	grep -iE $node $real_path |awk -F"," '{print tolower($9),"Location =>",$1 , "room =>" $2 , "rack_number => " $3 , "= rack_position_front =>",$4, "= rack_position_back =>",$5,"= serial number =>" , $12 , "= IL Id - colt reference => ", $10 }'

done
shift 1
