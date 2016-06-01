#!/bin/bash

# Author : Arnault MICHEL, iPKI Team, BNPPARIBAS
# Version : 1.0
# Pre Requisite : Java 1.4 min and the unlimited crypto pack
# Abstract : this script set and verifies variables


CLASSPATH=/usr/local/ipki/lib/bcprov-jdk14-140.jar:/usr/local/ipki/lib/log4j-1.2.15.jar:/usr/local/ipki/lib/bcmail-jdk14-140.jar:/usr/local/ipki/lib/ipki-cms_v1.0.1.jar:/usr/local/ipki/lib/ipki-core_v1.0.0.jar:/usr/local/ipki/conf

[ ! -e `which java` ]  && { echo "Java not found."; exit 1; }
