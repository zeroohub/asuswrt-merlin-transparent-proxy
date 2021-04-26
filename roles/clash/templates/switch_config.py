#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import base64
import json
from pathlib import Path
from subprocess import check_call, check_output

emoji_pattern = re.compile(
    u"(\ud83d[\ude00-\ude4f])|"  # emoticons
    u"(\ud83c[\udf00-\uffff])|"  # symbols & pictographs (1 of 2)
    u"(\ud83d[\u0000-\uddff])|"  # symbols & pictographs (2 of 2)
    u"(\ud83d[\ude80-\udeff])|"  # transport & map symbols
    u"(\ud83c[\udde0-\uddff])"  # flags (iOS)
    "+", flags=re.UNICODE)


def b64decode(s):
    try:
        s = s.encode("utf8")
    except AttributeError:
        pass
    return base64.urlsafe_b64decode(s + b'=' * (-len(s) % 4)).strip()


def demoji(s):
    return emoji_pattern.sub("", s)


def fromlink(link):
    link = b64decode(link[6:]).decode('utf8')
    params_dict = {}
    if '/' in link:
        data = link.split('/', 1)
        link, param = data
        pos = param.find('?')
        if pos >= 0:
            param = param[pos + 1:]
        params = param.split('&')
        for param in params:
            part = param.split('=', 1)
            if part[0] in ['obfsparam', 'protoparam', 'remarks', 'group']:
                params_dict[part[0]] = b64decode(part[1]).decode('utf8').strip()
            else:
                params_dict[part[0]] = part[1]

        params_dict['obfs_param'] = params_dict.pop('obfsparam', '')
        params_dict['protocol_param'] = params_dict.pop('protoparam', '')

    data = link.split(':')
    if len(data) == 6:
        host = data[0]
        port = int(data[1])
        protocol = data[2]
        method = data[3]
        obfs = data[4]
        passwd = b64decode(data[5]).decode('utf8')

        result = {'server': host, 'server_port': port,
                  'password': passwd, 'protocol': protocol,
                  'method': method, 'obfs': obfs}
        result.update(params_dict)
        output = json.dumps(result, sort_keys=True, indent=4, separators=(',', ': '))
        return output


def parse_data(data):
    links = b64decode(data).split()
    config = [eval(fromlink(l)) for l in links]
    return config


def get_nodes():
    result = []
    base_path = Path('/opt/home/ssr/etc/shadowsocksr/subscribes')
    for fn in base_path.iterdir():
        with fn.open('rb') as f:
            result += parse_data(f.read())
    return result


def apply_config(socks_file, conf):
    with open(socks_file, 'r') as f:
        old_conf = json.loads(f.read())
    with open(socks_file, 'w') as f:
        old_conf.update(conf)
        f.write(json.dumps(old_conf, indent=4))


if __name__ == '__main__':
    nodes = get_nodes()
    nodes = sorted([(f"{n.pop('group')}-{n.pop('remarks')}", n) for n in nodes],
                   key=lambda x: x[0])
    nodes_str = ""
    for idx, (name, node) in enumerate(nodes):
        nodes_str += f"{idx}) {name}\n"
    try:
        print(nodes_str)
    except UnicodeEncodeError:
        print(demoji(nodes_str))
    try:
        num = int(input("choose a node: "))
        conf = nodes[num][1]
    except (ValueError, IndexError):
        print('invalid input')
    else:
        check_output('ipset create -! WHITELIST_IPS hash:net', shell=True)
        dig = check_output(f"dig +short {conf['server']}", shell=True).strip().decode()
        if dig:
            dig = dig.split('\n')[-1]
            check_output(f'ipset add -! WHITELIST_IPS {dig}', shell=True)
        apply_config('/opt/home/ssr/etc/shadowsocksr/local.json', conf)
        apply_config('/opt/home/ssr/etc/shadowsocksr/redir.json', conf)
        check_call('/opt/home/ssr/etc/init.d/S21sslocal restart', shell=True)
        check_call('/opt/home/ssr/etc/init.d/S22ssredir restart', shell=True)
