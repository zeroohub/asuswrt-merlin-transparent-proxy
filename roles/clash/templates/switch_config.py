#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
from pathlib import Path
from subprocess import check_call
from yaml import load, Loader, dump, Dumper

root = Path("{{ CLASH_CFG_DIR }}")


def export_config(name):
    override = root / "config.yaml.override"
    sub = root / name
    config = root / 'config.yaml'
    with sub.open() as f:
        sub_dict = load(f.read(), Loader=Loader)
    with override.open() as f:
        override_dict = load(f.read(), Loader=Loader)
    sub_dict.update(override_dict)
    with config.open('w') as f:
        f.write(dump(sub_dict, Dumper=Dumper))


if __name__ == '__main__':
    name = sys.argv[1]
    export_config(name)
    check_call('{{ CLASH_INITD_FILE }} restart', shell=True)
1
