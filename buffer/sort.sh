#!/bin/bash

file="prod1"

# on recupere le num de ligne qui comporte le role 
grep -Eon "role :[[:alnum:]]+" $file |awk -F: '{print $1}'> line_number

# on modifie la partie role (en la prefixant d'un chiffre pour pouvoir trier par la suite)
for num in $(cat line_number)
do
sed -rn "$num s/role (:[[:alnum:]]+),/1role\1/p" $file > part_$num
done


# on supprime " et , apres on tri puis on rajoute les " et , : 
for i in $(ls part_*)
do
       sed -re "s/[\",]//g" $i |sed 's/ /\n/g' |sort |tr '\n' ' ' |sed -re "s/([[:alnum:]]+)/\"\1\"/g" |sed -re "s/(\"[[:alnum:]]+\")/\1,/g"  >> sorted_$i
done

for p in $(ls sorted_*)
do
    #sed -rn "s/\"1role\",:\"([[:alnum:]]+)\",/role :\1,/p" $p >> last_$p  |sed -rn "s/(.*+\"),/\1/p" >> last_$p
    sed -rn "s/\"1role\",:\"([[:alnum:]]+)\",/role :\1,/p" $p |sed -rn "s/(.*+\"),/\1/p" >> last_$p
done
