#!/bin/sh

if [ "$1" == 'disable' ]; then
    /opt/bin/config_dnsmasq remove
    /opt/bin/config_iptables remove
else
    /opt/bin/config_dnsmasq
    /opt/bin/config_iptables
    /opt/bin/switch_proxy
fi
