#!/usr/bin/env bash

# ZFS - Projects & LUNs creation



# ================================================
#   Function : usage
# ================================================

_usage() {
  f_bold="\033[01;37m"
  f_normal="\033[00m"
  echo -e "${f_bold}Description${f_normal}
  ZFS - Projects & shares creation
  Generate Multipath configuration after LUNs creation

${f_bold}Usage:${f_normal}
  ./$(basename ${0}) [-h] [options]


${f_bold}* Pool *${f_normal}

  ./$(basename ${0}) pool ${f_bold}list${f_normal} [-u|--username LOGIN] [-f|--filer HOST]
    -u, --username    Username
    -f, --filer       Filer IP or FQDN


${f_bold}* Project *${f_normal}

  ./$(basename ${0}) project ${f_bold}list${f_normal} [-u|--username LOGIN] [-t|--type TYPE]
    -u, --username    Username
    -t, --type        Data type. Possible values : iscsi, nfs

  ./$(basename ${0}) project ${f_bold}add${f_normal} [-u|--username LOGIN] [-t|--type TYPE] [-f|--filer HOST] [-p|--project NAME]
    -u, --username    Username
    -t, --type        Data type. Possible values : iscsi, nfs
    -f, --filer       Filer IP or FQDN
    -p, --project     Project name


${f_bold}* iSCSI / LUN *${f_normal}

  ./$(basename ${0}) lun ${f_bold}list${f_normal} [-u|--username LOGIN] [-f|--filer HOST] [-p|--project NAME] [-b|--brief]
    -u, --username    Username
    -f, --filer       Filer IP or FQDN
    -p, --project     Project name
    -b, --brief       Brief informations

  ./$(basename ${0}) lun ${f_bold}check${f_normal} [-u|--username LOGIN] [-f|--filer HOST] [-z|--pool NAME] [-p|--project NAME] [-l|--lun NAME]
    -u, --username    Username
    -f, --filer       Filer IP or FQDN
    -z, --pool        ZFS pool name
    -p, --project     Project name
    -l, --lun         LUN name

  ./$(basename ${0}) lun ${f_bold}add${f_normal} [-u|--username LOGIN] [-b|--db DB] [-t|--type LUN_TYPE] [-n|--nb NB_LUNS]
    -u, --username    Username
    -b, --db          Database name. Examples: bi, dba, dg, kelio, kimoce, paye, portal, grid_bi, dev1, uat1, ...
    -t, --type        LUN type. Examples: data, idx, lob, undo, temp, rdo1, rdo2, fra
    -n, --nb          Number of LUNs
      Example: ./zfs_mgmt.sh lun add -u n.martial -b dg -t idx -n 1
      Example: ./zfs_mgmt.sh lun add -u n.martial -b grid_dg -t grid -n 1


${f_bold}* NFS / Shares *${f_normal}
  
  ./$(basename ${0}) nfs ${f_bold}list${f_normal} [-u|--username LOGIN] [-f|--filer HOST] [-p|--project NAME] [-b|--brief]
    -u, --username    Username
    -f, --filer       Filer IP or FQDN
    -p, --project     Project name

  ./$(basename ${0}) nfs ${f_bold}add${f_normal} [-u|--username LOGIN] [-f|--filer HOST] [-p|--project NAME] [-s|--share NAME] [-q|--quota size] [-U|--uid UID] [-G|--gid GID] [-P|--perms]
    -u, --username    Username
    -f, --filer       Filer IP or FQDN
    -p, --project     Project name
    -s, --share       Share name
    -q, --quota       Quota. Suffixes: MG. Examples: 200M, 60G
    -U, --uid         User ID (= mount owner)
    -G, --gid         Group ID (= mount group owner)
    -P, --perms       Permissions. Example: 750
  "
}




# ================================================
#   Function : check FQDN/IP
# ================================================

_check_fqdn() {
  host "${1}" 2>&1 >/dev/null

  if [ $? -ne 0 ]; then
    echo "* Error: host '${1}' does not exist or is unreachable" ; return 1
  else
    return 0
  fi
}

_check_file() {
  if [ ! -f "${1}" ]; then
    echo -e "* Error: '${1}' is missing"
    return 1
  fi
  return 0
}


