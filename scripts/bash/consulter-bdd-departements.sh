#! /bin/sh

if [ $# -ne 2 ]
then
	echo "usage: $0 fichier.sql numero" >&2
	exit 1
fi
sqlite3 -line "$1" <<-EOF
	select * from depts where numero="$2";
EOF

