#!/bin/bash

## check in order to ensure than munin retrieve all data from client under 60 seconds and warn if it's not the case in HO

# var : 
parsed_file="$1"
target_file=$(/bin/mktemp  "${1}.XXXXXXXX")
# funct : 

function details (){  
	 grep -Ei "\([1-9]{3}\... sec\)|\(6.\... sec\)" $target_file |sort 
}

function summary() { 
 grep -Ei "\([1-9]{3}\... sec\)|\(6.\... sec\)" $target_file |awk '{print $1}' |sort -u
}
awk -F ";" '{ print $2 , $3}' $parsed_file > $target_file

#--------

#details
#summary

# data presentation : 
	
echo -n " choose the output between : details or summary "
read ans 

case "$ans" in 
	details) details
	;;
	summary) summary
	;;
	*) echo " plz enter your choice : details or summary"
esac
 

# clean :

rm "$target_file"   

















