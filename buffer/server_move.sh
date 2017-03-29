#!/bin/bash

## main goal : eases the record of server in files used in code deployment

#func :


# node remove : 

server_out_chk () {

      ## check node presence before deleting : 

      grep "$node" "$file"
      chk="$?"
      if [ _"$chk" != "_0" ]; then 
          echo "no way the node is not present !" 
          exit 1
      fi

	  # check position in file : in order to establish the dedicated text action to do.
      
      # begining : grep -E   "[[:alnum:]]*, \"${node}\"," prod.rb
      grep -Eq   "[[:alnum:]]*, \"${node}\"," $file
      chk="$?"
      if [ _"$chk" = "_0" ]; then
      echo "allright $node is the first of the list in the same category" 
      pattern="\"${node}\","
	  sed -i "s#${pattern}##" $file
      fi
	  
	  # node between some other server of the category :
      grep -Eq   "\"[[:alnum:]]*, \"${node}\"," "$file"
      chk="$?"
      if [ _"$chk" = "_0" ]; then
      echo "allright $node is one between some of the same category"
      pattern="\"${node}\","
	  sed -i "s#${pattern}##" $file
      fi

      # last one of the category : 
      grep -Eq   "\"[[:alnum:]]*, \"${node}\"$" "$file"
      chk="$?"
      if [ _"$chk" = "_0" ]; then
      echo "allright $node is the last of the  category" 
      pattern=", \"${node}\""
	  sed -i "s#${pattern}##" $file
      fi
}

server_out () {
echo "$node selected "
sed -i "s#,*\""$node"\",*##g" $file
}


## node injection : 

server_in_chk () {
      grep "$node" "$file"
      chk="$?"
      if [ _"$chk" = "_0" ]; then 
          echo "no way the node is already present !" 
          exit 3
      fi
}

server_def () {
      echo "all right you would like to add a node in $nodedef role categorie ..a kind already exists in $file"
      grep -in $nodedef $file
      chk="$?"
      if [ _"$chk" = "_0" ]; then 
          echo "no way : you want to inject a node that seems to be unique ..please check the role in the file !" 
          exit 3
      fi
         
         line=$(grep -in $nodedef $file |awk -F: '{print $1}')
}

server_in () {
echo "< $node > to be added in < $file >  at the end of line : < $line > "
echo "sed -i ""$line" s#\(.*[[:alnum:]]\"$\)#\1, \""$node"\"#" $file" 
sed -i ""${line}" s#\(.*[[:alnum:]]\"$\)#\1, \""$node"\"#" $file 

}

# var :
file="prod.rb"
cp ${file} ${file}.ori


echo "################################"

read -p "action on node : add or remove ?" action

echo "################################"


case $action in 


add)
read -p "gimme a node : " node
server_in_chk
read -p "please provide the plateform and the role of the server to be added. aka for instance : mwebfront, xwebapipriv and so ..." nodedef
server_def   
server_in
;;
remove)

read -p "gimme a node to be deleted: " node
server_out_chk
server_out
;;
*) echo "Please enter the action you'd like to be done < add > a new node in '.rb' files or < remove > a exiting one from the file(s)..."

esac
