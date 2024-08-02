#!/bin/bash

clear

# Set the script path
ScriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get the BestVPN Server from file
BestVPNServer=`awk 'NR==2' $ScriptPath/output_best_vpn_servers.txt | awk -F"." '{print $1}'`

GetVPNStatus () {
	# Get the VPN Status and output to temp file
	CurrentNanoSeconds=`date +"%7N"`
	TempVPNStatusFile="/tmp/vpn_status_$CurrentNanoSeconds.txt"
	timeout -k 1 3 nordvpn status > $TempVPNStatusFile

	VPNTechnology=`cat $TempVPNStatusFile | grep -E "technology" | awk -F ": " '{print $2}'`

	rm -f $TempVPNStatusFile

	}
	
GetVPNStatus
if [[ $VPNTechnology == 'OPENVPN' ]] ; then nordvpn set technology nordlynx ; fi
if [[ $VPNTechnology == 'NORDLYNX' ]] ; then nordvpn set technology openvpn ; fi

echo "$(date) Attempting to connect to Best VPN Server"
timeout -k 1 1 nordvpn disconnect >> /dev/null 2>&1
timeout -k 1 10 nordvpn connect $BestVPNServer