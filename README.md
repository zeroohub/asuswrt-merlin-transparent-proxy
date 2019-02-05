# Transparent Proxy setup for Asuswrt-Merlin

Ansible scripts for setting up transparent proxy on **Asuswrt-Merlin** firmware.   

## Features

- DNS over TLS with stubby
- ShadowsocksR
  - subscribes
  - China ip whitelist mode
- swapfile
- Adblock with dnsmasq

## Quick Start

This script has only been tested on **AC5300**, but it should work on all routers with **official merlin** firmware installed.

### Prerequisite

Before running script you need to:

1. Setup ssh login on your router.
2. Prepare a usb key, format it to ext2|ext3|ext4, plug on your router.
3. Running `sh entware-setup.sh` on your router's console. 
4. Install `python` on your router.
5. Install [`ansible`](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) on your own computer. 

### Install

To install everything on your Router:

1. Change some variables in `standard.yml` file.
   - `STUBBY_DNS_PROVIDERS`: Upstream dns resolver. If you are in China, keep the default.
   - `SSR_DEFAULT_NODE`: Default node of your SSR server (or from provider).
   - `SSR_SUBSCRIBES`: Subscribe links, if you don't have one, change it to `[]`.
2. (Optional) Change `hosts` in `hosts.yml` file. Usually keep default.
3. Running `ansible-playbook -i hosts.yml -u <router_login_name> standard.yml`. 
   - If you didn't config ssh-key for login, you need to append `-k` before `standard.yml`

## See Also:

- [ruby fish dns](https://www.rubyfish.cn/), the default upstream dns resolver for China

## TODOs

- Add tags 
- Able to rollback
- Add more doc

## License

This project is under [MIT](LICENSE) license.
