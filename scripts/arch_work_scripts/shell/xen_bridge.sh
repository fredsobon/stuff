#!/usr/bin/env bash

#
# Xen Bridge Management
#
# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/usrlocal/files/common/tool/virt/bin/xen_bridge.sh $
#


# ================================================
#   Variables
# ================================================

NET_FILE='/etc/network/interfaces'
NET_DIR='/etc/network/interfaces.d'
XEN_FILE='/etc/xen/scripts/multi-network-bridge'

VLAN=0

ARG_SETUP=false
ARG_CREATE=false
ARG_DELETE=false


# ================================================
#   Function : _usage
# ================================================

_usage() {
  echo -e "Description: Xen Bridge management \n
Usage: ${0} [-h] [option] [vlan_number] \n
Options :
  -c, --create        Create a bridge
  -d, --delete        Delete a bridge
  -h, --help          Show this help
  -l, --list          List brigdes
  -s, --setup         Set up network and bridge configuration
  "
}


# ================================================
#   Functions : generate configurations
# ================================================

_setupCfg() {
  # Create interfaces directory
  if [ ! -d "${NET_DIR}" ]; then
    echo "Creating '${NET_DIR}' folder..."
    mkdir "${NET_DIR}"
  fi

  # Include xenbr*.cfg files in /etc/network/interfaces
  if ! $( grep -q "${NET_DIR}" "${NET_FILE}" ); then
    echo "Include ${NET_DIR}/*.cfg in ${NET_FILE} file..."
    echo -e "\nsource ${NET_DIR}/*.cfg" >> "${NET_FILE}"
  fi

  # VLAN support
  /sbin/modprobe 8021q

  # Reinitialize multi-network-bridge script if wanted
  if [ -e "${XEN_FILE}" ]; then
    echo -e "${XEN_FILE} file already exists. Current configuration :"
    cat ${XEN_FILE} | sed 's/^/ | /'
    echo -en "\nWould you like to reinitialize it (all bridges will be removed!!) [y/n] : "
    read choice
    case "${choice}" in
      y|Y|o|O) ;;
      *) exit 0 ;;
    esac
  fi

  # multi-network-bridge configuration
  echo "Creating ${XEN_FILE} file..."
  cfg="#!/usr/bin/env bash
\ndir=\$(dirname "\$0")
\n\"\$dir/network-bridge\" \"\$@\" vifnum=0 netdev=eth0 bridge=eth0
\n# Bridges"
  echo -e "${cfg}" > "${XEN_FILE}"
  chmod +x "${XEN_FILE}"
}


_genInterfaceCfg() {
  vlan="${1}"

  eth0_ip=$(hostname -i)
  eth0_lastByte=${eth0_ip##*.}

  br_file="${NET_DIR}/${br}.cfg"
  br_cfg="\n# Bridge : xenbr${vlan}
\nauto eth0.${vlan}
\niface eth0.${vlan} inet manual
\n\tvlan-raw-device eth0
\nauto xenbr${vlan}
\niface xenbr${vlan} inet static
\n\tbridge-ports eth0.${vlan} \n\tbridge_stp off \n\taddress 10.3.${vlan}.${eth0_lastByte}
\n\tnetmask 255.255.255.0 \n\tbroadcast 10.3.${vlan}.255 \n\tnetwork 10.3.${vlan}.0"

  echo "Adding xenbr${vlan} configuration in ${br_file} file..."
  echo -e ${br_cfg} >> "${br_file}" || echo '...failed !'
}


_genXenCfg() {
  vlan="${1}"

  br_cfg="\"\$dir/network-bridge\" \"\$@\" vifnum=${vlan} netdev=eth0.${vlan} bridge=xenbr${vlan}"

  echo "Adding xenbr${vlan} configuration in ${XEN_FILE} file..."
  echo -e ${br_cfg} >> ${XEN_FILE} || echo '...failed !'
}


# ================================================
#   Function : create bridge
# ================================================

_createBr() {
  vlan="${1}"
  br="xenbr${vlan}"
  br_file="${NET_DIR}/${br}.cfg"

  # Add bridge in network interface configuration
  if [ -f "${br_file}" ]; then
    echo "* Bridge '${br}' already defined in ${br_file} *"
  else
    _genInterfaceCfg "${vlan}"
  fi

  # Add bridge in 'multi-network-bridge' configuration
  if $(grep -q "${br}" "${XEN_FILE}"); then
    echo "* Bridge '${br}' already defined in ${XEN_FILE} *"
  else
    _genXenCfg "${vlan}"
  fi

  # Bring bridge up
  echo "Bringing ${br} up..."
  ifup "${br}"
  echo
  brctl show
}


# ================================================
#   Function : delete bridge
# ================================================

_deleteBr() {
  vlan="${1}"
  br="xenbr${vlan}"
  br_file="${NET_DIR}/${br}.cfg"

  # Bring bridge down
  echo "Bringing ${br} down..."
  ifdown "${br}"

  # Delete bridge from network interface configuration
  if [ ! -f "${br_file}" ]; then
    echo "* Bridge '${br}' not defined in ${NET_FILE} *"
  else
    echo "Deleting ${br_file} file..."
    rm "${br_file}" || echo '...failed !'
  fi

  # Delete bridge from 'multi-network-bridge' configuration
  if ! $(grep -q "${br}" "${XEN_FILE}"); then
    echo "* Bridge '${br}' not defined in ${XEN_FILE} *"
  else
    echo "Deleting ${br} configuration from ${XEN_FILE} file..."
    sed -i "/.*${br}.*/d" ${XEN_FILE} || echo '...failed !'
  fi
}


# ================================================
#   Get options
# ================================================

# Options
SHORT_OPTS='c:d:slh'
LONG_OPTS='create:,delete:,setup,list,help'

# Get options
ARGS=$( getopt --options $SHORT_OPTS --long $LONG_OPTS -- "$@" 2>/dev/null )
if [ $? -ne 0 ]; then
  _usage
  exit 1
fi
eval set -- "$ARGS"

while true; do
  case "${1}" in
    -c|--create) ARG_CREATE=true; VLAN="${2}" ; shift 2 ;;
    -d|--delete) ARG_DELETE=true; VLAN="${2}" ; shift 2 ;;
    -s|--setup)  ARG_SETUP=true; shift ;;
    -l|--list)   brctl show ; exit 0 ;;
    -h|--help)   _usage ; exit 0 ;;
    --)          shift ; break ;;
    *)           shift ; break ;;
  esac
done


# ================================================
#   Checks
# ================================================

# Required option
if [[ "${ARG_CREATE}" == false && "${ARG_DELETE}" == false && "${ARG_SETUP}" == false ]]; then
  echo -e "* Error: missing arguments ! *\n"
  _usage
  exit 1
fi

# Check if VLAN value is numeric
if ( [[ "${ARG_CREATE}" == true || "${ARG_DELETE}" == true ]] && ! let "${VLAN}" ) ; then
  echo -e "* Error: illegal VLAN number !\n"
  _usage
  exit 1
fi



# ================================================
#   Main..
# ================================================

case true in
  "${ARG_CREATE}") _createBr "${VLAN}" ;;
  "${ARG_DELETE}") _deleteBr "${VLAN}" ;;
  "${ARG_SETUP}") _setupCfg ;;
esac

