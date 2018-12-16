#!/bin/bash

chmod +x /opt/bin/*
chmod +x /opt/etc/init.d/*
chmod +x /opt/sbin/*

export target=$1

/opt/bin/toggle_proxy disable

self="$(cat deploy_start.sh)" && eval "$self"

opkg update && opkg upgrade
opkg install libc libssp libev libmbedtls libpcre libpthread libsodium haveged zlib libopenssl ca-bundle shadowsocksr-libev bind-dig

chmod +x /opt/etc/init.d/S09dnscrypt-proxy
/opt/etc/init.d/S09dnscrypt-proxy restart

/opt/bin/toggle_proxy

add_service wan-start 'cru a run-services "*/1 * * * *" "/jffs/scripts/services-start"'
add_service wan-start 'cru a ensure_iptables "*/5 * * * *" "/opt/bin/config_iptables"'
add_service wan-start 'cru a update_ip_whitelist "25 3 * * mon" "/opt/bin/update_ip_whitelist && /opt/bin/config_iptables remove && /opt/bin/config_iptables"'
add_service wan-start 'cru a update_dns_whitelist "25 4 * * mon" "/opt/bin/update_dns_whitelist && /opt/bin/config_dnsmasq"'
add_service wan-start 'cru a update_subscribes "0 1 * * *" "/opt/bin/update_subscribes"'
