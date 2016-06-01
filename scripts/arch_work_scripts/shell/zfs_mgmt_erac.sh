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

  ${f_bold}./$(basename ${0}) pool list${f_normal} [-u|--username LOGIN] [-f|--filer HOST]
    -u, --username    Username
    -f, --filer       Filer IP or FQDN


${f_bold}* Project *${f_normal}

  ${f_bold}./$(basename ${0}) project list${f_normal} [-u|--username LOGIN] [-t|--type TYPE]
    -u, --username    Username
    -t, --type        Data type. Possible values : iscsi, nfs


${f_bold}* iSCSI / LUN *${f_normal}

  ${f_bold}./$(basename ${0}) lun list${f_normal} [-u|--username LOGIN] [-f|--filer HOST] [-p|--project NAME] [-b|--brief]
    -u, --username    Username
    -f, --filer       Filer IP or FQDN
    -p, --project     Project name
    -b, --brief       Brief informations

  ${f_bold}./$(basename ${0}) lun add${f_normal} [-u|--username LOGIN] [-i|--instance DB] [-n|--nb NB_LUNS]
    -u, --username    Username
    -i, --instance    Instance name. Example: erac1pb1_data
    -n, --nb          Number of LUNs
      Example: ./zfs_mgmt.sh lun add -u n.martial -i erac1pb1_data -n 1
      Example: ./zfs_mgmt.sh lun add -u n.martial -i erac1pb1_index -n 2
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




# =================================================
#   Function : list LUNs from a project
# =================================================

_list_shares() {
  if [ 0 -eq $# ]; then _usage ; return 1 ; fi

  arg_username=''
  arg_filer=''
  arg_pool=''
  arg_project=''
  arg_brief=false

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -f|--filer)     arg_filer=${2} ; shift 2 ;;
      -z|--pool)      arg_pool=${2} ; shift 2 ;;
      -p|--project)   arg_project=${2} ; shift 2 ;;
      -b|--brief)     arg_brief=true ; shift ;;
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
  if ! _check_project -u ${arg_username} -f ${arg_filer} -z ${arg_pool} -p ${arg_project} ; then
    echo "* Project '${arg_project}' does not exist on ${arg_filer} / pool:${arg_pool}" ; return 1
  fi

  # Displays only shares names
  if [[ ${arg_brief} == true ]]; then
    ssh -T "${arg_username}"@"${arg_filer}" << EOF
script
run('cd /') ; run("shares set pool=${arg_pool}") ; run("shares select ${arg_project}") ;
shares = list() ; for (i=0; i<shares.length; ++i) { printf('%s\n', shares[i]); }
EOF

  # Displays shares properties
  else
    echo "Shares from project '${arg_project}' on ${arg_filer} :"
    ssh -T "${arg_username}"@"${arg_filer}" << EOF
