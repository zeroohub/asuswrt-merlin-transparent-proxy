#!/bin/bash

ssh "$*" /opt/bin/toggle_proxy disable

self="$(cat deploy_start.sh)" && eval "$self"

if [ ! -e ./router/opt/etc/shadowsocks.json ];then
    echo '请首先定义 router/opt/etc/shadowsocks.json'
    exit
fi

copy ac5300_router.sh /opt/tmp/
copy deploy_start.sh /opt/tmp/
copy router/opt/etc/iptables.sh /opt/bin/update_iptables
copy router/opt/etc/toggle_proxy.sh /opt/bin/toggle_proxy
copy router/opt/etc/switch_proxy.py /opt/bin/switch_proxy
copy router/opt/etc/patch_router /opt/bin/
copy router/opt/etc/restart_dnsmasq /opt/bin/
copy router/opt/etc/localips /opt/etc/
copy router/opt/etc/update_ip_whitelist /opt/bin/
copy router/opt/etc/update_dns_whitelist /opt/bin/

copy router/opt/etc/init.d/S22shadowsocksr /opt/etc/init.d/
copy router/opt/etc/shadowsocks.json /opt/etc/
copy router/opt/etc/subscribes.txt /opt/etc/


copy router/opt/etc/dnsmasq.d/foreign_domains.conf /opt/etc/dnsmasq.d/foreign_domains.conf
copy router/opt/etc/dnscrypt-proxy.toml /opt/etc/dnscrypt-proxy.toml
copy router/opt/etc/init.d/S09dnscrypt-proxy /opt/etc/init.d/
copy router/opt/sbin/dnscrypt-proxy /opt/sbin/dnscrypt-proxy


[ -e router/opt/etc/user_ip_whitelist.txt ] && copy router/opt/etc/user_ip_whitelist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_whitelist.txt ] && copy router/opt/etc/user_domain_name_whitelist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_blocklist.txt ] && copy router/opt/etc/user_domain_name_blocklist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_gfwlist.txt ] && copy router/opt/etc/user_domain_name_gfwlist.txt /opt/etc
