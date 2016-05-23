#!/bin/bash


###
# main goal : push the flash key content on local machine - availability to rsync special data on dedicated folder(s)
###

#vars :
src="/media/boogie/flash" 
dst="/home/boogie/Documents/"
src_chk="$(grep "${src}" /proc/mounts 2>&1)"
res="$?"
target="0"
content=$(ls -d "$src"/* |grep -v "lost+found" )

#misc_checks :
if [ "C$target" == "C$res" ]; then 
	echo  "ok "${src}" present ..."
else
	echo "no data ..to be loaded. plz chk" ; exit 1
fi

[ -n "${content}" ] && echo "here are folder present on "${src}" ====:  " ; echo "$content"

read -p "plz select le folder you'd like to dumpdata to local machine : " folder
echo "========"
echo "ok : here is your selection ===> $folder .. let's gonna dump it on "$dst" "
echo "========"

dry_run=$(rsync -azvn "$folder" "$dst")
run_verbose=$(rsync -azv "$folder" "$dst")
run_quiet=$(rsync -az "$folder" "$dst")

read -p "plz select your dump mode : <dry_run> <run_verbose> <run_quiet> " mode
echo "$mode selected :"
echo " ....."


case "$mode" in 
	dry_run ) "$dry_run" 
	;;
	run_verbose ) "$run_verbose"
	;;
	run_quiet ) "$run_quiet"
	;;
	*) echo "plz look to the three mode and choose one"
esac 
