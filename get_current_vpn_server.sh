#!/bin/bash

# Set the script path
ScriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get the line with Hostname on then split out the numbers (we don't need those_ then split the line by the ':' colon and get the text after that
# This should be the country code for the Nord Server
CurrentVPNServer=`nordvpn status | grep -E "Hostname" | awk -F ": " '{print $2}'`
CountryCode=`echo $CurrentVPNServer | awk -F"[0-9]+" '{print $1;}' | awk -F": " '{print $1}'`

date +%F_%T > $ScriptPath/output_current_vpn_server.txt

curl --silent "https://api.nordvpn.com/v1/servers?filters\[country_id\]=$CountryCode&\[servers_groups\]\[identifier\]=legacy_standard&limit=16354" | jq --raw-output '.[] | select(.hostname | contains("'$CurrentVPNServer'")) | [.hostname, .load] | "\(.[0]): \(.[1])"' >> $ScriptPath/output_current_vpn_server.txt
