#! /bin/sh

for i in "$@"
do
	echo "$i"
	cat -n "$i" | expand -t2 | sed 's/^   //'
done
