#!/bin/bash
# double_boucle et filtrage distant de commande avec awk 
# on doit impérativement protéger avec un \ le $ de notre awk ....

for node  in $(cat lst)
do 
    echo " "
    echo "==  $node == "
    for ip in $(ssh  ${node} -l boogie "ip a |grep lo: |awk '{print \$4}'"  )
	do
		echo  "$ip"
    done
done  

