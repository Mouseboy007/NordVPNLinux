#!/bin/bash

clear

GetVPNStatus () {
	# Get the VPN Status and output to temp file
	CurrentNanoSeconds=`date +"%7N"`
	TempVPNStatusFile="/tmp/vpn_status_$CurrentNanoSeconds.txt"
	timeout -k 1 3 nordvpn status > $TempVPNStatusFile

	VPNTechnology=`cat $TempVPNStatusFile | grep -E "technology" | awk -F ": " '{print $2}'`

	rm -f $TempVPNStatusFile

	}

GetVPNStatus
if [[ $VPNTechnology == 'OPENVPN' ]] ; then Tunnel="nordtun" ; fi
if [[ $VPNTechnology == 'NORDLYNX' ]] ; then Tunnel="nordlynx" ; fi

# Default NIC
DefaultNIC='<<YOUR_NIC>>' #Example 'enp0s10' or 'eth0' etc
# Default DNS Server
DNSServerIP='<<YOUR_DNS_SERVER' #Example '10.0.0.3'
# Local System IP
LocalSystemIP='<<THIS_LINUX_SERVER' #Example '10.0.0.1'
# Local subnet
LocalSubnet='<<YOUR_LOCAL_SUBNET' #Example '10.0.0.1/24'

# Clear settings and reset
sudo iptables -X #Deletes all Default Chains to start from Scratch
sudo iptables -t nat -F # flushes all rules from the NAT tables
sudo iptables -t mangle -F #Flushes all rules from the Mangle tables
sudo iptables -F #Flushes all rules from all three default IPTables 

sudo iptables -A INPUT -i $DefaultNIC -s $LocalSubnet -j ACCEPT # Allow Internal Traffic Only
iptables -A OUTPUT -o $DefaultNIC -s $LocalSystemIP -j ACCEPT # Output from the Local System IP through the default NIC 

#PreRouting (send all DNS to PiHole)
sudo echo "Tunnel is" $Tunnel ; sleep 1
sudo iptables -t nat -A PREROUTING -i $Tunnel -p udp --dport 53 ! -s $DNSServerIP ! -d $DNSServerIP -j DNAT --to $DNSServerIP
sudo iptables -t nat -A PREROUTING -i $DefaultNIC -p udp --dport 53 ! -s $DNSServerIP ! -d $DNSServerIP -j DNAT --to $DNSServerIP
sudo iptables -t nat -A PREROUTING -i $Tunnel -p tcp --dport 53 ! -s $DNSServerIP ! -d $DNSServerIP -j DNAT --to $DNSServerIP
sudo iptables -t nat -A PREROUTING -i $DefaultNIC -p tcp --dport 53 ! -s $DNSServerIP ! -d $DNSServerIP -j DNAT --to $DNSServerIP

# Masquerade ALL outgoing traffic through the tunnel
sudo iptables -t nat -A POSTROUTING -o $Tunnel -j MASQUERADE

# Allow return traffic for established connections
sudo iptables -A INPUT -i $DefaultNIC -m state --state RELATED,ESTABLISHED -j ACCEPT

# Forward everything through the VPN tunnel
sudo iptables -A FORWARD -i $DefaultNIC -o $Tunnel -j ACCEPT
sudo iptables -A FORWARD -i $Tunnel -o $DefaultNIC -m state --state RELATED,ESTABLISHED -j ACCEPT