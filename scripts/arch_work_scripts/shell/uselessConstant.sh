#!/bin/bash

if [ ! $# = 1 ]
then
	echo "Syntax : $0 inputFileName"
	echo "inputFileName is a constants list. One constant by line."
	echo "Create a log file in the inputFileName directory."
	exit
fi

sExt="${1##*.}"
sInputFileBaseName="${1%%.*}"

sOutputFileBaseName=$(echo $sInputFileBaseName"_Check")
sInputFileName="$sInputFileBaseName.$sExt"
sOutputFileName="$sOutputFileBaseName.$sExt"
sBaseDirName=$(echo ~/"web_dir")
aSearchDirName=('bo-carrefour' 'bo-core' 'fo-carrefour' 'fo-core')

if [ ! -r "$sInputFileName" ]
then
	echo "$sInputFileName unknown"
	exit
fi

if [ -r "$sOutputFileName" ]
then
	rm -f $sOutputFileName
fi

echo "Reading $sInputFileName..."
while read sConstant
do
	for sSearchDirName in ${aSearchDirName[*]}
	do
		sSearchDirFullName="$sBaseDirName/$sSearchDirName"
		if [ -d $sSearchDirFullName ]
		then
			iRet=$(find $sSearchDirFullName -name '*.php' | xargs grep -snil \"$sConstant\" | wc -l)
			echo "$sSearchDirFullName	$sConstant	$iRet"
			echo "$sSearchDirFullName	$sConstant	$iRet" >> $sOutputFileName
		fi
	done
done < $sInputFileName
