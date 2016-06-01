#!/bin/bash

# Project        : ipki-cms
# Author         : Arnault MICHEL, iPKI Team, BNPPARIBAS
# Version        : v0.9.1
# Pre-requisites : Java 1.4 min and the unlimited crypto pack
# Abstract       : this script decrypt a p7m file

source /usr/local/ipki/bin/env.sh

CLASS=com.bnpparibas.ipki.cms.cli.UncryptFile

java -classpath $CLASSPATH $CLASS $@
