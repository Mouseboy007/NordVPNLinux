#!/bin/bash

clear

LockFile="/tmp/vpnlock"
LockFileTimeoutSeconds=60

# create a temporary file and exit if it already exists (as it means the process is running)
if test -e $LockFile ; then
  
	AgeOfLock=`date -d "now - $( stat -c "%Y" $LockFile ) seconds" +%s` 2>&1 >/dev/null
	if [ $AgeOfLock -gt $LockFileTimeoutSeconds ]
		then 
			echo File has been locked for $AgeOfLock seconds, removing lock
			rm -f $LockFile
		else 

		echo "Process already running, exiting ...."
		sleep 3
		exit 1
	fi
	
else
  touch $LockFile # This creates the file
fi

# Set the script path
ScriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set the location of the PiHole docker config
PiHolePath="<<YOUR_PATH_HERE>>" #Example "/home/bob/mydockerpiholedir"

# Set the Connectivity Log path and restrict it to 300 lines
VPNConnectivityLog="$ScriptPath/output_vpn_connectivity_log.txt"
tempvpnlog='/tmp/tmpvpnlog'
sed -n '1,300p;300q' $VPNConnectivityLog > $tempvpnlog ; mv $tempvpnlog $VPNConnectivityLog

# Set the NIC Interface that is connected directly to the WAN
NICInterface='ens160'

# Set the temporary WAN IP path if the file is blank
WANIP="$ScriptPath/output_public_wan_ip.txt"
# If the $WANIP file is blank, then populate it
if [[ ! -s $WANIP ]] ; then
  timeout -k 1 8 curl -s --interface $NICInterface https://api.ipify.org > $WANIP 2>&1
fi

# Set the WAN IP to the last 5 checks
tempwanip='/tmp/tmpwanip' ; sed -n '1,5p;5q' $WANIP > $tempwanip ; mv $tempwanip $WANIP


# Get the BestVPN Server from file
BestVPNServer=`awk 'NR==2' $ScriptPath/output_best_vpn_servers.txt | awk -F"." '{print $1}'`
BestVPNServerLoad=`awk 'NR==2' $ScriptPath/output_best_vpn_servers.txt | awk -F" " '{print $2}'`

	ConnectVPN () {
		# Before reconnecting, get the latest WAN IP
		until [ -n "$Public_WAN_IP" ]; do echo "Checking Public WAN IP" ; Public_WAN_IP=`timeout -k 1 8 curl -s --interface $NICInterface https://api.ipify.org` 2>&1 ; done
		sed -i "1i$(echo $Public_WAN_IP) - $(date)" $WANIP 2>&1
		timeout -k 1 15 sudo -u docker nordvpn connect $BestVPNServer # Probably need 7-10 seconds
		sudo -i $ScriptPath/set_vpn_iptables.sh
	}

	GetVPNStatus () {
	# Get the VPN Status and output to temp file
	CurrentNanoSeconds=`date +"%7N"`
	TempVPNStatusFile="/tmp/vpn_status_$CurrentNanoSeconds.txt"
	timeout -k 1 3 nordvpn status > $TempVPNStatusFile

	VPNStatus=`cat $TempVPNStatusFile | grep -E "Status" | awk -F ": " '{print $2}'`
	VPNHostname=`cat $TempVPNStatusFile | grep -E "Hostname" | awk -F ": " '{print $2}'`
	VPNIP=`cat $TempVPNStatusFile | grep -E "IP" | awk -F ": " '{print $2}'`
	VPNCountry=`cat $TempVPNStatusFile | grep -E "Country" | awk -F ": " '{print $2}'`
	VPNCity=`cat $TempVPNStatusFile | grep -E "City" | awk -F ": " '{print $2}'`
	VPNTransfer=`cat $TempVPNStatusFile | grep -E "Transfer" | awk -F ": " '{print $2}'`
	VPNUptime=`cat $TempVPNStatusFile | grep -E "Uptime" | awk -F ": " '{print $2}'`
	VPNTechnology=`cat $TempVPNStatusFile | grep -E "technology" | awk -F ": " '{print $2}'`
	VPNProtocol=`cat $TempVPNStatusFile | grep -E "protocol"  | awk -F ": " '{print $2}'`
	VPNVersion=`nordvpn version |  nordvpn version  | awk -F "Version " '{print $2}'`
	rm -f $TempVPNStatusFile

	}

