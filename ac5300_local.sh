#!/bin/bash

#ssh "$*" /opt/etc/toggle_proxy.sh disable

self="$(cat deploy_start.sh)" && eval "$self"

# self="$(cat ~/Project/deployment_bash/deploy_start.sh)" && eval "$self"

export target=$1

if [ ! -e ./router/opt/etc/shadowsocks.json ];then
    echo '请首先定义 router/opt/etc/shadowsocks.json'
    exit
fi

copy ac5300_router.sh /opt/tmp
copy deploy_start.sh /opt/tmp
copy router/opt/etc/iptables.sh /opt/etc
copy router/opt/etc/toggle_proxy.sh /opt/etc
copy router/opt/etc/switch_proxy.sh /opt/etc
copy router/opt/etc/patch_router /opt/etc
copy router/opt/etc/restart_dnsmasq /opt/bin/
copy router/opt/etc/localips /opt/etc
copy router/opt/etc/update_ip_whitelist /opt/etc
copy router/opt/etc/update_dns_whitelist /opt/etc

copy router/opt/etc/init.d/S22shadowsocksr /opt/etc/init.d/
copy router/opt/etc/shadowsocks.* /opt/etc


copy router/opt/etc/dnsmasq.d/foreign_domains.conf /opt/etc/dnsmasq.d/foreign_domains.conf
copy router/opt/etc/dnscrypt-proxy.toml /opt/etc/dnscrypt-proxy.toml
copy router/opt/etc/init.d/S09dnscrypt-proxy /opt/etc/init.d/
copy router/opt/sbin/dnscrypt-proxy /opt/sbin/dnscrypt-proxy


[ -e router/opt/etc/user_ip_whitelist.txt ] && copy router/opt/etc/user_ip_whitelist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_whitelist.txt ] && copy router/opt/etc/user_domain_name_whitelist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_blocklist.txt ] && copy router/opt/etc/user_domain_name_blocklist.txt /opt/etc
[ -e router/opt/etc/user_domain_name_gfwlist.txt ] && copy router/opt/etc/user_domain_name_gfwlist.txt /opt/etc
