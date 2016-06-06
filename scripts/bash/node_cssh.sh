#!/bin/sh

CSSH="clusterssh"
arg="$*"
search_file="/etc/hosts"
for pattern in $@
do
	hosts=$( grep -Ei "${arg}" "${search_file}" |grep  ".frontend" |grep -v "old" |awk '{print $2}')
done
	hosts=$(echo "${hosts}" |sed -n 's/.frontend//p')
if [ -n "$hosts" ]
then

	echo "Hosts:"
	echo $hosts

	count=$(echo $hosts|sed 's/ /\n/g'|wc -l)

	echo -n "\n$count host(s), let's go ? (y/N): "
	read ok

	if echo "$ok" | grep -qi ^y
	then
		$CSSH $hosts &
	fi
else
	echo "No matching hosts"
fi
