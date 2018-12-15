#!/usr/bin/env python
# -*- coding: utf-8 -*-

from urlparse import urlparse
import os
from subprocess import check_output

def update():
    result = []
    with open('/opt/etc/subscribes.txt') as f:
        subs = f.readlines()

    try:
        os.makedirs('/opt/etc/subscribes')
    except OSError:
        pass

    for sub in subs:
        url = sub.strip()
        output = check_output('curl -L {}'.format(url), shell=True)
        with open('/opt/etc/subscribes/{}'.format(urlparse(url).hostname), 'wb') as f:
            f.write(output)

    return result


if __name__ == '__main__':
    update()
