#!/bin/bash
# vim: ts=4 sw=4 et
#
# check-postfix: Vincent Batoufflet <vbatoufflet@e-merchant.com>
#                Thu, 06 Sep 2012 13:50:56 +0200
#

BASEOID='.1.3.6.1.4.1.38673.1.13'
MODE=''

# Functions
print_usage() {
    cat <<EOF
Usage: $(basename $0) [-h] {-g|-n|-s} OID [VALUE]

Options:
   -g  get value
   -h  display this help and exit
   -n  get next value
   -s  set value
EOF
}

snmp_get() {
    case "$1" in
        1)
            count=$(postqueue -p | grep -cE '^[0-9A-F]{5,}')
            echo -e "$BASEOID.$1\nINTEGER\n${count}"
            ;;
    esac
}

# Parse for command-line arguments
while getopts 'ghns' options; do
    case "$options" in
        g) MODE='get' ;;
        n) MODE='next' ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done

shift $(($OPTIND-1))

if [ $# -ne 1 -o -z "$MODE" ]; then
    print_usage
    exit 1
fi

# Check for requested OID
OID=$1

if ! (echo $OID | grep -qE "^$BASEOID"); then
    echo "Error: base OID must begin with $BASEOID" >&2
    exit 1
fi

# Parse mount files
case ${OID#$BASEOID} in
    '')
        if [ "$MODE" == 'next' ]; then
            snmp_get 1
        fi
        ;;
    .1)
        if [ "$MODE" == 'get' ]; then
            snmp_get 1
        fi
        ;;
esac

exit 0
