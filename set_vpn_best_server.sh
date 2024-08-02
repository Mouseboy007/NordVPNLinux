#!/bin/bash

clear

# Set the script path
ScriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VPNConnectivityLog="$ScriptPath/output_vpn_connectivity_log.txt"

# Get the BestVPN Server from file
BestVPNServer=`awk 'NR==2' $ScriptPath/output_best_vpn_servers.txt | awk -F"." '{print $1}'`

TempVPNStatusVariable=$(timeout -k 1 3 nordvpn status)
readarray -d ":" TempVPNStatusArray <<< "$TempVPNStatusVariable"

	VPNHostname=`echo ${TempVPNStatusArray[2]} | awk -F " " '{print $1}'`
	VPNIP=`echo ${TempVPNStatusArray[3]} | awk -F " " '{print $1}'`

sed -i "1iCurrent Server: $VPNHostname ($VPNIP) - $(date)" $VPNConnectivityLog 2>&1	
echo "$(date) Attempting to connect to Best VPN Server"
timeout -k 1 1 nordvpn disconnect >> /dev/null 2>&1
timeout -k 1 10 nordvpn connect $BestVPNServer