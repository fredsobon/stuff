#!/bin/bash

# but extraire des portions des textes contenant le role et sa liste de serveurs  : rediriger dans un fichier , supprimer le role puis trier.
#Rajouter le role 
# concatener les diferents portions pour reassembler le fichier original trié.

fixed="role :[[:alnum:]]+, "


# on extrait le num de ligne comprenant notre role et la liste de servers :
grep -En "$fixed" prod1 |cut -d ":" -f 1 >line_file
echo $fixed

for i in $(cat line_file); do cat prod1 |sed -rn "$i s/$fixed//p" > test_$i  ;done  


for piece in $(ls test_$i); do 
cat "test_$i" |sed 's/[",]//g' |tr ' ' '\n' |sort |tr '\n' ' ' |sed -r "s/([[:alnum:]]+)/\"\1\"/g" |sed -r "s/(\"[[:alnum:]]+\")/\1, /g" |sed -r "s/^(.*)$/"$fixed" \1/g" >> "sort_$i"
done


