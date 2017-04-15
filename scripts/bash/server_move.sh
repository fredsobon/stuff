#!/bin/bash

## main goal : eases the record of server in files used in code deployment

##func :

# node remove : 

server_out_chk () {

	  # check position in file : in order to establish the dedicated text action to do.
      
      # begining : grep -E   "[[:alnum:]]*, \"${node}\"," prod.rb
for file in $(cat inputlist); do 
   if 
       grep -Eq   "[a-z]+, \"${node}\"," $file 
   then
      pattern="\"${node}\","
	  echo "<$pattern>"
      echo "$node located at the start of $file "
	      sed -i "s# ${pattern}##" $file
   elif 	  
       grep -Eq   "\", \"${node}\"," "$file" 
    then 
      pattern="\"${node}\","
	  echo "<$pattern>"
      echo "$node is located between other nodes in $file"
	      sed -i "s# ${pattern}##" $file
    elif
      # last one of the category : 
       grep -Eq   "\", \"${node}\"$" "$file" 
    then
      pattern=", \"${node}\""
	  echo "<$pattern>"
      echo "$node is located at the end of the file $file"
	      sed -i "s/${pattern}//g" $file
    else
      ## check node presence before deleting : 
      echo " in node check ..in $file "
       grep "$node" "$file" || echo "no way the node is not present !" 
    fi 
done
}

## node injection : 

server_in_chk () {
      
for file in $(cat inputlist); do 
      # just check that the node is not already present : 
      grep "$node" "$file"
      if [ $? -eq 0 ]; then 
          echo "no way the node is already present in $file !" 
		  exit 3
      fi
      
      # ensure that the role of the server is already defined AND that the first node of this role has to be record in a manual action : safe operation
      role=${node:0:5}
      grep "$role" "$file"
      if [ $? -ne 0 ]; then 
          echo "be careful the node seems to be the first one of the category. manual check and record needed ...in $file" 
          exit 4
      else
          line=$(grep -in "$role" "$file" |awk -F: '{print $1}')
          echo "all right : < $node >  gonna be added in "$file" at line n° "$line" "
      fi 
done
}

server_in () {
for file in $(cat inputlist); do 

sed -i ""${line}" s#\(.*[[:alnum:]]\"$\)#\1, \""$node"\"#" $file 
done
}
sort_in () {

# retrieve role for nodes 
grep -Eon "role :[[:alnum:]]+" $file |awk -F: '{print $1}'> line_number

# fake name prefixing role to prepare sort 
for num in $(cat line_number)
do
sed -rn "$num s/role (:[[:alnum:]]+),/1role\1/p" $file > part_$num
done


# delete unused caracters : 
for i in $(ls part_*)
do
       sed -re "s/[\",]//g" $i |sed 's/ /\n/g' |sort |tr '\n' ' ' |sed -re "s/([[:alnum:]]+)/\"\1\"/g" |sed -re "s/(\"[[:alnum:]]+\")/\1,/g"  >> sorted_$i
done

# last change to clean role and delete unmandatory caracters : 

for p in $(ls sorted_*)
do
    sed -rn "s/\"1role\",:\"([[:alnum:]]+)\",/role :\1,/p" $p |sed -rn "s/(.*+\"),/\1/p" >> last_$p
done

# let's merge it all ...then cleanup ! 


awk '{print $0}' last_* >> filefinal
rm last_* sorted_* part_* line_number 
mv filefinal $file
}

####
# file prep : delete unecessary space .
sed -ir 's/\(.*"\)[[:space:]]*/\1/g' $(cat inputlist)

echo "################################"

read -p "action on node : add or remove ?   " action

echo "################################"

case $action in 

add)
read -p "gimme a node : " node
server_in_chk
server_in
sort_in
;;

remove)
read -p "gimme a node to be deleted: " node
server_out_chk
;;

*) echo "Please enter the action you'd like to be done < add > a new node in '.rb' files or < remove > a exiting one from the file(s)..."

esac

