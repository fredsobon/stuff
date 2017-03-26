#!/bin/bash

## main goal : eases the record of server in files used in code deployment

#func :

server_out_chk () {
      grep "$node" "$file"
      chk="$?"
      if [ _"$chk" != "_0" ]; then 
          echo "no way the node is not present !" 
          exit 2
      fi
}

server_in_chk () {
      grep "$node" "$file"
      chk="$?"
      if [ _"$chk" = "_0" ]; then 
          echo "no way the node is already present !" 
          exit 3
      fi
}

server_out () {
echo "$node selected "  
sed "s/,*\""$node"\",*//g" $file >>  yop
}

server_def () {
         echo "all right you would like to add a node in $nodedef role categorie ..a kind already exists in $file"
         grep -in $nodedef $file
         line=$(grep -in $nodedef $file |awk -F: '{print $1}')
}

server_in () {
echo "$node to be added in $file at the end of line : $line"
sed -i "s/\(.*$\)/\1, \""$node"\"/" $file

}

# var :
file="prod.rb"
cp ${file} ${file}.ori


echo "################"
read -p "action on node : add or remove ?" action
echo "################"


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
*) echo " please choose between <add> or <remove> ..else ciao!"
esac

## histo cmds : 
#sed -r 's#[[:alnum:]]{1,}, ([a-z]{1,}[0-9]{1})#\1#' lapin
# i=photostc5
#sed "s/\(.*$\)/\1, \""$i"\"/" t
#role :static, "photostc1",  "photostc3", "photostc4", "photostc5"

