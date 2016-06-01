#!/bin/ksh

# Script ot purge OMS log files
# Author: David Larquey <d.larquey@pixmania-group.com>
# Date: Mon Sep 22 11:38:59 CEST 2014

SCRIPT=$(basename $0)
#LOG_RETENTION_DAYS=10
LOG_RETENTION_DAYS=0

# directories to purge
DATALOGDIR[${#DATALOGDIR[@]}]=/opt/oracle/middleware/gc_inst/WebTierIH1/diagnostics/logs
DATALOGDIR[${#DATALOGDIR[@]}]=/opt/oracle/middleware/gc_inst/user_projects/domains/GCDomain/servers/EMGC_OMS1/logs

# lsof cache file
lsof_cache_file=

logerror() {
    echo "ERROR: $*" >&2
    [ -n "$lsof_cache_file" -a -f $lsof_cache_file ] && rm -f $lsof_cache_file
    exit 1
}

echo "Purge OMS log files from : $DATALOGDIR"
lsof_cache_file=$(mktemp -t $SCRIPT.XXXX)
[ -z "$lsof_cache_file" ] && logerror "Can't create temp file"

for i in $(seq 0 $((${#DATALOGDIR[@]}-1))); do
    datalogdir=${DATALOGDIR[$i]}
    echo "#### Purge logs for: $datalogdir ####"
    # build the opened log file cache
    #lsof|grep $datalogdir|grep REG|awk '{print $NF}'|grep -v '(deleted)' | while read file; do echo "$file\$"; done >$lsof_cache_file
    lsof|grep $datalogdir|grep REG|awk '{if ($NF~/(deleted)/) {a=NF-1; print $a} else {print $NF}}'
    
    # Purge
    echo "+ Purge opened log files..."
    find $datalogdir -type f -name '*log*' -size +500M -exec ls -1 {} \;|grep -f $lsof_cache_file|while read file; do
        ls -lh $file
        > $file
    done
    
    echo "+ Delete biggest closed log files..."
    find $datalogdir -type f -name '*log*' -size +100M -exec ls -1 {} \;|grep -vf $lsof_cache_file|while read file; do
        ls -lh $file
        rm -f $file
    done
    
    echo "+ Delete oldest closed log files..."
    find $datalogdir -type f -name '*log*' -mtime +$LOG_RETENTION_DAYS -exec ls -1 {} \;|grep -vf $lsof_cache_file|while read file; do
        ls -lh $file
        rm -f $file
    done
done

rm -f $lsof_cache_file

# vim: set sw=4 et ts=4
