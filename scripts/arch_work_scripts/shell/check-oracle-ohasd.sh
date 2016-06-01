#!/usr/bin/env bash
# vim: ts=4 sw=4 et
#
# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/snmp/files/plugins/check-oracle-ohasd.sh $


BASEOID='.1.3.6.1.4.1.38673.1.26.6'
MODE=''
TMPDIR=/tmp/$(basename ${0} .sh)


# Fonction : _usage
_usage() {
    cat <<EOF
Usage: $(basename $0) [-h] {-g|-n|-s} OID [VALUE]

Options:
    -g : get value
    -h : display this help and exit
    -n : get next value
    -s : set value
EOF
}


# Function : _ohasd_status
_ohasd_status() {
    [ ! -d "${TMPDIR}" ] && mkdir "${TMPDIR}"

    process='init.ohasd'
    cmd="pgrep -l ${process}"

    eval "${cmd}" 2>&1 >/dev/null
    if [ $? -eq 0 ]; then
        eval "${cmd}" | awk '{print $2 " ("$1") is running "}' >${TMPDIR}/result_msg 2>&1
        echo $? > ${TMPDIR}/result_code
    else
        echo "Error: ${process} is not running !" >${TMPDIR}/result_msg 2>&1
        echo 2 > ${TMPDIR}/result_code
    fi
}


# Function : _snmp_get
_snmp_get() {
    _ohasd_status
    case "$1" in
        0)
            echo -e "${BASEOID}.${1}\nINTEGER"
            cat ${TMPDIR}/result_code
            ;;
        1)
            echo -e "${BASEOID}.${1}\nSTRING"
            cat ${TMPDIR}/result_msg | sed -e ':a;N;$!ba;s/\n/; /g'
            ;;
    esac
}


# Parse for command-line arguments
while getopts 'ghns' options; do
    case "${options}" in
        g) MODE='get' ;;
        n) MODE='next' ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;
        h) _usage; exit 0 ;;
        *) _usage; exit 1 ;;
    esac
done

shift $((${OPTIND}-1))

if [ $# -ne 1 -o -z "${MODE}" ]; then
    _usage
    exit 1
fi

# Check for requested OID
OID=${1}

if ! (echo ${OID} | grep -qE "^${BASEOID}"); then
    echo "Error: base OID must begin with ${BASEOID}" >&2
    exit 1
fi

case ${OID#$BASEOID} in
    '') if [ "${MODE}" == 'next' ]; then _snmp_get 0 ; fi ;;
    .0) if [ "${MODE}" == 'get' ];  then _snmp_get 0 ; else _snmp_get 1 ; fi ;;
    .1) if [ "${MODE}" == 'get' ];  then _snmp_get 1 ; fi ;;
esac

