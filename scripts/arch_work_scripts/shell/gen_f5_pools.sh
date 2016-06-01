#!/bin/sh

# Update "f5_pools" metrics
# Usage: ./gen_f5_pools.sh > files/etc/snmp/metrics/f5_pools

POOLS=$( (snmpwalk -Osv -c pixro -v2c 10.3.254.242 F5-BIGIP-LOCAL-MIB::ltmPoolStatName; snmpwalk -Osv -c pixro -v2c 10.3.254.240 F5-BIGIP-LOCAL-MIB::ltmPoolStatName) | sed -e 's/^STRING: //' | sort )
VS=$( (snmpwalk -Osv -c pixro -v2c 10.3.254.242 F5-BIGIP-LOCAL-MIB::ltmVirtualServStatName; snmpwalk -Osv -c pixro -v2c 10.3.254.240 F5-BIGIP-LOCAL-MIB::ltmVirtualServStatName) | sed -e 's/^STRING: //' | sort )

echo "<Plugin snmp>"

for pool in $POOLS
do
	pool_lc=$(echo $pool | sed 's/^POOL_//' | tr A-Z a-z)

	cat <<END
    <Data "f5_poolconns_$pool_lc">
        Type "f5_poolconns"
        Table false
        Instance "$pool"
        Values "F5-BIGIP-LOCAL-MIB::ltmPoolStatServerCurConns.\"$pool\""
    </Data>
    <Data "f5_poolbytes_$pool_lc">
        Type "f5_poolbytes"
        Table false
        Instance "$pool"
        Values "F5-BIGIP-LOCAL-MIB::ltmPoolStatServerBytesIn.\"$pool\"" "F5-BIGIP-LOCAL-MIB::ltmPoolStatServerBytesOut.\"$pool\""
    </Data>
END

done

for vs in $VS
do
	
	vs_lc=$(echo $vs | sed 's/^VS_//' | tr A-Z a-z)

	cat <<END
    <Data "f5_vsreq_$vs_lc">
        Type "f5_req"
        Table false
        Instance "$vs"
        Values "F5-BIGIP-LOCAL-MIB::ltmVirtualServStatTotRequests.\"$vs\""
    </Data>
END
done

echo "</Plugin>"
