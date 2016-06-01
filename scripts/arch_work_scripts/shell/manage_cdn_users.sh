#!/bin/bash

DB=cdn

function logError() {
	echo "$@" >&2
	exit 1
}

function test_user() {
	user=$1
	mysql -sNB -e "SELECT user from $DB.users WHERE user='$user'"|grep -q "^$user$"
	return $?
}

function printSyntax() {
cat <<EOS
$(basename $0) - Création utilisateur CDN
	$(basename $0) insert USER PASSWORD
	$(basename $0) delete USER"
EOS
}



case "$1" in
'insert')
	[ -z "$2" ] && logError "il n'y a pas d'utilisateur de specifié"
	[ -z "$3" ] && logError "il n'y a pas de mdp de specifié"
	if ! test_user $2; then
		echo "Création de l'utilisateur $2"
		mysql -e "INSERT INTO $DB.users (user,passwd,uid,gid,home,allow_ftp,created) VALUES ('$2', PASSWORD('$3'), 5500, 5500, '/srv/cdn/${2}', 'true', NOW())"
		mkdir "/srv/cdn/${2}"
		chown 5500:5500 "/srv/cdn/${2}"
	else
		echo "L'utilisateur $2 existe deja!"
	fi
	;;

'delete')
	
	[ -z "$2" ] && logError "il n'y a pas d'utilisateur de specifié"
	if test_user $2; then
		echo "Suppression du user $2"
		mysql -e "DELETE FROM $DB.users WHERE user='$2'"
		echo "!!! /srv/cdn/${2} doit être supprimé manuellement"
	else
		echo "L'utilisateur $2 n'existe pas!"
	fi
	;;
*)
	printSyntax
	;;
esac
