#!/bin/sh

SQL=/opt/oracle/admin/orawork/sql/enable_block_change.sql
echo >$SQL

#for i in `cat /opt/oracle/admin/orawork/cfg/backuprman.cfg | grep -v "^#" | grep -v '^$'| grep  "^-sid"` 
cat /opt/oracle/admin/orawork/cfg/backuprman.cfg | grep -v "^#" | grep -v '^$'| grep  "^-sid" | while read i
do

dbname=$(echo $i | awk '{print $2}')
user=$(echo $i | awk '{print $6}')
chemin=$(echo $i | awk '{print $16}')


echo "Chemin : $chemin  user :$user"


echo "alter database disable block change tracking;" 							>> $SQL
echo "alter database enable block change tracking using file '$chemin/${dbname}_change_tracking.f'" 	>> $SQL



done;
