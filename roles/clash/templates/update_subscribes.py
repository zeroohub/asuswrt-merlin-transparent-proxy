#!/usr/bin/env python
# -*- coding: utf-8 -*-

from urllib.parse import urlparse
from subprocess import CalledProcessError, check_call


def ignore_error_call(cmd):
    try:
        check_call(cmd)
    except:
        pass


def update():
    with open('{{ CLASH_SUBSCRIBES_FILE }}') as f:
        subs = f.read().strip().split("\n")

    for sub in subs:
        url_str = sub.strip()
        if not url_str:
            continue
        url = urlparse(url_str)
        fn = f'{{ CLASH_CFG_DIR }}/{url.hostname.replace(".", "-")}.yaml'
        fn_bk = fn + "_backup"
        ignore_error_call(f"mv {fn} {fn_bk}")
        try:
            check_call(f'curl -L "{url_str}" -o {fn}', shell=True)
        except CalledProcessError:
            ignore_error_call(f"mv {fn_bk} {fn}")
        else:
            ignore_error_call(f"rm {fn_bk}")


if __name__ == '__main__':
    update()
