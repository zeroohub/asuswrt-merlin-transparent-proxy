#!/bin/bash

export target=$1

self="$(cat deploy_start.sh)" && eval "$self"

opkg update && opkg upgrade
opkg install libc libssp libev libmbedtls libpcre libpthread libsodium haveged zlib libopenssl ca-bundle shadowsocksr-libev bind-dig

# dnsmasq
dnsmasq_dir=/opt/etc/dnsmasq.d
if ! grep -qs "^conf-dir=$dnsmasq_dir/,\*\.conf$" /etc/dnsmasq.conf; then
    echo "conf-dir=$dnsmasq_dir/,*.conf" >> /etc/dnsmasq.conf
fi

sed -i 's/log-facility=\/var\/log\/dnsmasq.log/log-facility=\/opt\/var\/log\/dnsmasq.log/g' /etc/dnsmasq.conf

# dnscrypt
chmod +x /opt/etc/init.d/S09dnscrypt-proxy

/opt/etc/init.d/S09dnscrypt-proxy restart
/opt/bin/restart_dnsmasq


# shadowsocksr
replace_regex '"local_address".*' '"local_address":'" \"$targetip\"," /opt/etc/shadowsocks.json

#
## 每隔 1 分钟检测下所有的服务是否运行.
#add_service wan-start 'cru a run-services "*/5 * * * *" "/jffs/scripts/services-start"'
## 每隔 3 分钟检测下 iptables 是否失效.
#add_service wan-start 'cru a run-iptables "*/5 * * * *" "/opt/etc/iptables.sh"'
#
## 星期一的 3:25 分升级 IP 白名单.
#chmod +x /opt/etc/update_ip_whitelist && /opt/etc/update_ip_whitelist
#add_service wan-start 'cru a update_ip_whitelist "25 3 * * 2" "/opt/etc/update_ip_whitelist"'
#
## 星期一的 4:25 分升级域名白名单.
#chmod +x /opt/etc/update_dns_whitelist && /opt/etc/update_dns_whitelist
#add_service wan-start 'cru a update_dns_whitelist "25 4 * * 2" "/opt/etc/update_dns_whitelist"'
#
#set +e
#/jffs/scripts/services-stop
#set -e
#/jffs/scripts/services-start
#
## 在所有服务启动之后, 运行 /opt/etc/patch_router 为 dnsmasq 追加配置, 并重启 dnsmasq 服务.
#add_service services-start '
#if [ ! -f /tmp/patch_router_is_run ];then
#    /opt/etc/patch_router && touch /tmp/patch_router_is_run
#fi
#'
#
#chmod +x /opt/etc/patch_router && /opt/etc/patch_router
#
#if [ ! -f /tmp/patch_router_is_run ];then
#    /opt/etc/patch_router && touch /tmp/patch_router_is_run
#fi
#
#echo '如果无法翻墙, 按照下列步骤查错：'
#echo '1. 断掉已连接的 WiFi，并重新连接，看看是否可以翻墙。'
#echo '2. 保持 U 盘，待重启路由器完成后，等待片刻，看看是否可以翻墙。'
#echo
#echo '升级部署:'
#echo "$0 admin@router.asus.com"
#echo
#echo '无法连接路由器：'
#echo '1. 拔下 U 盘，重启，尝试重新连接路由器。'
#echo '2. 进入管理界面，选择格式化 jffs，插入 U 盘，并重启。'
#echo
#echo '暂时关闭代理：'
#echo 'ssh admin@router.asus.com /opt/etc/toggle_proxy.sh'
#echo '再次运行以上脚本重新开启。'
## reboot
