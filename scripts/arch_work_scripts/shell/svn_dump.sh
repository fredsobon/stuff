#!/bin/sh

SVN_BASE="/srv/svn"

while read repo path
do
	name="${repo}$(echo $path | tr / _)"
	file="/tmp/$name.dump"
	log="/tmp/$name.log"

	svnadmin dump $SVN_BASE/$repo | svndumpfilter include --drop-empty-revs --renumber-revs $path > $file 2>$log
done
