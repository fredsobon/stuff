#!/bin/bash


while [ $1 ] 
do
echo "\$1 is ==> $1 "

	if test -f node"$1" 
	then 
        	echo "ho ..no way the file node$1 already exists ...gonna quit!!"
	shift
		continue
	fi


echo "$1 can be processed ....lets do it!" 
echo "after shift \$1 is $1"
touch node"$1" 
shift 1
 
done
	
