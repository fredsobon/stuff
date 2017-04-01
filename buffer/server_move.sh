#!/bin/bash

## main goal : eases the record of server in files used in code deployment

#func :


# node remove : 

server_out_chk () {

	  # check position in file : in order to establish the dedicated text action to do.
      
      # begining : grep -E   "[[:alnum:]]*, \"${node}\"," prod.rb
for file in $(cat lst); do 
   if 
       grep -Eq   "[a-z]{1,}, \"${node}\"," $file 
   then
      echo "in first pos in $file "
	      sed -i "s# ${pattern}##" $file
   elif 	  
       grep -Eq   "\", \"${node}\"," "$file" 
    then 
      pattern="\"${node}\","
	  echo "<$pattern>"
      echo "in middle pos in $file"
	      sed -i "s# ${pattern}##" $file
    elif
      # last one of the category : 
       grep -Eq   "\", \"${node}\"$" "$file" 
    then
      pattern=", \"${node}\""
	  echo "<$pattern>"
      echo "in last pos in file $file"
	      sed -i "s/$pattern//g" $file
    else
      ## check node presence before deleting : 
      echo " in node check ..in $file "
       grep "$node" "$file" || echo "no way the node is not present !" 
    fi 
done
}

## node injection : 

server_in_chk () {
      
for file in $(cat lst); do 
      # just check that the node is not already present : 
      grep "$node" "$file"
      chk="$?"
      if [ _"$chk" = "_0" ]; then 
          echo "no way the node is already present in $file !" 
      fi
      
      # ensure that the role of the server is already defined AND that the first node of this role has to be record in a manual action : safe operation
      role=${node:0:4}
      grep "$role" "$file"
      chk="$?"
      if [ _"$chk" != "_0" ]; then 
          echo "be careful the node seems to be the first one of the category. manual check and record needed ...in $file" 
          exit 4
      else
          line=$(grep -in $role $file |awk -F: '{print $1}')
          echo "all right : < $node >  gonna be added in $file at line n° $line "
      fi 
done
}

server_in () {
for file in $(cat lst); do 
sed -i ""${line}" s#\(.*[[:alnum:]]\"$\)#\1, \""$node"\"#" $file 
done
}

# var :
#file="prod.rb"
#cp ${file} ${file}.ori
#lst= liste of files 


echo "################################"

read -p "action on node : add or remove ?" action

echo "################################"


case $action in 


add)
read -p "gimme a node : " node
server_in_chk
server_in
;;

remove)
read -p "gimme a node to be deleted: " node
server_out_chk
;;

*) echo "Please enter the action you'd like to be done < add > a new node in '.rb' files or < remove > a exiting one from the file(s)..."

esac

