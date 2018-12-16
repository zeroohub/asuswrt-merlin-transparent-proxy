#!/bin/sh

iptables_bak=/opt/tmp/iptables.rules
ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$1" == 'remove' ]; then
    echo 'remove iptables...'

    ip route flush table 100

    iptables -t nat -F SHADOWSOCKS_TCP          # flush
    iptables -t nat -X SHADOWSOCKS_TCP         # --delete-chain
    iptables -t mangle -F SHADOWSOCKS_UDP
    iptables -t mangle -X SHADOWSOCKS_UDP
    iptables -t mangle -F SHADOWSOCKS_MARK
    iptables -t mangle -X SHADOWSOCKS_MARK

    if [ "$ipset_protocal_version" == 6 ]; then
        alias iptables='/usr/sbin/iptables'
        ipset destroy CHINAIP
        ipset destroy CHINAIPS
        /usr/sbin/iptables-restore < $iptables_bak
    else
        alias iptables='/opt/sbin/iptables'
        ipset -X CHINAIP
        ipset -X CHINAIPS
        /opt/sbin/iptables-restore < $iptables_bak
    fi

    exit 0
fi

echo "install iptables..."
if iptables -t nat -L SHADOWSOCKS_TCP; then
    echo "already installed"
    exit 0
fi

remote_server_ip=$(cat /opt/etc/shadowsocks.json |grep 'server"' |cut -d':' -f2|cut -d'"' -f2)
local_redir_ip=$(cat /opt/etc/shadowsocks.json |grep 'local_address"' |cut -d':' -f2|cut -d'"' -f2)
local_redir_port=$(cat /opt/etc/shadowsocks.json |grep 'local_port' |cut -d':' -f2 |grep -o '[0-9]*')

echo 'Applying ipset rule, it maybe take several minute to finish ...'

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    alias iptables='/usr/sbin/iptables'
    alias iptables_save='/usr/sbin/iptables-save'
    modprobe ip_set
    modprobe ip_set_hash_net
    modprobe ip_set_hash_ip
    modprobe xt_set
    # 默认值 hashsize 1024 maxelem 65536, 已经足够了.
    ipset -N CHINAIPS hash:net
    ipset -N CHINAIP hash:ip
    alias ipset_add_chinaip='ipset add CHINAIP'
    alias ipset_add_chinaips='ipset add CHINAIPS'
else
    alias iptables='/opt/sbin/iptables'
    alias iptables_save='/opt/sbin/iptables-save'
    modprobe ip_set
    modprobe ip_set_nethash
    modprobe ip_set_iphash
    modprobe ipt_set
    # v4 document: https://people.netfilter.org/kadlec/ipset/ipset.man.html
    ipset -N CHINAIPS nethash
    ipset -N CHINAIP iphash
    alias ipset_add_chinaip='ipset -q -A CHINAIP'
    alias ipset_add_chinaips='ipset -q -A CHINAIPS'
fi

# 如果没有备份 iptables rule, 就备份它.
[ -f $iptables_bak ] || iptables_save > $iptables_bak

OLDIFS="$IFS" && IFS=$'\n'
if ipset -L CHINAIPS &>/dev/null; then
    # 将国内的 ip 全部加入 ipset CHINAIPS, 近 8000 条, 这个过程可能需要近一分钟时间.
    count=$(ipset -L CHINAIPS |wc -l)

    if [ "$count" -lt "8000" ]; then
        for ip in $(cat /opt/etc/chinadns_chnroute.txt |grep -v '^#'); do
            ipset_add_chinaips $ip
        done

        for ip in $(cat /opt/etc/localips|grep -v '^#'); do
            ipset_add_chinaips $ip
        done
    fi
fi

