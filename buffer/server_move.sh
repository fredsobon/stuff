#!/bin/env bash

##
## main goal : eases the record of server in files used in code deployment
##

##func :

# node remove : 

server_out_chk () {

# check position in file : in order to establish the dedicated text action to do.
for file in $(cat inputlist); do 
   if 
       grep -Eq   "[a-z]+, \"${node}\"," $file 
   then
      pattern="\"${node}\","
      #echo "$node located at the begining of $file "
	      sed -i "s# ${pattern}##" $file
   elif 	  
       grep -Eq   "\", \"${node}\"," "$file" 
    then 
      pattern="\"${node}\","
      #echo "$node is located between other nodes in $file"
	      sed -i "s# ${pattern}##" $file
    else
      # last one of the category : 
      grep -Eq   "\", \"${node}\"$" "$file" 
      pattern=", \"${node}\""
      #echo "$node is located at the end of the file $file"
	      sed -i "s/${pattern}//g" $file
    fi 
done
}

# node injection : 

server_in_chk () {
      
for file in $(cat inputlist); do 
      # just check that the node is not already present : 
      grep -q "$node" "$file"
      if [ $? -eq 0 ]; then 
          echo "no way the node is already present in $file !" 
		  exit 3
      fi
      
      # ensure that the role of the server is already defined AND that the first node of this role has to be record in a manual action : safe operation
      role=${node:0:5}
      grep -q "$role" "$file"
      if [ $? -ne 0 ]; then 
          echo "be careful the node seems to be the first one of the category. manual check and record needed ...in $file" 
          exit 4
      else
            line=$(grep -En "$role" "$file" |awk -F: '{print $1}')
            echo "ok : "$node" gonna be added  line number "$line" in "$file" "
            sed -ri ""${line}" s#(.*[[:alnum:]]\"$)#\1, \""$node"\"#" "$file" 
      fi 
done
}


##

sort_in () {

	for dir in $(dirname $(realpath $(cat inputlist)))
    do 
        cd "$dir"
        for file in *
        do
            grep -En role "$file" |awk -F: '{print $1}' > line_number
            sed -ri "s/role (:[[:alnum:]]+),/1role\1/g" "$file"
            sed -ri "s/[\",]//g" "$file" 
            for num in $(cat line_number)
			  do 
				sed -n "${num}p" $file  > ${file}${num}
                sed -ri "s/ /\n/g" "${file}${num}"
			    cat "${file}${num}" |sort |tr '\n' ' ' > "${file}${num}_sort"
			    sed -ri "s/([[:alnum:]]+)/\"\1\"/g" "${file}${num}_sort"
			    sed -ri "s/(\"[[:alnum:]]+\")/\1,/g" "${file}${num}_sort"
		        sed -ri "s/\"1role\",:\"([[:alnum:]]+)\",/role :\1,/" "${file}${num}_sort" 
			    sed -ri "s/(.*+\"),/\1/" "${file}${num}_sort"
				awk "{print }" "${file}${num}_sort" >> "${file}_final"
                rm  "${file}${num}" "${file}${num}_sort"
                cp "${file}_final" ../buffer/
		    done
				rm line_number
                mv "${file}_final" "$file"
        done
    done 
}


####

echo "################################"

read -p "action on node : add or remove ?   " action

echo "################################"

case $action in 

add)
read -p "gimme a node : " node

# retrieve target files to be process and test if this kind of server is already present ; if not a manual record is better (aka more safe) for the first time ... 
role=${node:0:5}
for file in fold/*
do 
    grep -q "$role" $file
    if [ $? -ne 0 ]; then 
        echo "be careful the node seems to be the first one of the category. manual check and record needed ...in $file" 
        exit 4
    fi
done

grep -l "${node:0:5}" fold/* > inputlist
echo "Here are the target file(s) :"
echo "$(cat -n inputlist)"
# delete potential dirty space at the end of lines : in order to process the job correctly
for file in $(cat inputlist)
do
    sed -i "s#\(.*\"\)[[:space:]]*#\1#g" "$file"
done

server_in_chk
sort_in
;;

remove)
read -p "gimme a node to be deleted: " node

# retrieve target files to be process 
grep  -q ^${node}$ "$file" 2>/dev/null || echo "no way the node is not present in $file!" 
grep -l "$node" fold/* > inputlist
# delete potential dirty space at the end of lines : in order to process the job correctly
for file in $(cat inputlist)
do
    sed -i "s#\(.*\"\)[[:space:]]*#\1#g" $file
done
server_out_chk
;;

*) echo "Please enter the action you'd like to be done < add > a new node in '.rb' files or < remove > a exiting one from the file(s)..."

esac

