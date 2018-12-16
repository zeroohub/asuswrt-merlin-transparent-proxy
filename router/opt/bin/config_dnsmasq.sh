#!/bin/sh
dnsmasq_dir=/opt/etc/dnsmasq.d
main_conf=/etc/dnsmasq.conf
if [ "$1" == 'remove' ]; then
    echo 'remove dnsmasq...'
    sed -i "s#^conf-dir=$dnsmasq_dir/,\*\.conf##g" $main_conf
    /opt/bin/restart_dnsmasq
    exit 0
fi

echo "install dnsmasq..."

resolv_file=$(cat ${main_conf} |grep 'resolv-file=' |tail -n1 |cut -d'=' -f2)

if [ "$resolv_file" ]; then
    default_dns_ip=$(cat ${resolv_file} |head -n1 |cut -d' ' -f2)
else
    default_dns_ip='114.114.114.114'
fi


if [ -d "$dnsmasq_dir" ]; then

    if ! grep -qs "^conf-dir=$dnsmasq_dir/,\*\.conf$" $main_conf; then
        echo "conf-dir=$dnsmasq_dir/,*.conf" >> $main_conf
    fi

    if ! grep -qs "^log-queries$" $main_conf; then
        echo 'log-queries' >> $main_conf
    fi

    if ! grep -qs "^log-facility=/opt/var/log/dnsmasq\.log$" $main_conf; then
        echo 'log-facility=/opt/var/log/dnsmasq.log' >> $main_conf
    fi

    accelerated=accelerated-domains.china.conf
    google=google.china.conf
    apple=apple.china.conf

    user_domain_name_whitelist=/opt/etc/user_domain_name_whitelist.txt
    user_domain_name_blocklist=/opt/etc/user_domain_name_blocklist.txt
    user_domain_name_gfwlist=/opt/etc/user_domain_name_gfwlist.txt


    sed "s#114\.114\.114\.114#${default_dns_ip}#" $dnsmasq_dir/$accelerated.bak > $dnsmasq_dir/$accelerated
    sed "s#114\.114\.114\.114#${default_dns_ip}#" $dnsmasq_dir/$google.bak > $dnsmasq_dir/$google
    sed "s#114\.114\.114\.114#${default_dns_ip}#" $dnsmasq_dir/$apple.bak > $dnsmasq_dir/$apple

    OLDIFS="$IFS" && IFS=$'\n'
    if [ -f $user_domain_name_whitelist ]; then
        rm -f $dnsmasq_dir/whitelist-domains.china.conf
        for i in $(cat $user_domain_name_whitelist|grep -v '^#'); do
            echo "server=/${i}/${default_dns_ip}" >> $dnsmasq_dir/whitelist-domains.china.conf
        done
    fi

    if [ -f $user_domain_name_blocklist ]; then
        rm -f $dnsmasq_dir/blacklist-domains.china.conf
        for i in $(cat $user_domain_name_blocklist|grep -v '^#'); do
            echo "address=/${i}/127.0.0.1" >> $dnsmasq_dir/blocklist-domains.china.conf
        done
    fi

    if [ -f $user_domain_name_gfwlist ]; then
        for i in $(cat $user_domain_name_gfwlist|grep -v '^#'); do
            sed -i "/server=\/${i}\/.*/d" $dnsmasq_dir/$accelerated
            sed -i "/server=\/${i}\/.*/d" $dnsmasq_dir/$google
            sed -i "/server=\/${i}\/.*/d" $dnsmasq_dir/$apple
        done
    fi
    IFS=$OLDIFS

    /opt/bin/restart_dnsmasq
fi