# ================================================
#   Function : list pools
# ================================================

_list_pools() {
  if [ 0 -eq $# ]; then _usage ; return 1 ; fi

  arg_username=''
  arg_filer=''

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -f|--filer)     arg_filer=${2} ; shift 2 ;;
      -h|--help)      _usage ; exit 0 ;;
      --)             shift ; break ;;
      *)              shift ; break ;;
    esac
  done

  # Required arguments
  if [ -z "${arg_username}" -o -z "${arg_filer}" ]; then _usage ; return 1 ; fi

  # Check host
  if ! _check_fqdn ${arg_filer} ; then return 1 ; fi

  # ZFS commands
  echo "Pools on ${arg_filer} :"
     ssh -T "${arg_username}"@"${arg_filer}" << EOF
script
run('cd /');
run('status storage');
pools = list();
for (i=0; i < pools.length; ++i) {
        printf(' * %s \n', pools[i]);
}
.
EOF
}




# ================================================
#   Function : list projects
# ================================================

_list_projects() {
  if [ 0 -eq $# ]; then _usage ; return 1 ; fi

  declare -A FILERS
  arg_username=''
  cfg=''

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -t|--type)      arg_sharetype="${arg_sharetype} ${2}" ; shift 2 ;;
      -h|--help)      _usage ; exit 0 ;;
      --)             shift ; break ;;
      *)              shift ; break ;;
    esac
  done

  # Required arguments
  if [ -z "${arg_username}" -o -z "${arg_sharetype}" ]; then _usage ; return 1 ; fi

  for _type in $arg_sharetype; do
    cfg="${dir_cfg}/filers_${_type}.conf"

    # Check and source configuration
    if ! _check_file ${cfg} ; then break ; fi
    source ${cfg}

    for filer in ${!FILERS[@]}; do
      # Get filers' properties
      eval ${FILERS[${filer}]}

      # ZFS commands
      echo "${_type} projects on ${filer} :"
      ssh -T "${arg_username}"@"${filer}" << EOF
script
run('cd /');
run('shares set pool=${ZPOOL}');
run('shares');
projects = list();
for (i=0; i < projects.length; ++i) {
        printf(' * %s \n', projects[i]);
}
.
EOF
      echo
    done
  done
}

# ================================================
#   Function : check if project exists
# ================================================

_check_project() {
  arg_username=''
  arg_filer=''
  arg_pool=''
  arg_project=''

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -f|--filer)     arg_filer=${2} ; shift 2 ;;
      -z|--pool)      arg_pool=${2} ; shift 2 ;;
      -p|--project)   arg_project=${2} ; shift 2 ;;
      -h|--help)      _usage ; exit 0 ;;
      --)             shift ; break ;;
      *)              shift ; break ;;
    esac
  done

  # Required arguments
  if [ -z "${arg_username}" -o -z "${arg_filer}" -o -z "${arg_pool}" -o -z "${arg_project}" ]; then _usage ; return 1 ; fi

  # Check host
  if ! _check_fqdn ${arg_filer} ; then return 1 ; fi

  # Check if project exists
  res=$( ssh -T "${arg_username}"@"${arg_filer}" << EOF
cd /
shares set pool=${arg_pool}
shares select ${arg_project}
EOF
  )

  return $?

}

# ================================================
#   Function : add a project
# ================================================

_add_project() {
  if [ 0 -eq $# ]; then _usage ; return 1 ; fi

  declare -A FILERS
  arg_username=''
  arg_sharetype=''
  arg_filer=''
  arg_project=''

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -t|--type)      arg_sharetype="${2}" ; shift 2 ;;
      -f|--filer)     arg_filer=${2} ; shift 2 ;;
      -p|--project)   arg_project=${2} ; shift 2 ;;
      -h|--help)      _usage ; exit 0 ;;
      --)             shift ; break ;;
      *)              shift ; break ;;
    esac
  done

  # Required arguments
  if [ -z "${arg_username}" -o -z "${arg_sharetype}" -o -z "${arg_filer}" -o -z "${arg_project}" ]; then _usage ; return 1 ; fi

  cfg="${dir_cfg}/filers_${arg_sharetype}.conf"

  # Check and source configuration
  if ! _check_file ${cfg} ; then break ; fi
  source ${cfg}

  # Get filers' properties
  eval ${FILERS[${arg_filer}]}

  # Check if project exists
  if _check_project -u ${arg_username} -f ${arg_filer} -z ${ZPOOL} -p ${arg_project} ; then
    echo "* Project '${arg_project}' already exists on ${arg_filer}@${arg_pool}" ; return 1
  fi

  # Add project
  echo -n "* Adding project '${arg_project}' on ${arg_filer}... "
  ssh -T "${arg_username}"@"${arg_filer}" << EOF
