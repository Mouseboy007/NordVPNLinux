#!/bin/bash

VPNDir='/home/docker/shared/vpn'

rm -f /tmp/vpnlock
sudo chown -R +777 $VPNDir/*
sudo chmod -R +777 $VPNDir/*
sudo chmod -R +X $VPNDir/*.sh
sudo -u docker nordvpn set technology nordlynx
sudo $VPNDir/get_vpn_best_server.sh
sudo $VPNDir/set_vpn_best_server.sh
sudo $VPNDir/set_vpn_iptables.sh


