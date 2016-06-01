dest=/srv/backup/export_svn/

[ -d $dest ] || exit 1

for repo in /srv/svn/*; do
	tag=$(svn propget em:lastsync-prod --revprop -r 0 file://$repo)
	proj=$(basename $repo)
	echo "$repo:<$tag>"
	if [ -z "$tag" ]; then
		echo "# $repo:$tag - TAG not found"
	else
		echo "# $repo:$tag - svn export file://$repo/tags/$tag $dest/$proj"
		svn export file://$repo/tags/$tag $dest/$proj >/dev/null
	fi
done



