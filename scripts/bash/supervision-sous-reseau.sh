#! /bin/bash

# La premiere colonne correspond aux noms ou adresses IP des postes
# a surveiller, la seconde au nom d'utilisateur a employer pour la
# supervision.
i=1;
poste[$i]="192.168.1.8"  ; user[$i]="root"; i=$((i+1))
poste[$i]="192.168.1.9"  ; user[$i]="root"; i=$((i+1))
poste[$i]="192.168.1.20" ; user[$i]="root"; i=$((i+1))
poste[$i]="192.168.1.24" ; user[$i]="root"; i=$((i+1))
poste[$i]="192.168.1.105"; user[$i]="root"; i=$((i+1))
poste[$i]="192.168.1.217"; user[$i]="root"; i=$((i+1))
nb_postes=$i



function installer
{
	# Generer si besoin la cle SSH
	if [ ! -f ~/.ssh/id_rsa.pub ]
	then
		rm -rf ~/.ssh
		ssh-keygen -t rsa
	fi

	# Aller l'inscrire sur les postes supervises
	cle=$(cat ~/.ssh/id_rsa.pub)
	local i=1
	while [ $i -lt $nb_postes ]; do
		ssh -o StrictHostKeyChecking=no ${user[$i]}@${poste[$i]} \
		  "rm -rf .ssh; mkdir .ssh; echo $cle > .ssh/authorized_keys"
		i=$((i+1))
	done
}



function executer
{
	local i=1
	while [ $i -lt $nb_postes ]
	do
		echo "======= ${poste[$i]} ======="
		ssh ${user[$i]}@${poste[$i]} "$*"
		i=$((i+1))
	done
}



function download
{
	local r="$1"
	local p="$2";
	local i=1
	while [ $i -lt $nb_postes ]
	do
		if ping -c 1 -w 1 ${poste[$i]} >/dev/null 2>&1
		then
			echo "${poste[$i]}"
			scp "${user[$i]}@${poste[$i]}:$r" "$p"-${poste[$i]}
		fi
		i=$((i+1))
	done
}



function upload
{
	local l="$1"
	local r="$2";
	local i=1
	while [ $i -lt $nb_postes ]
	do
		if ping -c 1 -w 1 ${poste[$i]} >/dev/null 2>&1
		then
			echo "${poste[$i]}"
			scp "$l" "${user[$i]}@${poste[$i]}:$r"
		fi
		i=$((i+1))
	done
}



if [ "$*" = "" ]
then 
	echo "USAGE" >&2
	echo "  $0 action [arguments...]" >&2
	echo "ACTIONS" >&2
	echo "  install">&2
	echo "    installer la supervision sur toutes les stations" >&2
	echo "  upload local remote">&2
	echo "    copier le fichier \"local\" a l'emplacement \"distant\" sur toutes les stations" >&2 
	echo "  download distant prefixe">&2
	echo "    copier tous les fichiers \"distants\" en local avec le \"prefixe\" suivi du nom de station" >&2
	echo "  execute commande..." >&2
	echo "    executer la \"commande\" sur un shell distant">&2
	exit 0
fi

case $1 in
	instal*  )
		shift
		if [ $# -ne 0 ]; then echo "$0: trop d'arguments"; exit 2; fi
		installer ;;
	download )
		shift
		if [ $# -ne 2 ]; then echo "$0 : mauvais nombre d'arguments"; exit 2; fi
		download "$1" "$2"
		;;
	upload )
		shift
		if [ $# -ne 2 ]; then echo "$0 : mauvais nombre d'arguments"; exit 2; fi
		upload "$1" "$2"
		;;
	exec* )
		shift 
		executer "$@" ;;

	* )
		echo "Action inconnue. Invoquez \"$0\" seul pour avoir de l'aide" >&2
		exit 1
		;;
esac

