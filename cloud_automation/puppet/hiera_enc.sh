# author:      lapin
# Description: Simple script that uses HIERA as an ENC.
#              It fetches 4 variables from a config file to
#              build the hierarchy.
#

###############################################################################
### Statics
###############################################################################
# These statics are defined according to the BSD syslog protocol (RFC 3164)
S_EMERG=0 # Emergency: system is unusable
S_ALERT=1 # Alert: action must be taken immediately
S_CRITIC=2 # Critical: critical conditions
S_ERROR=3 # Error: error conditions
S_WARNING=4 # Warning: warning conditions
S_NOTICE=5 # Notice: normal but significant condition
S_INFO=6 # Informational: informational messages
S_DEBUG=7 # Debug: debug-level messages

LOG_LEVEL=${S_DEBUG} # Log level of the script possible values are defined in static
SCRIPT_NAME=$(basename $0) # get the name of the script without directory path
LOG_FACILITY='user' # Facility to use via the system logger
HIERA_BIN='/opt/puppetlabs/bin/hiera' # Hiera binary
HIERA_NODES_YML='/etc/puppetlabs/code/hiera_nodes.yaml' # Hiera nodes configuration file
NODES_PATH='/etc/puppetlabs/code/environments/production/hieradata/certname' # Path to look for node definition. Could be separated (ie: /etc/puppetlabs/code/environments/production/hieradata/nodes

