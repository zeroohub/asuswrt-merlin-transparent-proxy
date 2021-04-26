#!/usr/bin/env python
# -*- coding: utf-8 -*-
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


def create_rule():
    command = f"iptables -t nat -A {RULE_NAME} "
    run('iptables -t nat -N ' + RULE_NAME)
    run(command + "-d 192.168.0.0/16 -j RETURN")
    run(command + "-p tcp -j REDIRECT --to-ports {{ CLASH_REDIR_PORT }}")


def apply_rule():
    run('iptables -t nat -A PREROUTING -p tcp --dport 22 -j ACCEPT')
    run(f'iptables -t nat -A PREROUTING -j {RULE_NAME}')
    run('iptables -t nat -A PREROUTING -p udp -m udp --dport 53 -j DNAT --to-destination 192.168.50.1:{{ CLASH_DNS_PORT }}')


def clean_rule():
    run('iptables -t nat -D PREROUTING -p udp -m udp', True)
    run(f'iptables -t nat -D PREROUTING -j {RULE_NAME}', True)
    run('iptables -t nat -D PREROUTING -p tcp --dport 22 -j ACCEPT', True)


if __name__ == '__main__':
    clean_rule()
    create_rule()
    apply_rule()
