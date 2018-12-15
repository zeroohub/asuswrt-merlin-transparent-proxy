#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os
import json
import base64
from subprocess import check_call, CalledProcessError, check_output


def to_bytes(s):
    if bytes != str:
        if type(s) == str:
            return s.encode('utf-8')
    return s


def to_str(s):
    if bytes != str:
        if type(s) == bytes:
            return s.decode('utf-8')
    return s


def b64decode(data):
    if b':' in data:
        return data
    if len(data) % 4 == 2:
        data += b'=='
    elif len(data) % 4 == 3:
        data += b'='
    return base64.urlsafe_b64decode(data)


def fromlink(link):
    if link[:6] == 'ssr://':
        link = to_bytes(link[6:])
        link = to_str(b64decode(link))
        params_dict = {}
        if '/' in link:
            datas = link.split('/', 1)
            link = datas[0]
            param = datas[1]
            pos = param.find('?')
            if pos >= 0:
                param = param[pos + 1:]
            params = param.split('&')
            for param in params:
                part = param.split('=', 1)
                if len(part) == 2:
                    if part[0] in ['obfsparam', 'protoparam', 'remarks', 'group']:
                        params_dict[part[0]] = to_str(b64decode(to_bytes(part[1])))
                    else:
                        params_dict[part[0]] = part[1]

        datas = link.split(':')
        if len(datas) == 6:
            host = datas[0]
            port = int(datas[1])
            protocol = datas[2]
            method = datas[3]
            obfs = datas[4]
            passwd = to_str(b64decode(to_bytes(datas[5])))

            result = {}
            result['server'] = host
            result['server_port'] = port
            result['password'] = passwd
            result['protocol'] = protocol
            result['method'] = method
            result['obfs'] = obfs
            result.update(params_dict)
            output = json.dumps(result, sort_keys=True, indent=4, separators=(',', ': '))
            return output


def parse_data(data):
    links = b64decode(data).split()
    config = [eval(fromlink(l)) for l in links]
    return config


def get_nodes():
    result = []
    base_path = '/opt/etc/subscribes'
    for fn in os.listdir(base_path):
        with open(os.path.join(base_path, fn)) as f:
            result += parse_data(f.read())
    return result


def apply_config(conf):
    socks_file = '/opt/etc/shadowsocks.json'
    with open(socks_file, 'r') as f:
        old_conf = json.loads(f.read())
    with open(socks_file, 'w') as f:
        old_conf.update(conf)
        f.write(json.dumps(old_conf, indent=4))


if __name__ == '__main__':
    nodes = get_nodes()
    nodes = sorted([(u"{}-{}".format(n.pop('group'), n.pop('remarks').decode('unicode-escape')), n) for n in nodes],
                   key=lambda x: x[0])
    nodes_str = u""
    for idx, (name, node) in enumerate(nodes):
        nodes_str += u"{}) {}\n".format(idx, name)
    while True:
        print(nodes_str)
        num = input("choose a node: ")
        if isinstance(num, int) and num < len(nodes):
            conf = nodes[num][1]
            apply_config(conf)
            try:
                check_output('ipset add CHINAIP {} 2>&1'.format(conf['server']), shell=True)
            except CalledProcessError as e:
                if "it's already added" in e.output:
                    pass
                else:
                    raise
            check_call('/opt/etc/init.d/S22shadowsocksr restart', shell=True)
            break
        else:
            print("invalid input")