###############################################################################
### Functions
###############################################################################
script_log(){
  # If the log level is correct, this function will log the message through the system logger
  # $1 is the facility of the message
  # $2 is the criticity of the message
  # $3 is the tag of the message
  # $4 argument is the body of the log
  # $5 must be a non empty file if provided
  #
  # Error codes:
  # return=1: wrong number of arguments
  # return=2: the provided syslog facility is not recognized

  # test is nb argument is ok
  if [ $# -lt 4 ] || [ $# -gt 5 ];then
    echo 'script_log(): expecting 4 or 5 arguments, '
    return 1
  fi

  # Check if the criticallity is correct
  if [ $2 -le ${S_DEBUG} ] && [ $2 -ge ${S_EMERG} ]; then
    l_crit=$2
  else
    echo "script_log(): expecting criticallity [0:7], provided value: $2"
    return 2
  fi

  l_tag=$3

  # Limit the logging process to the log level defined in global variables
  if [ ${l_crit} -le ${LOG_LEVEL} ];then
    logger -p $1.${l_crit} -t ${l_tag} "$4"
    # make sure $4 is a non empty file
    if [ -s "$5" ];then
      # Send the content of the file through the logger
      cat $5 | logger -p $1.${l_crit} -t ${l_tag}
    fi
  fi
} # End: script_log()

get_node_var(){
  # Function that fetch the content of a requested variable from a configuration file.
  # $1 must be a variable name
  # $2 must be a configuration file
  # $3 is a log file to store error messages
  l_node_var_name=$1
  l_node_file=$2
  l_log_file=$3

  l_return=0 # By default considers everything is fine

  l_node_var_content=$(grep "^[[:space:]]*[^#]*[[:space:]]*${l_node_var_name}:.*$" ${l_node_file} 2>${l_log_file} | sed -e "s/^.*'\(.*\)'.*$/\1/")
  # if the grep failed or the result is empty
  if [ ${PIPESTATUS[0]} -ne 0 ] || [ -z ${l_node_var_content} ];then
    script_log ${LOG_FACILITY} ${S_ERROR} ${SCRIPT_NAME} "${FUNCNAME[0]}: Failed to fetch content of the ${l_node_var_name} variable" ${l_log_file}
    # Doing some cleaning
    cleanup ${l_log_file}
    # Could not get environment, exit in error
    l_return=80
  else
    script_log ${LOG_FACILITY} ${S_DEBUG} ${SCRIPT_NAME} "${FUNCNAME[0]}: Fetched ${l_node_var_name} = ${l_node_var_content}"
    echo ${l_node_var_content}
  fi

  return ${l_return}
} # End: get_node_var()

cleanup(){
  # Purging provided file(s) in arguments
  # $1 is the file to purge

  l_return=0 # By default cconsider ok

  if [ $# -ne 1 ];then
    script_log ${LOG_FACILITY} ${S_ERROR} ${SCRIPT_NAME} 'script_log(): expecting 1 argument '
    l_return=100
  fi
  l_file=$1
  if [ -f ${l_file} ];then
    script_log ${LOG_FACILITY} ${S_INFO} ${SCRIPT_NAME} "Purging temporaty log file"
    script_log ${LOG_FACILITY} ${S_DEBUG} ${SCRIPT_NAME} "Running: rm -f ${l_file} >/dev/null 2>&1"
    rm -f ${l_file} >/dev/null 2>&1
    if [ $? -ne 0 ];then
      script_log ${LOG_FACILITY} ${S_ERROR} ${SCRIPT_NAME} "Error: failed to purge ${l_file}"
      l_return=101
    fi
  fi

  return ${l_return}
} # End: cleanup()

quit_script(){
  # This function is called after a signal has been trapped.
  # It purges the file provided in argument with the cleanup function
  # and exit the script.
  # $1: Must be a file

  l_last_retrun=$?
  l_file=$1

  # Function call
  cleanup ${l_file}
  l_return=$?

  # Removing the EXIT signal from trap so the script can end normaly
  trap - EXIT

  exit 60

} # End: quit_script()

###############################################################################
### Main
###############################################################################

script_log ${LOG_FACILITY} ${S_NOTICE} ${SCRIPT_NAME} 'Starting'

script_log ${LOG_FACILITY} ${S_INFO} ${SCRIPT_NAME} 'Creating temporary log file'
script_log ${LOG_FACILITY} ${S_DEBUG} ${SCRIPT_NAME} 'Running: tmpLogFile=$(mktemp)'
tmpLogFile=$(mktemp) # Create a temporary log file that will store the result of each command
if [ $? -ne 0 ];then
  script_log ${LOG_FACILITY} ${S_ERROR} ${SCRIPT_NAME} 'Error: failed to create temporaty log file'
  exit 1
fi
script_log ${LOG_FACILITY} ${S_DEBUG} ${SCRIPT_NAME} "${tmpLogFile} has been generated"

script_log ${LOG_FACILITY} ${S_DEBUG} ${SCRIPT_NAME} 'Setting signals trap on '
trap "cleanup ${tmpLogFile}" EXIT
trap "quit_script ${tmpLogFile}" SIGINT SIGTERM SIGQUIT

# Get params
NODE=${1%%.*}
NODE_FILE="${NODES_PATH}/${NODE}.yaml"

# Get node variables to use into hiera hierarchy
NODE_ENVIRONMENT=$(get_node_var 'hiera_environment' ${NODE_FILE} ${tmpLogFile})
NODE_LOCATION=$(get_node_var 'hiera_location' ${NODE_FILE} ${tmpLogFile})
NODE_DOMAIN=$(get_node_var 'hiera_domain' ${NODE_FILE} ${tmpLogFile})
NODE_ROLE=$(get_node_var 'hiera_role' ${NODE_FILE} ${tmpLogFile})

# Get environment from hiera fed by YAML
NODE_CLASSES=$(${HIERA_BIN} classes ::hostname=${NODE} --config ${HIERA_NODES_YML} | sed -r 's/(\[|\]|"|,)//g')
if [[ "${NODE_CLASSES}" != "nil" && -n ${NODE_CLASSES} ]];then
  script_log ${LOG_FACILITY} ${S_DEBUG} ${SCRIPT_NAME} "Fetched classes = ${NODE_CLASSES}"
else
  # Could not get classes, exit in error
  exit 1
fi

# Echo YAML output
echo '---'
echo "classes:"
for tmp_class in ${NODE_CLASSES}; do
  echo "- ${tmp_class}"
done

# Print only if all variables found
if [ -n "${NODE_ENVIRONMENT}" ] && [ -n "${NODE_LOCATION}" ] && [ -n "${NODE_DOMAIN}" ] && [ -n "${NODE_ROLE}" ];then
  echo "parameters:"
  echo "  enc_env: ${NODE_ENVIRONMENT}"
  echo "  enc_loc: ${NODE_LOCATION}"
  echo "  enc_dom: ${NODE_DOMAIN}"
  echo "  enc_role: ${NODE_ROLE}"
fi

# Doing some cleaning
cleanup ${tmpLogFile}

script_log ${LOG_FACILITY} ${S_NOTICE} ${SCRIPT_NAME} 'End'
exit 0

