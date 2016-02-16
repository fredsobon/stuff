#! /bin/sh

REPERTOIRE_SCAN=~/scans
PREFIXE_FICHIER=scan

# Chercher le premier numero libre de la journee
base_fichier="${REPERTOIRE_SCAN}/${PREFIXE_FICHIER}"-$(date +"%Y-%m-%d")
i=1
while true
do
	fichier="${base_fichier}"-$(printf "%02d" $i).pdf
	if [ -e "$fichier" ]
	then
		i=$((i+1))
		continue
	fi
	break
done

while true
do
	echo "Placez le document sur le scanner"
	echo "   pressez Entrée (Ctrl-D pour finir)"
	read r  || break
	scanimage > scan.pnm  || break
 	convert scan.pnm "$fichier"  || break
	echo "===> fichier $fichier sauvegarde"
	i=$((i+1))
	fichier="${base_fichier}"-$(printf "%02d" $i).pdf
done
