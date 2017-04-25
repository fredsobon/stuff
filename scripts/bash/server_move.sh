#!/usr/bin/env bash

####
## main goal : eases the record of server in files used in code deployment for production env.
## mardi 25 avril 2017, 11:10:17 (UTC+0200)
## < exploit@meetic-corp.com > 
### 


##func :

# simple usage 
usage() { 

echo "$0 < add |remove > <node>" 
echo "ex: $0 add rabbit32 ; $0 remove lulu43"

}

# node remove  - got to test misc cases in order to delete a node :

server_out () {

# check position in file : in order to establish the dedicated text action to do.
for file in $(cat inputlist); do 
   if 
       grep -Eq   "[a-z]+, \"${node}\"," $file 
   then
      pattern="\"${node}\","
      echo "$node gonna be deleted at the begining of $file "
	      sed -i "s# ${pattern}##" $file
   elif 	  
       grep -Eq   "\", \"${node}\"," "$file" 
    then 
      pattern="\"${node}\","
      echo "$node gonna be deleted between two other nodes in $file"
	      sed -i "s# ${pattern}##" $file
    elif
      # last one of the category : 
      grep -Eq   "\", \"${node}\"$" "$file"
    then 
      pattern=", \"${node}\""
      echo "$node gonna be deleted at the end of the file $file"
	      sed -i "s/${pattern}//g" $file
    else 
      continue
    fi 
done
}

# node injection - got to test misc cases in order to add a node :

server_in () {
      
for file in $(cat inputlist); do 
      # just check that the node is not already present : 
      grep -q "$node" "$file"
      if [ $? -eq 0 ]; then 
          echo "no way the node is already present in file(s)! Please check !" 
		  exit 3
      fi
      
      # ensure that the role of the server is already defined AND that the first node of this role has to be record in a manual action : safe operation
      role=${node:0:5}
      grep -q "$role" "$file"
      if [ $? -ne 0 ]; then 
          echo "< Be careful the node seems to be the first one of the category. manual check and record needed ...in $file > " 
          exit 4
      else
            line=$(grep -En "$role" "$file" |awk -F: '{print $1}')
            echo "ok : "$node" gonna be added  line number "$line" in "$file" "
            sed -ri ""${line}" s#(.*[[:alnum:]]\"$)#\1, \""$node"\"#" "$file" 
      fi 
done
}


# sort our files - got to work on our files after a node added :

sort_in () {

	for dir in $(dirname $(realpath $(cat inputlist)))
    do 
        cd "$dir"
		for file in $(ls prod.rb)
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
		    done
				rm line_number
                mv "${file}_final" "$file"
    			sed -i "s#[[:space:]]*role#role#g" "$file"
                sed -i "s#\(.*\"\)[[:space:]]*#\1#g" $file
				if [ -e inputlist ]
				then rm inputlist
				fi
        done
    done 
}


###

## var :
action="$1"
node="$2"

# simple test to ensure at least one node is provided : 
if [  -n "$action" -a  -z "$node" ]
then 
	echo "Please provide a node to be proceeded ! ex: $0 add rabbit32" 
    exit 9
fi

# clean potential previous file : 
if [ -e inputlist ] 
	then rm inputlist
else  
	true
fi


#
case "$action" in 

add)

# retrieve target files to be process and test if this kind of server is already present ; if not a manual record is better (aka more safe) for the first time ... 
role=${node:0:5}
for file in $(ls */prod.rb)
do 
	grep -l "$role" "$file" >> inputlist
done

if [  -s inputlist ]
then
    echo "Here are the target file(s) :"
    echo "$(cat -n inputlist)"
else 
    echo "be careful the node seems to be the first one of the category. manual check and record needed in correct file(s) " 
	exit 1
fi 

# delete potential dirty space at the end of lines : in order to process the job correctly
for file in $(cat inputlist)
do
    sed -i "s#\(.*\"\)[[:space:]]*#\1#g" $file
done
# delete potential dirty space at the begining  of lines : in order to process the job correctly
for file in $(cat inputlist)
do
    sed -i "s#[[:space:]]*role#role#g" $file
done

server_in
sort_in
;;

remove)

# retrieve target files to be process 

for file in $(ls */prod.rb)
do
    grep -l "$node" "$file" >> inputlist
done

if [  -s inputlist ]
then
    echo "Here are the target file(s) :"
    echo "$(cat -n inputlist)"
else
    echo "no way the node is not present. Please check the file(s) !  " 
fi

# delete potential dirty space at the end of lines : in order to process the job correctly
for file in $(cat inputlist)
do
    sed -i "s#\(.*\"\)[[:space:]]*#\1#g" $file
done
# delete potential dirty space at the begining  of lines : in order to process the job correctly
for file in $(cat inputlist)
do
    sed -i "s#[[:space:]]*role#role#g" $file
done


server_out
;;

*) usage

esac

