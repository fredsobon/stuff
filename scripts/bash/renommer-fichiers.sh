#! /bin/sh


if [ $# -lt 3 ]
then
	echo "usage: $0 <chaine_orginale> <chaine_remplacement> fichiers..." >&2
	exit 1
fi

origine="$1"
shift
remplacement="$1"
shift

for fic in "$@"
do
	new=$(echo "$fic" | sed -e 's/'${origine}'/'${remplacement}'/g')
	if [ "$fic" != "$new" ]
	then
		mv "$fic" "$new"
	fi
done

