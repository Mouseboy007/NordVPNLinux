#!/bin/bash

# Set the script path
ScriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BestVPNServersOutput="$ScriptPath/output_best_vpn_servers.txt"

# Get the line with Hostname on then split out the numbers (we don't need those_ then split the line by the ':' colon and get the text after that
# This should be the country code for the Nord Server
ccode=`nordvpn status  | grep -E "^Hostname: " | awk -F"[0-9]+" '{print $1;}' | awk -F": " '{print $2}'`

date +%F_%T > $BestVPNServersOutput

curl --silent "https://api.nordvpn.com/v1/servers/recommendations?filters\[country_id\]=$ccode&\[servers_groups\]\[identifier\]=legacy_standard" | jq --raw-output --slurp ' .[] | sort_by(.load) | limit(10;.[]) | [.hostname, .load] | "\(.[0]): \(.[1])"' >> $BestVPNServersOutput