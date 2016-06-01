#!/bin/sh

# A utiliser avec l'applet "Moniteur générique" de XFCE
# Package "xfce4-genmon-plugin" sous Debian

# CONFIGURATION
URL="http://monrer.fr"
STATION="LEG"
# Noms des trains (missions) à prendre en compte pour l'affichage du prochain passage
MISSIONS="GATA|GUTA|GOTA|NORA|TORA"
IMG=/usr/share/icons/gnome-colors-common/16x16/apps/clock.png

trains=$(curl -s -o - -e $URL/?s=$STATION $URL/json?s=$STATION | jq '.trains|.[]| .mission,.time,.retard,.destination' | sed -e 's/$/;/' | xargs -n 4 echo | sed -e 's/; /;/g' -e 's/;$//')

next=$( echo "$trains" | awk -F\; -v missions="$MISSIONS" '$1 ~ missions {print $2 " " $3}' | sort | head -1 | sed 's/ /\n/')

trains=$(echo "$trains" | sed 's/;/\t/g')

if [ -n "$IMG" ] && [ -f "$IMG" ]
then
    echo "<img>$IMG</img>"
fi
echo "<txt>$next</txt>"
echo "<tool>$trains</tool>"
echo "<click>xdg-open $URL/?s=$STATION</click>"
