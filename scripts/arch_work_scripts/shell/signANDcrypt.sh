#!/bin/bash

# Project        : ipki-cms
# Author         : Arnault MICHEL, iPKI Team, BNPPARIBAS
# Version        : v0.9.1
# Pre-requisites : Java 1.4 min and the unlimited crypto pack
# Abstract       : this script sign and encrypt a file

source /usr/local/ipki/bin/env.sh

CLASS=com.bnpparibas.ipki.cms.cli.SignFile
java -classpath $CLASSPATH $CLASS $1 $2.temp

CLASS=com.bnpparibas.ipki.cms.cli.CryptFile
java -classpath $CLASSPATH $CLASS $2.temp $2

rm -f $2.temp