if ipset -L CHINAIP; then
    ipset_add_chinaip 202.12.29.205 # ftp.apnic.net
    ipset_add_chinaip 81.4.123.217 # entware
    ipset_add_chinaip 151.101.76.133 # raw.githubusercontent.com
    ipset_add_chinaip 151.101.40.133 # raw.githubusercontent.com
    ipset_add_chinaip $remote_server_ip # vps ip address, 如果访问 VPS 地址, 无需跳转, 直接返回, 否则会形成死循环.

    # user_ip_whitelist.txt 格式示例:
    # 81.4.123.217 # entware 的地址 (注释可选)
    if [ -e /opt/etc/user_ip_whitelist.txt ]; then
        for ip in $(cat /opt/etc/user_ip_whitelist.txt|grep -v '^#'); do
            ipset_add_chinaip $ip
        done
    fi
fi
IFS=$OLDIFS

# ====================== tcp rule =======================
iptables -t nat -N SHADOWSOCKS_TCP
# 两个 ipset 中的 ip 直接返回.
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -m set --match-set CHINAIPS dst -j RETURN
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -m set --match-set CHINAIP dst -j RETURN
# 否则, 重定向到 ss-redir
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -j REDIRECT --to-ports $local_redir_port

# Apply tcp rule
iptables -t nat -A PREROUTING -p tcp -j SHADOWSOCKS_TCP
# 从路由器内访问时, 也是用这个 rule.
iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS_TCP

# if enable this, make sure, port 53 are exclude, since it's already use dnscrypt.
# ====================== udp rule =======================
#
# 只有满足下面两个条件, 才需要 udp rule

if ! modprobe xt_TPROXY; then
    echo 'Kernel not support tproxy, skip UDP rule.'
    exit 0
fi

if ! cat /opt/etc/init.d/S22shadowsocksr |grep '^ARGS=' |grep -qs -e '-u'; then
    echo 'ss-redir not enable udp redir, skip UDP rule.'
    exit 0
fi

iptables -t mangle -N SHADOWSOCKS_UDP
iptables -t mangle -N SHADOWSOCKS_MARK

ip rule add fwmark 1 lookup 100
ip route add local default dev lo table 100

# 两个 ipset 中的 ip 直接返回.
iptables -t mangle -A SHADOWSOCKS_UDP -p udp -m set --match-set CHINAIPS dst -j RETURN
iptables -t mangle -A SHADOWSOCKS_UDP -p udp -m set --match-set CHINAIP dst -j RETURN

# 猜测:
# 1. TPROXY only works in iptables PREROUTING-chain, 即: 在数据包进入路由器时, 这条规则被应用, 使用 tproxy 进行代理.
# 2. --dport 53, 表示进入的包, 目标端口是 53, 也就是 DNS 包.
# 3. --on-ip 192.168.50.1, 表示进入的包, 目标 ip 就是路由器的地址, 即: 192.168.50.1
# 4. --on-port 是 tproxy 模块要代理到的目标, 这里是 1080, 没错了, 它和 --tproxy-mark 0x01/0x01
#    一起配合工作, 表示, 如果有数据包被 mark 为 0x01/0x01, 就转发到 1080 端口
#    这一步, 只是完成了 tproxy 代理的策略, 并没有任何 set mark 操作发生.
iptables -t mangle -A SHADOWSOCKS_UDP -p udp --dport 53 -j TPROXY --on-port $local_redir_port --on-ip $local_redir_ip --tproxy-mark 0x01/0x01

# 猜测:
# 1. 这一步执行真正的 set-mark 操作.
# 2. dnsmasq 会转发所有国内域名之外的域名查询请求到 8.8.4.4(在 dnsmasq 配置中有配置),
#    所有目的地 ip 为 8.8.4.4, 端口为 53 的数据包都将会 setmark 1.
# 3. 这意味着所有的 DNS 数据包都被发往 ss-redir 端口 在 VPS 使用 8.8.4.4 来解析.
iptables -t mangle -A SHADOWSOCKS_MARK -p udp -d 8.8.4.4 --dport 53 -j MARK --set-mark 1

# apply udp rule

# -A 链名 表示新增(append)一条规则到该链, 该规则增加在原本存在规则的最后面.
# 换成 -I 链名 1, 则新插入的规则变为第一条规则.
iptables -t mangle -A PREROUTING -p udp -j SHADOWSOCKS_UDP
# iptables -t mangle -A OUTPUT -p udp -j SHADOWSOCKS_MARK