cd /
shares set pool=${arg_pool}
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
  gen_multipath='gen_multipath_conf_erac.sh'
  filers_infos="${dir_cfg}/filers_iscsi.conf"
  dir_output='/tmp'
  arg_username=''
  arg_instance=''
  arg_nb=''

  while true ; do
    case "${1}" in
      -u|--username)  arg_username=${2} ; shift 2 ;;
      -i|--instance)  arg_instance=${2} ; shift 2 ;;
      -n|--nb)        arg_nb=${2} ; shift 2 ;;
      -h|--help)      _usage ; exit 0 ;;
      --)             shift ; break ;;
      *)              shift ; break ;;
    esac
  done

  # Required arguments
  if [ -z "${arg_username}" -o -z "${arg_instance}" -o -z "${arg_nb}" ]; then _usage ; return 1 ; fi
  if ! let "${arg_nb}" 2>/dev/null ; then echo "* Error: ${arg_nb} is not an integer" ; _usage ; return 1 ; fi

  # Check if Multipath script exists
  if [ ! -f "${gen_multipath}" ]; then
    echo -e "ERROR: script '${gen_multipath}' does not exist"
    return 1
  fi

  # Check if filers list exists
  if [ ! -f "${filers_infos}" ]; then
    echo -e "* Error: '${filers_infos}' is missing"
    return 1
  fi

  # Check if LUN configuration exist, otherwise list configuration files
  cfg="${dir_cfg}/${arg_instance}.conf"
  if [ ! -f "${cfg}" ]; then
    echo -e "* Error: '${cfg}' is missing \n* List of databases/grid :"
    ls ${dir_cfg} | awk -F'.' '{print "  - "$1}'
    return 1
  fi

  # Source LUN configuration
  source ${cfg}

  # Check expected parameters
  if [ -z "${INITIATOR_GROUP}" ]; then echo "* Error: missing parameter in '${cfg} : INITIATOR_GROUP" ; return 1 ; fi
  if [ -z "${TARGET_GROUP}" ];    then echo "* Error: missing parameter in '${cfg} : TARGET_GROUP" ;    return 1 ; fi
  if [ ${#FILERS[@]} -eq 0 ];     then echo "* Error: missing parameter in '${cfg} : FILERS" ;          return 1 ; fi
  if [ -z "${VOLSIZE}" ];         then echo "* Error: missing parameter in '${cfg} : VOLSIZE" ;         return 1 ; fi
  if [ -z "${VOLBLOCKSIZE}" ];    then echo "* Error: missing parameter in '${cfg} : VOLBLOCKSIZE" ;    return 1 ; fi
  if [ -z "${LOGBIAS}" ];         then echo "* Error: missing parameter in '${cfg} : LOGBIAS" ;         return 1 ; fi
  if [ -z "${COMPRESSION}" ];     then echo "* Error: missing parameter in '${cfg} : COMPRESSION" ;     return 1 ; fi
  if [ -z "${SPARSE}" ];          then echo "* Error: missing parameter in '${cfg} : SPARSE" ;          return 1 ; fi
  

  for key in ${!FILERS[@]}; do

    eval ${FILERS[${key}]}

    # Check expected parameters on specific filer
    if [ -z "${FILER}" ];   then echo "* Error: missing parameter in '${cfg} : FILER" ;   return 1 ; fi
    if [ -z "${POOL}" ];    then echo "* Error: missing parameter in '${cfg} : POOL" ;    return 1 ; fi
    if [ -z "${PROJECT}" ]; then echo "* Error: missing parameter in '${cfg} : PROJECT" ; return 1 ; fi
    if [ -z "${PREFIX}" ];  then echo "* Error: missing parameter in '${cfg} : PREFIX" ;  return 1 ; fi

    # Check host
    if ! _check_fqdn ${FILER} ; then return 1 ; fi

    # Check project
    if ! _check_project -u ${arg_username} -f ${FILER} -z ${POOL} -p ${PROJECT} ; then
      echo "* Project '${PROJECT}' does not exist on ${FILER}" ; return 1
    fi

    # Get last LUN index
    last_index=$(_list_shares -u ${arg_username} -f ${FILER} -z ${POOL} -p ${PROJECT} -b | sed "s/${PREFIX}_//" | sort -g | tail -1)
    [[ ${last_index} == '' ]] && last_index=0
    start_index=$((last_index + 1))
    stop_index=$((last_index + ${arg_nb} ))

    # Add LUNs
    for i in $(seq ${start_index} ${stop_index}); do
      lun="${PREFIX}_${i}"
      echo "* Adding LUN '${lun}' in project '${PROJECT}' on ${FILER}... "
      ssh -T "${arg_username}"@"${FILER}" << EOF
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

      # Status creation
      if [ $? -eq 0 ]; then
        echo 'OK'
      else
        echo 'Failed'
        nb_errors=$(( ${nb_errors} + 1 ))
      fi
    done
  done


  # eRAC name (ie. erac1pa1)
  erac_name=${arg_instance%%_*}

  # Generate Multipath configuration per filer for a specific eRAC (primary or standby)
  echo 'Generating Multipath configuration... please wait...'
  source ${filers_infos}
  for filer in ${!FILERS[@]}; do
    eval ${FILERS[${filer}]}
    tmp_results="${dir_output}/multipath_${erac_name}_${filer}.txt"
    ./${gen_multipath} -u ${arg_username} -f ${filer} -z ${POOL} -e ${erac_name} -U 1014 -G 1015 -M 660 -o ${tmp_results}
  done

  # Merge Multipath configurations
  merged_results="${dir_output}/multipath_${erac_name}_$(date +%Y.%m.%d).txt"
  header="###################\n# Alias multipath #\n###################\n# Add a multipath alias name for each LUN you add\n\nmultipaths {\n"
  footer="}\n# End database"
  echo -e ${header} > ${merged_results}
  cat ${dir_output}/multipath_${erac_name}_filer1[23]*.txt >> ${merged_results}
  echo -e ${footer} >> ${merged_results}

  if [ $? -eq 0 ]; then
    echo "INFO: File ${merged_results} created"
  else
    echo "ERROR: Could not generate ${merged_results}.txt"
  fi
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
      *)      _usage ; exit 1 ;;
    esac
    ;;

  lun)
    shift
    case "${1}" in
      list)   shift ; _list_shares ${@} ;;
      add)    shift ; _add_luns ${@} ;;
      *)      _usage ; exit 1 ;;
    esac
    ;;

  -h|--help) _usage ; exit 0 ;;
  *)         _usage ; exit 1 ;;
esac

