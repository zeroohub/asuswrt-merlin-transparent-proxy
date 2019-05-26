#!/usr/bin/env python
# -*- coding: utf-8 -*-
import json
from subprocess import check_call, check_output, CalledProcessError

RULE_NAME = "{{ IPTABLES_RULE_NAME }}"


def to_str(s):
    if bytes != str:
        if type(s) == bytes:
            return s.decode('utf-8')
    return s


def call(cmd):
    return to_str(check_output(cmd, shell=True)).strip()


def run(cmd):
    return check_call(cmd, shell=True)


def is_already_setup():
    try:
        count = int(call('iptables -t nat -L {} | wc -l'.format(RULE_NAME)))
        if count == 2:
            run('iptables -t nat -X ' + RULE_NAME)
            return False
        if count == 0:
            return False
        return True
    except CalledProcessError:
        return False


def get_ssr_port():
    with open('{{ SSR_CFG_FILE }}') as f:
        ssr_cfg = json.loads(f.read())
        return ssr_cfg['local_port']


def create_rule():
    command = "iptables -t nat -A {} -p tcp ".format(RULE_NAME)
    run('iptables -t nat -N ' + RULE_NAME)
    run(command + "--dport 853 -j RETURN")
    run(command + "-m set --match-set {{ COMMON_IPSET_LOCAL_NAME }} dst -j RETURN")
    run(command + "-m set --match-set {{ COMMON_IPSET_CHINA_NAME }} dst -j RETURN")
    run(command + "-j REDIRECT --to-ports {}".format(get_ssr_port()))


def apply_rule():
    run('iptables -t nat -A PREROUTING -p tcp -j ' + RULE_NAME)
    run('iptables -t nat -A OUTPUT -p tcp -j ' + RULE_NAME)


if __name__ == '__main__':
    if is_already_setup():
        exit(0)
    create_rule()
    apply_rule()
