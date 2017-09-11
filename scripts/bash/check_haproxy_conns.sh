# /bin/bash

curl=`which curl`
max="8000"
opts="-s --connect-timeout 5 -m 30 -u admin:admin"
servers="loadb05b:8081 loadb05b:8082 loadb05b:8083 loadb05b:8084 loadb05b:8085 loadb05b:8086 loadb05b:8087 loadb06u:8081 loadb06u:8082 loadb06u:8083 loadb06u:8084 loadb06u:8085 loadb06u:8086 loadb06u:8087 xwebprivlb01bv:9090"

highest=$(for serv in $servers; do
	connexions=`$curl $opts http://$serv | egrep "current conns =|process #"`
	process=`echo "$connexions" | grep process | awk '{print $6}'`
	conns=`echo "$connexions" | grep current | awk '{print $4}'`
	if [ $? -eq 0 ]; then
		echo "CNXs:$serv:process $process:$conns" 
	else
		echo "CNXs:warning curl haproxy $1"
	fi
done) 
high=`echo "highest = $highest" | sed -e s/\;// -e s/\,// | awk -F ':' '{print $2":"$4":"$5}' | sort -t ":" -rn -k3 | head -n1 | cut -d":" -f3` 
low=`echo "highest = $highest" | sed -e s/\;// -e s/\,// | awk -F ':' '{print $2":"$4":"$5}' | sort -t ":" -n -k3 | head -n1 | cut -d":" -f3` 
if [ $high -gt 2500 ]; then
	echo "Problem!"
	echo "sending email..."
	echo "high = $high"
	echo "low = $low"
else
	if [ $low -lt 1 ]; then
		heure=`date +%H`
		echo "heure = $heure"
		echo "Problem!"
		echo "high = $high"
		echo "low = $low"
		echo "highest = $highest" | sed -e s/\;// -e s/\,// | awk -F ':' '{print $2":"$4":"$5}' | sort -t ":" -n -k3 
		if [ $heure -eq 00 ] || [[ $heure -ge 20 && $heure -le 23 ]]; then
			echo "Problem!"
        		echo "sending email..."
			echo "high = $high"
        		echo "low = $low"
		fi
	else
		echo "high = $high"
		echo "low = $low"
		echo "details:"
		echo "    $highest" | sed -e s/\;// -e s/\,// | awk -F ':' '{print $2":"$4":"$5}' | sort -t ":" -rn -k3
		echo "    "ok no problem"
	fi
fi
