#!/bin/bash

src="/home/boogie/Documents/work/work_doc/"
dst="/media/boogie/flash/m_job/"

if [ -d "/media/boogie/flash/" ] ; then
echo "ok flash key mounted ..let's gonna run "
else 
echo "check the mountpoint .."
fi

rsync -azv --exclude=".git" $src $dst




