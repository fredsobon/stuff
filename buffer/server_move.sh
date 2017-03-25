#!/bin/bash

## main goal : eases the record of server in files used in code deployment

#func :

server_out () {
echo "$node selected "  
sed "s/\""$node"\",//g" $file >> prod.new
}

server_def () {
      grep "$node" "$file"
      chk="$?"
      if [ _"$chk" = "_0" ]; then 
          echo "no way the node is already present !" 
          exit 3
      else 
         echo "all right you would like to add a node in $nodedef role categorie ..a kind already exists in $file"
         grep -in $nodedef $file
         line=$(grep -in $nodedef $file |awk -F: '{print $1}')
      fi
}

server_in () {
echo "$node to be added in $file at the end of line : $line"
echo "sed  "$line" "s/\(.*$\)/\1, \""$node"\"/" t"
#sed -i ""$line" s/\(.*$\)/\1, \""$node"\"/" t
sed -i "s/\(.*$\)/\1, \""$node"\"/" t

}

# var :
file="prod.rb"


read -p "gimme a node : " node
read -p "action on node : add or remove ?" action



case $action in 

add) read -p "please provide the plateform and the role of the server to be added. aka for instance : mwebfront, xwebapipriv and so ..." nodedef
         server_def   
         server_in
;;
remove) server_out
;;
*) echo " please choose between <add> or <remove> ..else ciao!"
esac

## histo cmds : 
#sed -r 's#[[:alnum:]]{1,}, ([a-z]{1,}[0-9]{1})#\1#' lapin
# i=photostc5
#sed "s/\(.*$\)/\1, \""$i"\"/" t
#role :static, "photostc1",  "photostc3", "photostc4", "photostc5"

