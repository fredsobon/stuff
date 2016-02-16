#! /bin/sh

ADRESSE_LOCALE_SERVEUR="192.168.3.1"
ADRESSE_LOCALE_PORTABLE="192.168.3.15"
ADRESSE_INTERNET_SERVEUR="12.34.56.789"
PORT_SSH_INTERNET_SERVEUR="-p 12345"
LISTE_REPERTOIRES="/home/cpb/Documents/ /home/cpb/Projets/ /home/cpb/Desktop/"

synchroniser()
{
	# Arguments : 
	#    + [-r] inverse le sens du transfert
	#    + Repertoire
	#    + Hote
	#    + Port
	local dir
	local dst
	local port
	local ligne

	if [ "$1" = "-r" ]
	then
		dir="$2"
		dst="$3"
		port="$4"
		ligne="--rsh=\"ssh $port\" --delete \"${dst}:${dir}/\" \"${dir}/\""
	else
		dir="$1"
		dst="$2"
		port="$3"
		ligne="--rsh=\"ssh $port\" --delete \"${dir}/\" \"${dst}:${dir}\""
	fi
	echo "synchronisation $dir" >&2
	eval rsync -avxz -quiet "$ligne"
}



# le script s'execute-t-il sur le serveur ?
if /sbin/ifconfig | grep -F "${ADRESSE_LOCALE_PORTABLE} " >/dev/null 2>&1
then
	# Synchroniser le portable par Wifi
	DST_ADDR="${DST_ADDR:-${ADRESSE_LOCALE_SERVEUR}}"
	DST_PORT=

# Sinon s'execute-t-il sur le portable en wifi ?
elif /sbin/ifconfig | grep -F "${ADRESSE_LOCALE_SERVEUR} " >/dev/null 2>&1
then
	# Synchroniser le serveur par Wifi
	DST_ADDR="${DST_ADDR:-${ADRESSE_LOCALE_PORTABLE}}"
	DST_PORT=

# Sinon il s'execute sur le portable en deplacement
else
	# Synchroniser le serveur par son adresse Internet
	DST_ADDR="${DST_ADDR:-${ADRESSE_INTERNET_SERVEUR}}" 
	# Et le numero de port SSH sur le serveur
	DST_PORT="${PORT_SSH_INTERNET_SERVEUR}"
fi

if [ "$#" -gt 1 ]
then
	echo "usage: $0 [-r]" >&2
	exit 1
fi

if [ "$#" -eq 1 ]
then 
	if [ "$1" != "-r" ]
	then
		echo "$0: option $1 invalide" >&2
		exit 1
	fi
fi

for rep in ${LISTE_REPERTOIRES}
do
	synchroniser $1 "$rep" "$DST_ADDR" "$DST_PORT"
done