# Colours to use with echo -e
Red='\033[0;31m'    #'0;31' is Red's ANSI color code
Green='\033[0;32m'  #'0;32' is Green's ANSI color code
Yellow='\033[1;33m' #'1;32' is Yellow's ANSI color code
Cyan='\033[0;36m'   #'0;34' is Cyan's ANSI color code#
Magenta='\033[0;35m'   #'0;34' is Magenta's ANSI color code
White='\033[0;37m'   #'0;34' is White's ANSI color code
NoColour='\033[0m'

# NOTE: 'timeout -k 1 5' means run for 5 secs, then kill after 1
# Function to CheckDNS and Restart DNS if needed
	CheckDNS() {
		PiHoleBooting=`timeout -k 1 1 docker ps | grep -E "pihole" | grep -E "seconds" | grep -o "starting"`
		if grep -q  "starting" <<< "echo $PiHoleBooting"
		then
		  echo -e "${Cyan}PiHole Starting Up, please wait${NoColour}"
		else
			DNSCheck="0.0.0.0"
			#DNSCheck="answer"
			#QueryDNS=`timeout -k 1 8 nslookup google.co.uk 192.168.0.25 | grep -E $DNSCheck` # Run an nslookup to see if we can resolve IP info
			QueryDNS=`timeout -k 1 2 nslookup pi.hole 192.168.0.25 | grep -E $DNSCheck` # Run an nslookup to see if we can resolve IP info
			if grep -q $DNSCheck <<< "echo $QueryDNS"
			then # check if the word 'answer' appears in the DNS lookup (if so, it's working okay)
			  echo -e "${Cyan}DNS queries working correctly${NoColour}"
			else
			  echo -e "${Yellow}unable to resolve DNS address, restarting DNS (PiHole)${NoColour}"
					timeout -k 1 2 docker network prune -f
					timeout -k 1 8 docker-compose -f $PiHolePath/docker-compose.yaml down
					#timeout -k 1 8 sudo -u docker docker-compose -f $PiHolePath/docker-compose.yaml down
					timeout -k 1 8 docker-compose -f $PiHolePath/docker-compose.yaml up -d
					timeout -k 1 2 docker network prune -f
				fi
		fi
	}

	CompareIPInfo() {
	CurrentIP=`timeout -k 1 2 dig +short myip.opendns.com @resolver1.opendns.com` # Get the Current VPN WAN IP from dig
	Public_WAN_IP=`cat $WANIP | head -1 | grep -E "-"  | awk -F "-" '{print $1}'`  # Get the latest WAN IP from file from the last disconnect state
	
	# In case the first method of getting the Public IP failed, loop and test using a different method
	# api.ipify.org has no API limits so can query it relentlessly
	until [ -n "$CurrentIP" ]; do echo "Checking VPN WAN IP" ; CurrentIP=`timeout -k 1 2 curl -s https://api.ipify.org` 2>&1 ; done
		
	}

	CheckWAN() {

		if [[ ! -s $VPNConnectivityLog ]] ; then 
			echo "Current Server: $VPNHostname ($VPNIP) - $(date)" > $VPNConnectivityLog
		fi
		
		if grep -q "$CurrentIP" <<< "$Public_WAN_IP"
		then 
			echo -e "${Red}Current IP and Public IP are the SAME - VPN Disconnected!${NoColour}"
			sed -i "1iDisconnected! - $(date)" $VPNConnectivityLog 2>&1	
			echo "$(date) Attempting to reconnect to VPN"
			#timeout -k 1 2 nordvpn disconnect >> /dev/null 2>&1
			ConnectVPN
			sleep 1
			sed -i "1iCurrent Server: $VPNHostname ($VPNIP) - $(date)" $VPNConnectivityLog 2>&1
			LoopCounter=50		
		else 
			echo -e "${Green}Current WAN IP and Public WAN IP are DIFFERENT - VPN Connected!${NoColour}"
			TopLineOfLog=`awk 'NR==1' $VPNConnectivityLog`
			if [[ $LoopCounter -gt 0 && $LoopCounter -lt 1000 ]] 
			then
				if ! grep -q "$VPNIP" <<< "$TopLineOfLog" 
				then sed -i "1iCurrent Server: $VPNHostname ($VPNIP) - $(date)" $VPNConnectivityLog 2>&1
				fi
			fi	
			LoopCounter=1000
		fi
	}

	ScreenInfo () {
		#echo "Getting Current VPN Load"
		#CurrentVPNLoad=`timeout -k 1 5 curl --silent https://api.nordvpn.com/server/stats/$VPNHostname | awk -F ':' '{print $2}' | awk -F '}' '{print $1}'`
		CurrentVPNServerInFile=`awk 'NR==2' $ScriptPath/output_current_vpn_server.txt | awk -F":" '{print $1}'`
		if ! grep -q "$CurrentVPNServerInFile" <<< "$VPNHostname"
		then $ScriptPath/get_current_vpn_server.sh
		fi
		CurrentVPNLoad=`awk 'NR==2' $ScriptPath/output_current_vpn_server.txt | awk -F" " '{print $2}'`
		

		sleep 1
		#clear

		# VNStat Statisticts
		ThisMonth=`date +"%Y-%m-01"`
		CurrentMonth=`date +"%b"`
		CurrentHour=`date +"%H:00"`
		VNStatMonthlyData=`vnstat -m --begin $ThisMonth | rev | cut -d '|' -f 2 | rev | awk 'NR==6' | awk -F " " '{print $1,$2}'`
		VNStatTodayData=`vnstat -d --begin today | rev | cut -d '|' -f 2 | rev | awk 'NR==6' | awk -F " " '{print $1,$2}'`
		VNStatYesterdayData=` vnstat -d 2 | rev | cut -d '|' -f 2 | rev | awk 'NR==6' | awk -F " " '{print $1,$2}'`
		VNStatSinceLastOClock=`vnstat -h --hours 1 | rev | cut -d '|' -f 2 | rev | awk 'NR==7' | awk -F " " '{print $1,$2}'`

		echo "#########"
			if grep -q "$CurrentIP" <<< "$Public_WAN_IP"
			then 
				  echo -e "${Red}"WARNING Public IP Cnly"${NoColour}"
				  echo -e "${Red}$Public_WAN_IP${NoColour}"
			else 
				  echo -e "${Green}PUBLIC IP - $CurrentIP${NoColour}"
			fi
		echo "#########"
		echo

		echo "##############"
		echo -e "${Yellow}VPN STATUS${NoColour}"
		echo "Status:   $VPNStatus"
		echo "Tech:     $VPNTechnology"
		echo "Host:     $VPNHostname (Load $CurrentVPNLoad)"
		echo "Best:     $BestVPNServer (Load $BestVPNServerLoad)"
		echo "IP:       $VPNIP"
		echo "Country:  $VPNCountry"
		echo "City:     $VPNCity"
		echo "Transfer: $VPNTransfer"
		echo "Time Now: $(date +%H:%M:%S)"
		echo "UpTime:   $VPNUptime"
		echo "Version:  $VPNVersion"
		echo ""
		echo

		ServerUptime=`uptime -p`
		PiHoleUptime=`timeout -k 1 1 docker ps | grep -E "pihole" | awk -F "Up " '{print $2}' | awk -F "(" '{print $1}'`
		FreeDiskSpace=`df -h / | tail -n 1 | awk '{print $4}'`
		echo "##########"
		echo -e "${Cyan}PIHOLE UPTIME - $PiHoleUptime${NoColour}"
		echo -e "${Cyan}SERVER UPTIME - $ServerUptime${NoColour}"
		#echo
		echo -e "${Cyan}DATA STATS    - $CurrentMonth: ${Yellow}$VNStatMonthlyData${Cyan}, Yesterday: ${Yellow}$VNStatYesterdayData,${NoColour}"
		echo -e "${Cyan}              - Today: ${Yellow}$VNStatTodayData${Cyan}, Since $CurrentHour: ${Yellow}$VNStatSinceLastOClock${NoColour}"
		#echo
		echo -e "${Cyan}DISK FREE     - ${Magenta}$FreeDiskSpace${NoColour}"
		echo "##########"
		echo
	}

# Set a loop for our Do/Until loop
LoopCounter=1

until [ $LoopCounter -gt 2 ]
do
	GetVPNStatus ; if [[ $VPNStatus == "Disconnected" ]] ; then ConnectVPN ; fi
	CheckDNS
	CompareIPInfo
	CheckWAN
	LoopCounter=$(($LoopCounter + 1))
done

if [[ $LoopCounter -lt 1000 ]]
	then
		echo -e "${Red}$(date) multiple attempts to reconnect failed, rebooting system${NoColour}"
		rm -f $LockFile
		
		# This will only work if you've launched the script as 'sudo' (like via crontab) otherwise you'll be prompted for a password to reboot
		sudo -i /sbin/reboot

fi

# Check if script is being run interactively or not
if test -t 0; then ScreenInfo ; fi

rm -f $LockFile

# Remove any handle to this script now we've finished running through it
ThisScript=$(readlink -f $0)
#echo $ThisScript
pgrep -f $ThisScript | xargs kill -n >> /dev/null 2>&1

exit