cd /
shares set pool=${ZPOOL}
shares project ${arg_project}
commit
EOF
  [ $? -eq 0 ] && echo 'OK' || echo 'Failed'
}




# =================================================
#   Function : list shares (LUN/NFS) from a project
# =================================================

_list_shares() {
  if [ 0 -eq $# ]; then _usage ; return 1 ; fi

  declare -A FILERS
  arg_username=''
  arg_sharetype=''
  arg_filer=''
  arg_project=''
  arg_brief=false

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -t|--type)      arg_sharetype="${2}" ; shift 2 ;;
      -f|--filer)     arg_filer=${2} ; shift 2 ;;
      -p|--project)   arg_project=${2} ; shift 2 ;;
      -b|--brief)     arg_brief=true ; shift ;;
      -h|--help)      _usage ; exit 0 ;;
      --)             shift ; break ;;
      *)              shift ; break ;;
    esac
  done

  # Required arguments
  if [ -z "${arg_username}" -o -z "${arg_sharetype}" -o -z "${arg_filer}" -o -z "${arg_project}" ]; then _usage ; return 1 ; fi

  cfg="${dir_cfg}/filers_${arg_sharetype}.conf"

  # Check host
  if ! _check_fqdn ${arg_filer} ; then return 1 ; fi

  # Check and source configuration
  if ! _check_file ${cfg} ; then break ; fi
  source ${cfg}

  # Get filers' properties
  eval ${FILERS[${arg_filer}]}

  # Check if project exists
  if ! _check_project -u ${arg_username} -f ${arg_filer} -z ${ZPOOL} -p ${arg_project} ; then
    echo "* Project '${arg_project}' does not exist on ${arg_filer}" ; return 1
  fi

  # Displays only shares names
  if [[ ${arg_brief} == true ]]; then
    ssh -T "${arg_username}"@"${arg_filer}" << EOF
script
run('cd /') ; run("shares set pool=${ZPOOL}") ; run("shares select ${arg_project}") ;
shares = list() ; for (i=0; i<shares.length; ++i) { printf('%s\n', shares[i]); }
EOF

  # Displays shares properties
  else
    echo "Shares from project '${arg_project}' on ${arg_filer} :"
    ssh -T "${arg_username}"@"${arg_filer}" << EOF
cd /
shares set pool=${ZPOOL}
shares select ${arg_project} list
EOF
  fi
}

# ================================================
#   Function : add LUNs
# ================================================

