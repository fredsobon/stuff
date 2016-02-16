#! /bin/bash

lg_mot_de_passe="${1:-8}"
mot_de_passe=""

# Liste des caracteres utilisables pour le mot de passe.
caracteres="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
caracteres="${caracteres}abcdefghijklmnopqrstuvwxyz"
caracteres="${caracteres}0123456789"
# NB: le caractere $ doit etre protege par un backslash.
caracteres="${caracteres}\$@&%~#{([-_])}+="

# Nombre de caracteres dans la liste de ceux autorises.
nb_caracteres=${#caracteres}

i=1
while [ $i -le "$lg_mot_de_passe" ]
do
	# Tirer une valeur aleatoire entre 1 et le nombre de
	# caracteres dans la liste autorisee.
	n=$((1 + ${RANDOM} % ${nb_caracteres}))

	# Ajouter dans le mot de passe le n-ieme caractere.
	mot_de_passe="${mot_de_passe}${caracteres:$n:1}"

	i=$((i + 1))
done

echo "$mot_de_passe"
