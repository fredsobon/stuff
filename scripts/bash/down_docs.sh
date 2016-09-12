#!/bin/bash


###
# main goal : push the flash key content on local machine - availability to rsync special data on dedicated folder(s)
###
dry_run ()
{
rsync -azvn "${src}/m_job/" "$dst"
}

run_verbose ()
{
rsync -azv "${src}/m_job/" "$dst"
}

run_quiet () 
{
rsync -az "${src}/m_job/" "$dst"
}

#vars :
src="/media/boogie/flash"
dst="/home/boogie/Documents/work/m_job/"
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

read -p "plz select your dump mode : <dr> <verbose> <silent> ... " mode
echo "$mode selected :"
echo " ....."


case "$mode" in 
	dr ) dry_run
	;;
	verbose ) run_verbose
	;;
	silent ) run_quiet
	;;
	*) echo "plz look to the three mode and choose one"
        ;;
esac 
