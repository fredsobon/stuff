#!/bin/sh

set -e

SSH_HOST=app01.tool.office.prod.vit.e-merchant.net

# Use current $USER by adding a dot (.) after the first character
JIRA_USER=$(echo $USER | sed 's/^\(.\)/\1./')

JIRA_DB=jiradb4
JIRA_URL="https://jira.e-merchant.com"
JIRA_URL_JQL="$JIRA_URL/issues/?jql="
DATE=$(date +%Y-%m-%d)
BASE_TIME=450
CRIT_LEVEL=300
WARN_LEVEL=360
CRIT_COLOR=red
WARN_COLOR=orange
GOOD_COLOR=green

IMG=/usr/share/icons/gnome-colors-common/16x16/apps/clock.png

if [ -n "$IMG" ] && [ -f "$IMG" ]
then
	echo "<img>$IMG</img>"
fi

TIME=$(ssh $SSH_HOST "mysql -s -e \"select round(sum(timeworked)/60, 0) from worklog where UPDATEAUTHOR = '$JIRA_USER' and STARTDATE like '$DATE%'\" $JIRA_DB")
DETAIL=$(ssh $SSH_HOST "mysql -s -e \"select concat(p.pkey, '-', i.issuenum) as Ticket, concat(round(sum(w.timeworked)/60, 0), 'm') as Timeworked, i.SUMMARY from worklog w join jiraissue i on w.issueid = i.ID join project p on i.PROJECT=p.ID where w.UPDATEAUTHOR = '$JIRA_USER' and w.STARTDATE like '$DATE%' group by ticket order by ticket\" $JIRA_DB")
COUNT=$(echo "$DETAIL" | grep -v '^$' | wc -l)

if [ -n "$DETAIL" ]
then
	TICKETS_URL="${JIRA_URL_JQL}key%3D`echo "$DETAIL"| awk '{print $1}' | xargs echo | sed 's/ /%20or%20key%3D/g'`%20order%20by%20key"
else
	TICKETS_URL=$JIRA_URL
	DETAIL="Rien !!!"
fi

[ $TIME = "NULL" ] && TIME=0

if [ $TIME -lt $CRIT_LEVEL ]
then
	COLOR=$CRIT_COLOR
elif [ $TIME -lt $WARN_LEVEL ]
then
	COLOR=$WARN_COLOR
else
	COLOR=$GOOD_COLOR
fi

if [ $COUNT -gt 1 ]
then
	TICKETS="$COUNT tickets"
else
	TICKETS="$COUNT ticket"
fi

PCT=$(echo "$TIME / $BASE_TIME * 100"|bc -l)
TIME=$(echo "$TIME / 60"|bc -l)

echo "<txt><span foreground=\"$COLOR\">$(printf %.2f $TIME)h</span>
$TICKETS</txt>"
#echo "<bar>$(printf %.2f $PCT)</bar>"
echo "<tool>$DETAIL</tool>"
echo "<click>xdg-open $TICKETS_URL</click>"
