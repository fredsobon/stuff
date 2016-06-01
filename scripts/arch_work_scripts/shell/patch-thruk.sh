#!/bin/sh

patch_dir=$(pwd)

for img in /etc/thruk/themes/themes-available/*/images ; do
	cp -vu  $patch_dir/images/* $img/
done 

cd /usr/share/thruk
patch -p1 < $patch_dir/e-merchant-links.diff
