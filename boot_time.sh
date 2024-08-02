#!/bin/bash

VPNDir='<<YOUR_PATH_HERE>>' # example '/home/bob/mystuff/vpnfolder'

rm -f /tmp/vpnlock
sudo chown -R +777 $VPNDir/*
sudo chmod -R +777 $VPNDir/*
sudo chmod -R +X $VPNDir/*.sh
sudo -u docker nordvpn set technology nordlynx
sudo $VPNDir/set_vpn_best_server.sh
sudo $VPNDir/set_vpn_iptables.sh


