#!/bin/bash

for y in $(cut -f6 -d ':' /etc/passwd |sort |uniq); do
  name="$y" 
  for suffix in "" "2"; do
    if [ -s "${y}/.ssh/authorized_keys$suffix" ]; then
      echo "### ${y}: " | sed 's/......................//'
      awk  '/ssh-/ {printf "%s-%s:\n  key: '\''%s'\''\n  type: %s\n",$NF,"'${name}'",$(NF-1),$(NF-2)}' "${y}/.ssh/authorized_keys$suffix"
      echo ""
     fi;
   done;
done

