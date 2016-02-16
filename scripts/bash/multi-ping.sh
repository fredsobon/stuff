#! /bin/sh

CODE_RETOUR=0

for host in "$@"
do
	if ping -c1 -w1 "${host}" > /dev/null 2>&1
	then
		echo "${host} Ok"
	else
		echo "${host} inacessible"
		CODE_RETOUR=1
	fi
done

exit ${CODE_RETOUR}

