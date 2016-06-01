#!/bin/sh
# Maxime Guillet - Wed, 19 Mar 2014 17:02:36 +0100


[ "$1" = '--now' ] || sleep $(perl -e 'print int(rand(30));')m

for prj_path in /opt/pertimm/projects/* ; do
	prj=$(basename $prj_path)

	[ $(ls ${prj_path}/indexes 2>/dev/null | wc -l) -eq 0 ] && continue

	curl -s -X POST -d '{"name":"consolidate_index"}' --basic -u "emerchant@support.pertimm.com:ij54qs91" http://localhost:8080/${prj}/qws/jobs.json >/dev/null
	sleep 120
done
