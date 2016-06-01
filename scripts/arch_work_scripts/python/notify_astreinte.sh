#!/bin/bash

# ChangeLog:
# 28/01/2015 - dlarquey     Add the LOG_ALERT mode for logging all alerts into a log file
# 28/01/2015 - dlarquey     Enable the PAGE mode during holidays
# 23/01/2015 - dlarquey     Add the mode for disabling all notifications
# 20/01/2015 - dlarquey     Allow email notifications in NOPAGE mode. Add debug and force mode, add the help
# 19/01/2015 - dlarquey     Add the NOPAGE mode during the week and enable it
#                           Disable pages for UAT

debug() {
    [ $ARG_DEBUG -eq 1 ] || return
    echo "$*"
}

log_alert() {
# FORMAT:
# [Date,Day,DayOfWeek|Timestamp|Team|TimePeriod|AlertMode|AlertMessage
    [ $LOG_ALERT -eq 1 ] || return
    local team="$1"
    local alert=1
    [ "${ALERTS}" == "ALL OK" ] && alert=0
    echo -e "[$(LANG=en date '+%D_%H:%M,%A,%u')]|Timestamp=$(date +%s)|Team=$team|TimePeriod=$HO_WEEK,$HNO_WEEK,$HNO_WEEKEND,$HNO_HOLIDAY|Alert=${alert}|${ALERTS}" >>$ALERT_FILE
}

send_daily_notify() {
    # During the week
    if [ "$DAY" -le "5" ]; then
        # Check State 19h
        if [ "$HOUR" -eq "19" ] && [ "$MIN" -eq "00" ]; then
            debug "Send the daily notification"
            ALERTS=$(python /usr/local/bin/overview-report.py -f -c sys -x dba)
            [ $ARG_FORCE_NOMAIL -eq 0 ] && echo -e "${ALERTS}" | mail -s "[monitoring][SYS] Summary" $LIST_SYS $LIST_SYS_DUTY
            [ $NOPAGE -eq 0 ] && /usr/local/nagios/bin/smsm.py -c /etc/smsm.conf -s -g web -t "`echo "${ALERTS}" | head -c 130`"
    
            ALERTS=$(python /usr/local/bin/overview-report.py -f -c dba -i dba)
            [ $ARG_FORCE_NOMAIL -eq 0 ] && echo -e "${ALERTS}" | mail -s "[monitoring][DBA] Summary" $LIST_DBA
            [ $NOPAGE -eq 0 ] && /usr/local/nagios/bin/smsm.py -c /etc/smsm.dba.conf -s -g web -t "`echo "${ALERTS}" | head -c 130`"
            exit 0
        fi
    fi
}

send_alert() {
    debug "Get monitoring alerts..."
    # Alerting
    ALERTS=$(python /usr/local/bin/overview-report.py -x dba -c sys $UAT_NOPAGE)
    if [ -n "${ALERTS}" ]; then
        debug "New SysAdmin alert!"
        log_alert SYS
        [ $ARG_FORCE_NOMAIL -eq 0 ] && echo -e "${ALERTS}" | mail -s "[monitoring][SYS] new event occurred" $LIST_SYS
        [ $NOPAGE -eq 0 ] && /usr/local/nagios/bin/smsm.py -c /etc/smsm.conf -s -g web -t "`echo "${ALERTS}" | head -c 130`"
    else
        debug "No SYS alerts"
    fi
    
    ALERTS=$(python /usr/local/bin/overview-report.py -i dba -c dba $UAT_NOPAGE)
    if [ -n "${ALERTS}" ]; then
        debug "New DBA alert!"
	    log_alert DBA
        [ $ARG_FORCE_NOMAIL -eq 0 ] && echo -e "${ALERTS}" | mail -s "[monitoring][DBA] new event occurred" $LIST_DBA
        [ $NOPAGE -eq 0 ] && /usr/local/nagios/bin/smsm.py -c /etc/smsm.dba.conf -s -g web -t "`echo "${ALERTS}" | head -c 130`"
    else
        debug "No DBA alerts"
    fi
}

syntax() {
cat <<EOS
$(basename $0) - Notify monitoring alerts

SYNTAX

    $(basename $0) [-v] [-D DATE] [-f] [-N] [-P]

    The NOPAGE mode disable the SMS notifications

    -v      Enable the verbose mode
    -D DATE Instead of now, try this date for checking the hour mode (working or non-working hours)
            To use for debug *only*. Enable the verbose mode
            No notifications will be send in this mode
            Example: -D "20150101 10:00"
    -f      Force a non-working hour (HNO) check even if we are in working hours
    -N      Force the NOPAGE mode (no sms will be sent)
    -P      Disable the NOPAGE mode whatever the conditions
    -M      Disable the notifications by email
    -n      Disable all notifications. To use for debug *only*

    -h      This help

EOS
}



