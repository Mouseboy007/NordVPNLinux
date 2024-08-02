#!/bin/bash

VPNDir='<<YOUR_PATH_HERE>>' # example '/home/bob/mystuff/vpnfolder'

timeout -k 1 3 sudo -u docker mv $VPNDir/get_vpn_connection_status.sh $VPNDir/get_vpn_connection_status-PAUSE.sh 2> /dev/null