_add_luns() {
  if [ 0 -eq $# ]; then _usage ; return 1 ; fi

  declare -A FILERS
  declare -A LUNS
  nb_errors=0
  gen_multipath='gen_multipath_conf.sh'
  arg_username=''
  arg_db=''
  arg_type=''
  arg_nb=''

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -b|--db)        arg_db=${2} ; shift 2 ;;
      -t|--type)      arg_type=${2} ; shift 2 ;;
      -n|--nb)        arg_nb=${2} ; shift 2 ;;
      -h|--help)      _usage ; exit 0 ;;
      --)             shift ; break ;;
      *)              shift ; break ;;
    esac
  done
  # Required arguments
  if [ -z "${arg_username}" -o -z "${arg_db}" -o -z "${arg_type}" -o -z "${arg_nb}" ]; then _usage ; return 1 ; fi
  if ! let "${arg_nb}" 2>/dev/null ; then echo "* Error: ${arg_nb} is not an integer" ; _usage ; return 1 ; fi

  # Check if LUN configuration exist
  cfg="${dir_cfg}/${arg_db}.conf"
  if [ ! -f "${cfg}" ]; then
    echo -e "* Error: '${cfg}' is missing \n* List of databases/grid :"
    ls ${dir_cfg} | awk -F'.' '{print "  - "$1}'
    return 1
  fi

  # Source LUN configuration
  source ${cfg}

  # Check if script exists
  if [ ! -f "${gen_multipath}" ]; then
    echo -e "ERROR: script '${gen_multipath}' does not exist"
    return 1
  fi

  # Check expected parameters
  if [ ${#FILERS[@]} -eq 0 -o -z "${INITIATOR_GROUP}" -o -z "${TARGET_GROUP}" -o -z "${PROJECT}" ]; then
    echo "* Error: missings parameter(s) in '${cfg}' (FILERS|INITIATOR_GROUP|TARGET_GROUP|PROJECT)" ; return 1
  fi
 
  # Check if LUN type (ie. idx, rdo) is defined
  lun_types=${!LUNS[@]}
  if ! $(echo ${lun_types} | grep -q "${arg_type}"); then echo "* Error: LUN type '${arg_type}' not defined in ${cfg}" ; return 1 ; fi

  # Get LUN properties
  params=${LUNS[${arg_type}]}
  eval ${params}
  if [ -z "${VOLSIZE}" -o -z "${VOLBLOCKSIZE}" -o -z "${LOGBIAS}" -o -z "${COMPRESSION}" -o -z "${SPARSE}" -o -z "${PREFIX}" ]; then
    echo "* Error: missings parameter(s) in '${cfg}' (VOLSIZE|VOLBLOCKSIZE|LOGBIAS|COMPRESSION|SPARSE|PREFIX)" ; return 1
  fi

  # LUN creation on each filer
  for f in ${!FILERS[@]}; do
    eval ${FILERS[${f}]}

    # Check expected parameters
    if [ -z "${FILER}" -o -z "${POOL}" ]; then
      echo "* Error: missings parameter(s) in '${cfg}' (FILER|POOL)" ; return 1
    fi

    # Check host
    if ! _check_fqdn ${FILER} ; then return 1 ; fi

    # Check project
    if ! _check_project -u ${arg_username} -f ${FILER} -z ${POOL} -p ${PROJECT} ; then
      echo "* Project '${PROJECT}' does not exist on ${FILER}" ; return 1
    fi

    # Get last LUN index
    last_index=$(_list_shares -u ${arg_username} -t iscsi -f ${FILER} -p ${PROJECT} -b | sed "s/${PREFIX}_//" | sort -g | tail -1)
    [[ ${last_index} == '' ]] && last_index=0
    start_index=$((last_index + 1))
    stop_index=$((last_index + ${arg_nb} ))

    # Add LUNs
    for i in $(seq ${start_index} ${stop_index}); do
      lun="${PREFIX}_${i}"
      echo "* Adding LUN '${lun}' in project '${PROJECT}' on ${FILER}... "
      ssh -T "${arg_username}"@"${arg_filer}" << EOF
cd /
shares set pool=${POOL}
shares select ${PROJECT}
lun ${lun}
set compression=${COMPRESSION}
set logbias=${LOGBIAS}
set volblocksize=${VOLBLOCKSIZE}
set volsize=${VOLSIZE}
set sparse=${SPARSE}
set targetgroup=${TARGET_GROUP}
set initiatorgroup=${INITIATOR_GROUP}
set status=online
commit
EOF
      if [ $? -eq 0 ]; then
        echo 'OK'
      else
        echo 'Failed'
        nb_errors=$(( ${nb_errors} + 1 ))
      fi
    done
  done

  # Generate Multipath configuration
  echo -e "\n* INFO: LUN creation report : ${nb_errors} error"
  if [ ${nb_errors} -eq 0 ]; then
    for f in ${!FILERS[@]}; do
      eval ${FILERS[${f}]}

      ./${gen_multipath} -u ${arg_username} -f ${FILER} -z ${POOL} -p ${PROJECT} -U 1002 -G 1000 -o /tmp/multipath-${arg_db}-${FILER}.txt
      if [ $? -eq 0 ]; then
        echo "INFO: File /tmp/multipath-${arg_db}-${FILER}.txt created"
      else
        echo "ERROR: Could not generate /tmp/multipath-${arg_db}-${FILER}.txt"
      fi
    done
  fi
}




# ================================================
#   Function : add NFS share
# ================================================

_add_nfs() {
  if [ 0 -eq $# ]; then _usage ; return 1 ; fi

  declare -A FILERS
  arg_username=''
  arg_filer=''
  arg_project=''
  arg_share=''
  arg_quota=''
  arg_uid=''
  arg_gid=''
  arg_perms=''

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -f|--filer)     arg_filer=${2} ; shift 2 ;;
      -p|--project)   arg_project=${2} ; shift 2 ;;
      -s|--share)     arg_share=${2} ; shift 2 ;;
      -q|--quota)     arg_quota=${2} ; shift 2 ;;
      -U|--uid)       arg_uid=${2} ; shift 2 ;;
      -G|--gid)       arg_gid=${2} ; shift 2 ;;
      -P|--perms)     arg_perms=${2} ; shift 2 ;;
      -h|--help)      _usage ; exit 0 ;;
      --)             shift ; break ;;
      *)              shift ; break ;;
    esac
  done

  # Required arguments
  if [ -z "${arg_username}" \
    -o -z "${arg_filer}" -o -z "${arg_project}" \
    -o -z "${arg_share}" -o -z "${arg_quota}" -o -z "${arg_uid}" -o -z "${arg_gid}" -o -z "${arg_perms}" ]; then _usage ; return 1 ; fi

  cfg="${dir_cfg}/filers_nfs.conf"

  # Check host
  if ! _check_fqdn ${arg_filer} ; then return 1 ; fi

  # Check and source configuration
  if ! _check_file ${cfg} ; then break ; fi
  source ${cfg}

  # Get filers' properties
  eval ${FILERS[${arg_filer}]}

  # Check if project exists
  if ! _check_project -u ${arg_username} -f ${arg_filer} -z ${ZPOOL} -p ${arg_project} ; then
    echo "* Project '${arg_project}' does not exist on ${arg_filer}" ; return 1
  fi

  # Check arguments
  #if ! let "${arg_uid}" 2>/dev/null ; then echo "* Error: UID value '${arg_uid}' is not an integer" ; return 1 ; fi
  #if ! let "${arg_gid}" 2>/dev/null ; then echo "* Error: GID value '${arg_gid}' is not an integer" ; return 1 ; fi
  if ! let "${arg_perms}" 2>/dev/null ; then echo "* Error: permissions value '${arg_perms}' is not an integer" ; return 1 ; fi


  echo "* Adding NFS share '${arg_share}' in project '${arg_project}' on ${arg_filer}..."
  ssh -T "${arg_username}"@"${arg_filer}" << EOF
