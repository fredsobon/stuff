#! /bin/bash


#set -x

if [ "$#" -ge "3" ]
then
	cd $1
	ROOT_PATH=$1
	java -Xms256M -Xmx1024M -cp classpath.jar: $2 --context=$3 $*
else
	echo "usage: le script prend 3 arguments,un répertoire de base, un fichier compilé (ex:shopbot_file_export.ceneo_plpl_0_1.Ceneo_PLpl) puis votre context (ex:Default)"

fi
