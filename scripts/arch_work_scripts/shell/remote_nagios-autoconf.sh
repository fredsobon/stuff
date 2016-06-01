#!/bin/bash

# dlarquey @ E-Merchant

TARGET_DIR=/etc/nagios/conf.d
TARGET_FILENAME=e-merchant.cfg
TARGET_FILE=${TARGET_DIR}/${TARGET_FILENAME}
BASEDIR=/root/nagios-autoconf

# colors
GREEN= ; RED= ; CYAN= ; GRAY= ; WHITE= ; NC=
DRY_RUN= ; SITE= ; COLORS=


function error {
    echo "${RED}$*${NC}" >&2
    exit 1
}


function myexit() {
    [ -f ${f_objectsExtracted_before} ] && rm -f ${f_objectsExtracted_before}
    [ -f ${f_objectsExtracted_after} ] && rm -f ${f_objectsExtracted_after}
    [ -f ${TARGET_FILE}.tmp ] && rm -f ${TARGET_FILE}.tmp
}


function ExtractNagiosObjects() {
    local config_file="$1"
    [ -f ${config_file} ] || error "Missing file: ${config_file}"
    cat ${config_file}|awk '{
if ($0 ~ /^define/) {
        split($0,a," ")
        type = a[2]
        host = ""
        check = ""
}
if ((type == "service" || type == "host") && $0 ~ /host_name/) {
        split($0,a," ")
        host = a[2]
}
else if ((type == "service" || type == "host") && $0 ~ /check_command/) {
        split($0,a," ")
#        a[2] = a[2]"!"
#        check = a[2]
#        check = substr(a[2], 0, index(a[2],"!")-1)
        b=""
        for(i=2;i<=NF;i++) { b=b" "a[i] }
        check = b
}
else if ((type == "servicegroup" || type == "hostgroup") && $0 ~ /name/) {
        split($0, a," ")
        host = a[2]
}
if ($0 == "}") {
        print type";"host";"check
}
}'
}


function NagiosGenConfig() {
    [ -f ${TARGET_FILE}.tmp ] && rm -f ${TARGET_FILE}.tmp

    echo "Extracting objects before generating"
    ExtractNagiosObjects ${TARGET_FILE} >${f_objectsExtracted_before}

    echo "${WHITE}Generating the configuration...${NC}"
    echo "Temporary file used: ${TARGET_FILE}.tmp"

#cat ${f_objectsExtracted_before}

    eval $GENCONFIG -g $SITE >${TARGET_FILE}.tmp
    ret=$?
    [ $ret -eq 0 ] || error "Error when generating Nagios configuration. ABORT"

    echo "Extracting objects after generating"
    ExtractNagiosObjects ${TARGET_FILE}.tmp >${f_objectsExtracted_after}
}


function PrintObjectsDiff() {
        local char operator line
        case "$1" in
                added) char=">" ;;
                removed) char="<" ;;
                *) return
        esac

    diff -a -wB ${f_objectsExtracted_before} ${f_objectsExtracted_after}|\
        egrep "^${char}"|sed -r "s/^> (.*)$/${GREEN}\1${NC}/; s/^< (.*)$/${RED}\1${NC}/"
}


function PrintObjectsModified() {
    echo -e "\n${CYAN}* Objects removed${NC}"
    PrintObjectsDiff removed
    echo -e "\n${CYAN}* Objects added${NC}"
    PrintObjectsDiff added
}

function PrintTotalObjectsSummary() {
    echo -e "\n${CYAN}* Objects modified per type${NC}"
    diff -wB  ${f_objectsExtracted_before} ${f_objectsExtracted_after}|\
        egrep "< |> "|awk '{split($0,b,";"); split(b[1],c," "); print c[2]}'|sort|uniq -c|awk '{print $2" = "$1}'|\
        sed -r "s/(.*) = (\+?[1-9][0-9]*)$/${CYAN}\1${NC} = ${RED}\2${NC}/"|sed 's/^/\t/'
    echo
}


function PrintDiff() {
    echo -e "\n${CYAN}______________________ Diff ______________________${NC}"
    PrintObjectsModified
    PrintTotalObjectsSummary
}


function usage() {
cat <<EOS
$(basename $0) - Generate the Nagios configuration

    -n      Dry run mode
    -g      The geographical site for generating rules
    -C      Enable color mode
    -d      Base directory including the generator to use. Default is ${BASEDIR}
    -h      This help

EOS
exit 2

}



############
### MAIN ###
############

while getopts 'ng:Cd:h' flag; do
  case "${flag}" in
    n) DRY_RUN='true' ;;
    g) SITE="${OPTARG}" ;;
    C) COLORS="true" ;;
    h) usage ;;
    d) BASEDIR=${OPTARG} ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

if [ "$COLORS" == 'true' ]; then
    GREEN=$(echo -e '\033[0;32m')
    RED=$(echo -e '\033[0;31m')
    CYAN=$(echo -e '\033[0;36m')
    GRAY=$(echo -e '\033[0;37m')
    YELLOW=$(echo -e '\033[0;33m')
    NC=$(echo -e '\033[00m')
fi

trap myexit EXIT

echo -e "\n${CYAN} ------- Starting $(basename $0) -------${NC}"
echo "Using base directory: $BASEDIR"
[ -z "$SITE" ] && error "You must define the site to apply rules (-g)"
[ -d $BASEDIR ] || error "Invalid base directory: $BASEDIR"
GENCONFIG=${BASEDIR}/nagios-autoconf
[ -x $GENCONFIG ] || error "Invalid generator script: $GENCONFIG"

if [ "$DRY_RUN" == "true" ]; then
    echo "${YELLOW}Dry run option is ON${NC}" && sleep 1
fi


# temp files
MKTEMP_OPTS="-t $(basename $0).XXXXXX"
f_objectsExtracted_before=$(mktemp $MKTEMP_OPTS)
f_objectsExtracted_after=$(mktemp $MKTEMP_OPTS)

NagiosGenConfig
PrintDiff

if [ "$DRY_RUN" != "true" ]; then
    echo -n "${YELLOW}Applying changes for \"${SITE}\" (y/n):${NC} "
    read answer
    echo
    if [ "${answer,,}" == 'y' ]; then
        echo "${YELLOW}Applying changes...${NC}"
        echo "Backup the current configuration to: /tmp/${TARGET_FILENAME}.old"
        cp -f ${TARGET_FILE} /tmp/${TARGET_FILENAME}.old
        echo "Create the new configuration to: ${TARGET_FILE}"
        cp -vf ${TARGET_FILE}.tmp ${TARGET_FILE} && nagios3 -v /etc/nagios/nagios.cfg && /etc/init.d/nagios3 restart
    fi
else
    echo "${YELLOW}Dry Run mode: Nothing to do !${NC}"
fi