########
# MAIN #
########


LIST_SYS="it.prod.admin@pixmania-group.com" 
LIST_DBA=it.prod.dba@pixmania-group.com

NOPAGE_WEEK='y'
LOG_ALERT=1
ALERT_FILE="/var/log/$(basename $0).log"

HO_WEEK=0
HNO_WEEK=0
HNO_WEEKEND=0
HNO_HOLIDAY=0

ARG_DEBUG=0
ARG_DATE=
ARG_FORCE_CHECK=0
ARG_FORCE_NOPAGE=0
ARG_FORCE_PAGE=0
ARG_FORCE_NOMAIL=0
ARG_DISABLE_NOTIF=0

# Get options
while getopts vD:fNPMnh option; do
    case "$option" in
        D) ARG_DATE=$OPTARG; ARG_DEBUG=1 ;;
        v) ARG_DEBUG=1 ;;
        f) ARG_FORCE_CHECK=1 ;;
        N) ARG_FORCE_NOPAGE=1 ;;
        P) ARG_FORCE_PAGE=1 ;;
        M) ARG_FORCE_NOMAIL=1 ;;
        n) ARG_DISABLE_NOTIF=1 ;;
        h) syntax; exit ;;
    esac
done

# ARG_DATE = "20150120 18:15"
DATE=${ARG_DATE:-'now'}
CURDATE=$(date '+%Y%m%d %H:%M' -d "$DATE")
CURTS=$(date +%s -d "$CURDATE")
DAY=$(date +%u -d @$CURTS)
HOUR=$(date +%k -d @$CURTS)
MIN=$(date +%M -d @$CURTS)
CAL=$(gcal "%$CURDATE" -qfr --holiday-list=short | grep -v '=' | grep -c '+')
UAT_NOPAGE='-x uat'

if [ $CAL -ne 0  ]; then
    HNO_HOLIDAY=1
elif [ "$DAY" -le "5" ] && [ "$HOUR" -ge "09" ] && [ "$HOUR" -lt "19" ]; then
    HO_WEEK=1
elif ([ "$DAY" -eq "1" ] && [ "$HOUR" -lt "9" ]) || [ "$DAY" -ge "6" ] || ([ "$DAY" -eq "5" ] && [ "$HOUR" -ge "19" ]); then
    HNO_WEEKEND=1
else
    HNO_WEEK=1
fi

# UAT: Disable the NOPAGE mode for UAT during the week between 07h->09h and 19h->20h
#[ "$DAY" -le "5" ] && [ "$HOUR" -ge "07" ] && [ "$HOUR" -le "20" ] && [ $CAL -eq 0 ] && UAT_NOPAGE=''

# Enable/disable the NOPAGE mode during the week
NOPAGE=0
[ $HO_WEEK -eq 1 ] && NOPAGE=1
[ $NOPAGE_WEEK == 'y' ] && [ $HNO_WEEK -eq 1 ] && [ $HNO_HOLIDAY -eq 0 ] && NOPAGE=1
[ $ARG_FORCE_PAGE -eq 1 ] && NOPAGE=0
[ $ARG_FORCE_NOPAGE -eq 1 ] && NOPAGE=1

debug "Date: $CURDATE"
if [ $HNO_HOLIDAY -eq 1 ]; then
    debug "We are in holiday"
elif  [ $HNO_WEEKEND -eq 1 ]; then
    debug "We are in weekend"
else
    [ $HO_WEEK -eq 1 ] && debug "We are in working hour (HO)"
    [ $HNO_WEEK -eq 1 ] && debug "We are in week non-working hour (HNO)"
fi
[ $NOPAGE -eq 1 ] && debug "NOPAGE is currently enabled" || debug "NOPAGE is currently disabled"

# HO : exit if we are during the week working hours (Heures Ouvrables) and the force option is disabled
[ $HO_WEEK -eq 1 ] && [ $ARG_FORCE_CHECK -eq 0 ] && { debug "Nothing to do."; exit 0; }

# No notifications if a date is specified instead of NOW
[ -n "$ARG_DATE" ] && { debug "A date was specified. EXIT." ; exit; }


# send notifications
[ $ARG_DISABLE_NOTIF -eq 1 ] && exit 0
send_daily_notify
send_alert

exit 0

