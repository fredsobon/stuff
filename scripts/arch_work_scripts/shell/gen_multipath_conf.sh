#!/bin/bash
## prerequis: projet/share déjà existant
## Pour les insultes: f.dutheil@pixmania-group.com

# safety first
set -e

#Global vars
SSH_CMD="`which ssh` -T"
OUTPUT=""

usage() {
	echo 
	echo "Usage:"
	echo "`basename $0` [-u <USER>] [-f <FILER_ADDR>] [-z <POOL_NAME>] [-p <PROJECT_NAME>] [-U <USERID>][-G <GROUPID>][-o <OUTPUT_FILE>]"
	echo
	exit 1
}


generate_luns_conf() {
	$SSH_CMD -l $USER_NAME $FILER_NAME << EOF
script
pool = '$POOL_NAME';
project = '$PROJECT_NAME';
uid = $USERID;
gid = $GROUPID;
mode = 660;
run('cd /');
run('shares set pool=' + pool);
run('shares select ' + project);
luns = list();
for (i=0; i < luns.length; ++i) {
  run('select ' + luns[i]);
  printf('\tmultipath {\n');
  printf('\t\twwid 3%s\n', get('lunguid').toLowerCase());
  printf('\t\talias %s\n', luns[i]);
  printf('\t\tuid %d\n', uid);
  printf('\t\tgid %d\n', gid);
  printf('\t\tmode %d\n', mode);
  printf('\t\t}\n');
  run('cd ..');
}
.
EOF
}


# parsing command line options
while getopts "u:f:z:p:o:U:G:h" optionname; do
case "$optionname" in
	u) USER_NAME="$OPTARG" ;;
	f) FILER_NAME="$OPTARG" ;;
	z) POOL_NAME="$OPTARG" ;;
	p) PROJECT_NAME="$OPTARG" ;;
	o) OUTPUT_FILE="$OPTARG" ;;
	U) USERID="$OPTARG" ;;
	G) GROUPID="$OPTARG" ;;
	h) echo "" && usage ;;
    *) echo "ERROR: unrecognized option $1" 1>&2; usage ;;
    esac
done


# Check arguments
if [ -z "$USER_NAME" ] ||  [ -z "$FILER_NAME" ] || [ -z "$POOL_NAME" ] || [ -z "$PROJECT_NAME" ] ||  [ -z "$USERID" ] ||  [ -z "$GROUPID" ] ; then
	echo "ERROR: missing parameter" 1>&2 && usage
fi

# Check if pool exists
res=$( $SSH_CMD -l $USER_NAME $FILER_NAME << EOF
cd /
shares set pool=$POOL_NAME
EOF
)
if ( echo $res | grep -q 'bad property' ); then
	echo "ERROR: Pool $POOL_NAME does not exist." 1>&2 && usage
fi

# Check if project exists
res=$( $SSH_CMD -l $USER_NAME $FILER_NAME << EOF
cd /
shares set pool=$POOL_NAME
shares select $PROJECT_NAME get creation
EOF
)
if ( echo $res | grep -q 'not found' ); then
	echo "ERROR: Share/Project $PROJECT_NAME does not exist." 1>&2 && usage
fi


OUTPUT=$( echo -e "\t# Begin project $PROJECT_NAME (generated with \'`basename $0` $*\')" ; generate_luns_conf ; echo -e "\t# End project $PROJECT_NAME" )


if [ -z "$OUTPUT_FILE" ]
then
    echo "$OUTPUT"
else
    echo "$OUTPUT" > "$OUTPUT_FILE"
fi

