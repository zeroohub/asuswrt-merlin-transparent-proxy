#!/usr/bin/env python
# -*- coding: utf-8 -*-

from urllib.parse import urlparse
from subprocess import CalledProcessError, check_call


def update():
    with open('{{ CLASH_SUBSCRIBES_FILE }}') as f:
        subs = f.readlines()

    for sub in subs:
        url_str = sub.strip()
        url = urlparse(url_str)
        fn = f'{{ CLASH_SUBSCRIBES_FILE }}/{url.hostname.replace(".", "-")}.yaml'
        fn_bk = fn + "_backup"
        check_call(f"mv {fn} {fn_bk}", shell=True)
        try:
            check_call(f'curl -L {url_str} -o {fn}', shell=True)
        except CalledProcessError:
            check_call(f"mv {fn_bk} {fn}", shell=True)
        else:
            check_call(f"rm {fn_bk}", shell=True)


if __name__ == '__main__':
    update()
