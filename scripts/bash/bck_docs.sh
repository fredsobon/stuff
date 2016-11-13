#!/bin/bash


# Main goal : bck /home/boogie/Documents/learn folder and all contents ( which are the main doc to be retrieve) on a nexternal hdd 



src="/home/boogie/Documents/learn"
dst="/media/boogie/bck_flash"


# test de presence du montage dans proc/mounts : nb pas de "/" a la fin du pattern :
dst_check="$(grep "${dst}" /proc/mounts 2>&1)"
res=$?


if [ $res -eq 1  ]; then 
	echo "no way check your moutpoint plz "
	exit 1 
else 
	echo "mount point ok ...." 
fi  


# test du contenu du repertoire ( si vide le retour du test est faux ) :
[ "$(ls -A $dst)" ] && echo "Not Empty" || echo "Empty"


# test :

if [ -f $dst ]; then
	echo "please ensure your bck device is correctly recognize by the system.."
	echo "..thx .."
	exit 2
else
	echo "seems to be cool ..let's start ..."
	cd $src
	echo " we're now in $src folder ..."
        echo "gonna make a dry run first .."
	rsync -azvn . $dst
	read -p "is this the objective ??" ans
	echo "your answer is $ans .."
	case "$ans" in 
		y|yes|Y|Y..) rsync -azv . $dst
		;;
		n|no|N|NO) echo "alright ..let 's go out .."
		;;
		*) echo "please the answer should be <y|yes|Y|Y..> or n|no|N|NO ..then try again.."
		;; 
	esac
		
	fi

	
