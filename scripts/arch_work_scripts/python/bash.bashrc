####################################
## THIS FILE IS MANAGED BY PUPPET ##
####################################
# System-wide .bashrc file for interactive bash(1) shells.

# To enable the settings / commands in this file for login shells as well,
# this file has to be sourced in /etc/profile.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, overwrite the one in /etc/profile)
#PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# Completion
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# create /mnt/share/USER if needed
# Only for UID > 20000
if [ "$EUID" -ge "20000" ]; then
  [ ! -d /home/$LOGNAME/tmp ] && mkdir -p /home/$LOGNAME/tmp 
  [ ! -d /mnt/share/dev/$LOGNAME/xdebug ] && mkdir -p /mnt/share/dev/$LOGNAME/xdebug
  [ ! -d /home/$LOGNAME/xdebug ] && mkdir -p /home/$LOGNAME/xdebug
fi

# Commented out, don't overwrite xterm -T "title" -n "icontitle" by default.
# If this is an xterm set the title to user@host:dir
#case "$TERM" in
#xterm*|rxvt*)
#    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
#    ;;
#*)
#    ;;
#esac

# enable bash completion in interactive shells
#if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
#    . /etc/bash_completion
#fi

# if the command-not-found package is installed, use it
#if [ -x /usr/lib/command-not-found -o -x /usr/share/command-not-found ]; then
#	function command_not_found_handle {
#	        # check because c-n-f could've been removed in the meantime
#                if [ -x /usr/lib/command-not-found ]; then
#		   /usr/bin/python /usr/lib/command-not-found -- $1
#                   return $?
#                elif [ -x /usr/share/command-not-found ]; then
#		   /usr/bin/python /usr/share/command-not-found -- $1
#                   return $?
#		else
#		   return 127
#		fi
#	}
#fi

#History with date
export HISTCONTROL=ignoredups
#export HISTIGNORE='ls:ll:cl:l'
export HISTFILESIZE=50000
export HISTSIZE=1000
export HISTTIMEFORMAT="%d/%m/%Y %H:%M:%S "

# Colorize by datacenter
HOST=($(hostname -f|tr "[:lower:]" "[:upper:]"|sed 's/\./ /g'))
DC=${HOST[4]}
PFS=${HOST[2]}
PFS_ENV=${HOST[3]}

# colors available
color_normal="\[\033[0;00m\]"
color_darkred="\[\033[0;31m\]"
color_darkgreen="\[\033[0;32m\]"
color_darkblue="\[\033[0;34m\]"
color_darkyellow="\[\033[0;33m\]"
color_darkblue="\[\033[0;34m\]"
color_darkmagenta="\[\033[0;35m\]"
color_darkcyan="\[\033[0;36m\]"
color_reset="\[\033[00;00m\]"

case "$PFS_ENV" in
	PROD)
		COLOR_ENV=$color_darkyellow
	;;
	*)
		COLOR_ENV=$color_darkgreen
	;;
esac

case "$DC" in
	STD)
		export PS1="[$PFS]${COLOR_ENV}[$PFS_ENV]${color_darkred}[$DC]${color_reset} \h:\w\\$ " ;;
	VIT)
		export PS1="[$PFS]${COLOR_ENV}[$PFS_ENV]${color_darkblue}[$DC]${color_reset} \h:\w\\$ " ;;
	*)
		export PS1="[$PFS]${COLOR_ENV}[$PFS_ENV]${color_darkmagenta}[$DC]${color_reset} \h:\w\\$ " ;;
esac

if [ "$TERM" != "dumb" ]; then
    eval "`dircolors -b`"
    alias ls='ls --color=auto'
    #alias dir='ls --color=auto --format=vertical'
    #alias vdir='ls --color=auto --format=long'
fi

# some more ls aliases
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear; ls'
alias cll='clear; ll'

#alias pup='puppetd agent --test'
alias st='dmidecode -s system-serial-number'
alias model='dmidecode -s system-product-name'

# Puppet
function pup {
if [ -z "$1" ]; then
    puppetd agent --test | grep -v info:
elif [ "$1" ]; then
    puppetd agent --test $@
fi
}

