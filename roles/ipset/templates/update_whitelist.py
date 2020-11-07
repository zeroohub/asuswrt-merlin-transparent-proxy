#!/usr/bin/env python
# -*- coding: utf-8 -*-
from subprocess import check_output
import math
import json
import sys


def call(cmd):
    return check_output(cmd, shell=True).decode().strip()


def create_ipset(name):
    call(f"ipset create -! {name} hash:net")  # make sure sets exist, ignore error


def add_to_ipset(name, ip):
    call(f"ipset add -! {name} {ip}")


def del_from_ipset(name, ip):
    call(f"ipset del -! {name} {ip}")


def list_ipset(name):
    return call(f"ipset list {name}").split('\n')[8:]


def update_china_ips(skip=False):
    ipset_name = "{{ COMMON_IPSET_CHINA_NAME }}"
    create_ipset(ipset_name)
    if not skip:
        call("curl -C - -L 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' -o {{ IPSET_APNIC_FILE }}")
    with open('{{ IPSET_APNIC_FILE }}') as f:
        result = f.read()
    china_ips = [ip.split('|')[3:5] for ip in result.split('\n') if 'CN|ipv4' in ip]
    china_nets = {f"{ip}/{32 - int(math.log(float(num), 2))}" for ip, num in china_ips}
    existing_nets = set(list_ipset(ipset_name))
    for net in existing_nets:
        if net not in china_nets:
            del_from_ipset(ipset_name, net)
    for net in china_nets:
        if net not in existing_nets:
            add_to_ipset(ipset_name, net)


def update_whitelist_ips():
    ipset_name = "{{ COMMON_IPSET_WHITELIST_NAME }}"
    create_ipset(ipset_name)
    with open('{{ IPSET_WHITELIST_FILE }}', "r") as f:
        local_nets = set([line.strip() for line in f.readlines()])

    existing_nets = set(list_ipset(ipset_name))
    for net in existing_nets:
        if net not in local_nets:
            del_from_ipset(ipset_name, net)
    for net in local_nets:
        if net not in existing_nets:
            add_to_ipset(ipset_name, net)

    with open('{{ SSR_REDIR_CFG_FILE }}') as f:
        ssr_cfg = json.loads(f.read())
    add_to_ipset(ipset_name, f"-r {ssr_cfg['server']}")


if __name__ == '__main__':
    skip = False
    if len(sys.argv) > 1:
        skip = True
    update_china_ips(skip)
    update_whitelist_ips()
