#!/usr/bin/env python
# -*- coding: utf-8 -*-
import json
from subprocess import check_call, check_output, CalledProcessError

RULE_NAME = "{{ IPTABLES_RULE_NAME }}"


def call(cmd):
    return check_output(cmd, shell=True).decode().strip()


def run(cmd, ignore=False):
    try:
        return check_call(cmd, shell=True)
    except CalledProcessError:
        if not ignore:
            raise


def get_ssr_port():
    with open('{{ SSR_REDIR_CFG_FILE }}') as f:
        ssr_cfg = json.loads(f.read())
        return ssr_cfg['local_port']


def create_rule():
    command = f"iptables -t nat -A {RULE_NAME} -p tcp "
    run('iptables -t nat -N ' + RULE_NAME)
    run(command + "--dport 853 -j RETURN")
    run(command + "-m set --match-set {{ COMMON_IPSET_WHITELIST_NAME }} dst -j RETURN")
    run(command + "-m set --match-set {{ COMMON_IPSET_CHINA_NAME }} dst -j RETURN")
    run(command + f"-j REDIRECT --to-ports {get_ssr_port()}")


def apply_rule():
    run('iptables -t nat -A PREROUTING -p tcp -j ' + RULE_NAME)
    run('iptables -t nat -A OUTPUT -p tcp -j ' + RULE_NAME)


def clean_rule():
    run('iptables -t nat -D PREROUTING -p tcp -j ' + RULE_NAME, True)
    run('iptables -t nat -D OUTPUT -p tcp -j ' + RULE_NAME, True)
    run('iptables -t nat -F ' + RULE_NAME, True)
    run('iptables -t nat -X ' + RULE_NAME, True)


if __name__ == '__main__':
    clean_rule()
    create_rule()
    apply_rule()