cd /
shares set pool=${ZPOOL}
shares select ${arg_project}
filesystem ${arg_share}
set mountpoint=/export/${arg_share}
set quota=${arg_quota}
set root_user=${arg_uid}
set root_group=${arg_gid}
set root_permissions=${arg_perms}
commit
EOF
  [ $? -eq 0 ] && echo 'OK' || echo 'Failed'
}




# ================================================
#   Main
# ================================================

dir_cfg='conf.d'

if [ 0 -eq $# ]; then _usage ; exit 1 ; fi

case "${1}" in
  pool)
    shift
    case "${1}" in
      list)   shift ; _list_pools ${@} ;;
      *)      _usage ; exit 1 ;;
    esac
    ;;

  project)
    shift
    case "${1}" in
      list)   shift ; _list_projects ${@} ;;
      add)    shift ; _add_project ${@} ;;
      *)      _usage ; exit 1 ;;
    esac
    ;;

  lun)
    shift
    case "${1}" in
      list)   shift ; _list_shares ${@} -t iscsi ;;
      add)    shift ; _add_luns ${@} ;;
      *)      _usage ; exit 1 ;;
    esac
    ;;

  nfs)
    shift
    case "${1}" in
      list)   shift ; _list_shares ${@} -t nfs ;;
      add)    shift ; _add_nfs ${@} ;;
      *)      _usage ; exit 1 ;;
    esac
    ;;

  -h|--help) _usage ; exit 0 ;;
  *)         _usage ; exit 1 ;;
esac

