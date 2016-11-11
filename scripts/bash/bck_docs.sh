#!/bin/bash


# Main goal : bck /home/boogie/Documents/learn folder and all contents ( which are the main doc to be retrieve) on a nexternal hdd 



src="/home/boogie/Documents/learn"
dst="/media/boogie/bck_flash"

dst_check="$(grep "${dst}" /proc/mounts 2>&1)"

[ "$(ls -A $dst)" ] && echo "Not Empty" || echo "Empty"


# test :

	if [ -f $dst ]; then
		echo "please ensure your bck device is correctly recognize by the system.."
		echo "..thx .."..
	else
		echo "seems to be cool ..let's start ..."
		cd $src
		echo " we're now in $src folder ..."
	        echo "gonna make a dry run first .."
		rsync -azvn . $dst
		read -p "is this the objective ??" ans
		echo "your answer is $ans .."
		case "$ans" in 
			y|Y) rsync -azvn . $dst
			;;
			n|N) echo "alright ..let 's go out .."
			;;
		esac
		
	fi

	
