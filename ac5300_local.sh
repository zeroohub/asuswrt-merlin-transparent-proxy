#!/bin/bash

export target=$1

self="$(cat deploy_start.sh)" && eval "$self"

if [ ! -e ./router/opt/etc/shadowsocks.json ];then
    echo '请首先定义 router/opt/etc/shadowsocks.json'
    exit
fi

copy ac5300_router.sh /opt/tmp/
copy deploy_start.sh /opt/tmp/
copy router/opt/bin/config_iptables.sh /opt/bin/config_iptables
copy router/opt/bin/config_dnsmasq.sh /opt/bin/config_dnsmasq
copy router/opt/bin/toggle_proxy.sh /opt/bin/toggle_proxy
copy router/opt/bin/switch_proxy.py /opt/bin/switch_proxy
copy router/opt/bin/restart_dnsmasq /opt/bin/
copy router/opt/bin/update_ip_whitelist /opt/bin/
copy router/opt/bin/update_dns_whitelist /opt/bin/
copy router/opt/bin/update_subscribes.py /opt/bin/update_subscribes

copy router/opt/etc/init.d/S22shadowsocksr /opt/etc/init.d/
copy router/opt/etc/shadowsocks.json /opt/etc/
copy router/opt/etc/subscribes.txt /opt/etc/

copy router/opt/etc/localips /opt/etc/
copy router/opt/etc/dnsmasq.d/foreign_domains.conf /opt/etc/dnsmasq.d/foreign_domains.conf
copy router/opt/etc/dnscrypt-proxy.toml /opt/etc/dnscrypt-proxy.toml
copy router/opt/etc/init.d/S09dnscrypt-proxy /opt/etc/init.d/
copy router/opt/sbin/dnscrypt-proxy /opt/sbin/dnscrypt-proxy


[ -e router/opt/etc/user_ip_whitelist.txt ] && copy router/opt/etc/user_ip_whitelist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_whitelist.txt ] && copy router/opt/etc/user_domain_name_whitelist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_blocklist.txt ] && copy router/opt/etc/user_domain_name_blocklist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_gfwlist.txt ] && copy router/opt/etc/user_domain_name_gfwlist.txt /opt/etc
