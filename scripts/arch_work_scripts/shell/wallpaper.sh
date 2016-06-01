#!/bin/bash

DIR=~/Images/Wallpapers/dualdisplay
DELAY=900
WIDTH=1280
HEIGHT=1024
BARSIZE=32
TMPDIR=/tmp
BG_COLOR="black"

BG_HEIGHT=$(( $HEIGHT - $BARSIZE ))

while true
do
	# Select one file randomly
	IMG=`ls $DIR/* | shuf -n 1`

	# Set $NAME to file name without extension
	NAME=`basename $IMG | sed 's/\....$//'`

	# Split image in 2 parts, left (_0) and right (_1)
	convert $IMG -filter lanczos -crop 50%x100% -resize ${WIDTH}x${HEIGHT} +repage $TMPDIR/${NAME}_%d.png

	for image in $TMPDIR/${NAME}_?.png
	do
		h=$(identify $image|awk '{print $3}'|awk -Fx '{print $2}')
		if [ $h -eq $HEIGHT ]
		then
			# Image is already full height, nothing to do
			continue
		else
			if [ $h -lt $BG_HEIGHT ]
			then
				# Image's height is less than visible background's height
				# So we first center it in an image with background's height
				tmpfile=$(mktemp --tmpdir=/tmp tmp.XXXXXXXXXX.png)
				convert $image -size ${WIDTH}x${BG_HEIGHT} xc:$BG_COLOR +swap -gravity South -composite $tmpfile
	            mv $tmpfile $image
			fi

			# Now, create full height image, adding bottom background
			tmpfile=$(mktemp --tmpdir=/tmp tmp.XXXXXXXXXX.png)
	        convert $image -size ${WIDTH}x${HEIGHT} xc:$BG_COLOR +swap -gravity North -composite $tmpfile
			mv $tmpfile $image
		fi
	done

	# Set XFCE monitors backgrounds
	#xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-show -s true
	xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path -s $TMPDIR/${NAME}_0.png
	xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor1/image-path -s $TMPDIR/${NAME}_1.png

	# Sleep a while but allow immediate change with SIGHUP
	sleep $DELAY &
	trap "rm $TMPDIR/${NAME}_?.png; exit" TERM INT
	trap "kill $!" HUP
	wait

	# Clean up
	rm $TMPDIR/${NAME}_?.png
done
