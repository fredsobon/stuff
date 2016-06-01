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
	echo "`basename $0` [-u <USER>] [-f <FILER_ADDR>] [-z <POOL_NAME>] [-e <ERAC_NAME>] [-U <USERID>][-G <GROUPID>][-M <MODE>][-o <OUTPUT_FILE>]"
	echo
	exit 1
}


generate_luns_conf() {
	$SSH_CMD -l $USER_NAME $FILER_NAME << EOF
script
pool = '$POOL_NAME';
erac_name = '$ERAC_NAME';
uid = $USERID;
gid = $GROUPID;
mode = $MODE;
printf('\n\t######################################################\n');
printf('\t##  $FILER_NAME  ##\n');
printf('\t######################################################\n\n');
run("cd /");
run('shares set pool=' + pool);
run('shares');
projects = list();
for (i=0; i < projects.length; ++i) {
  project = projects[i];
  reg = new RegExp ('^' + erac_name + '_.*$');
  if ( ! project.match(reg) ) {
    continue;
  }
  printf('\t# Begin project %s\n', project);
  run('cd /');
  run('shares select ' + project);
  luns = list();
  for (j=0; j < luns.length; ++j) {
    run('select ' + luns[j]);
    printf('\tmultipath {\n');
    printf('\t\twwid 3%s\n', get('lunguid').toLowerCase());
    printf('\t\talias %s\n', luns[j]);
    printf('\t\tuid %d\n', uid);
    printf('\t\tgid %d\n', gid);
    printf('\t\tmode %d\n', mode);
    printf('\t\t}\n');
    run('cd ..');
  }
  printf('\t# End project %s\n\n', project);
}
.
EOF
}


# parsing command line options
while getopts "u:f:z:e:o:U:G:M:h" optionname; do
case "$optionname" in
	u) USER_NAME="$OPTARG" ;;
	f) FILER_NAME="$OPTARG" ;;
	z) POOL_NAME="$OPTARG" ;;
	e) ERAC_NAME="$OPTARG" ;;
	o) OUTPUT_FILE="$OPTARG" ;;
	U) USERID="$OPTARG" ;;
	G) GROUPID="$OPTARG" ;;
	M) MODE="$OPTARG" ;;
	h) echo "" && usage ;;
    *) echo "ERROR: unrecognized option $1" 1>&2; usage ;;
    esac
done


# Check arguments
if [ -z "$USER_NAME" ] ||  [ -z "$FILER_NAME" ] || [ -z "$POOL_NAME" ] || [ -z "$ERAC_NAME" ] ||  [ -z "$USERID" ] ||  [ -z "$GROUPID" ] || [ -z "$MODE" ]; then
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

OUTPUT=$( generate_luns_conf )

if [ -z "$OUTPUT_FILE" ]
then
    echo "$OUTPUT"
else
    echo "$OUTPUT" > "$OUTPUT_FILE"
fi

