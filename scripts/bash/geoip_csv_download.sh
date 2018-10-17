#!/bin/bash

path_csv="/home/boogie/Bureau/run/geoip_csv/test/"
file_type="GeoIP2-City-CSV GeoIP2-ISP-CSV GeoIP2-Anonymous-IP-CSV"
bck_folder="/tmp/"
key="blabla"
date=$(date +%F)

for file in $(echo ${file_type})
do 
  # download zip files :
  curl -s -o ${file}.zip https://download.maxmind.com/app/geoip_download?edition_id=${file}\&license_key=${key}\&suffix=zip
  # download md5 files :
  curl -s -o ${file}.md5 https://download.maxmind.com/app/geoip_download?edition_id=${file}\&license_key=${key}\&suffix=zip.md5

  # compare checksum : 
  md5=$(md5sum ${file}.zip |awk '{print $1}')
  if [[ "$md5" == $(cat "${file}.md5") ]]
  then 
    echo "${file} downloaded the $date is correct" >> ${date}_log
  else 
    echo "file corruption!"  
    curl -s -o ${file}.zip https://download.maxmind.com/app/geoip_download?edition_id=${file}\&license_key=${key}\&suffix=zip
  fi
done


mv G* ${bck_folder}

