SHELL := /bin/bash
.PHONY: requirements, install

ROLE_ROOT=roles
ROLE_ELEMENTS={tasks,defaults,meta}

role.%:
	mkdir -p ${ROLE_ROOT}/$*/${ROLE_ELEMENTS}
	touch ${ROLE_ROOT}/$*/${ROLE_ELEMENTS}/main.yml

requirements:
	pip install -qr requirements/base.txt --exists-action w

upgrade: requirements
	pip install pip-tools
 	# Make sure to compile files after any other files they include!
	pip-compile --upgrade -o requirements/base.txt requirements/base.in

install:
	ansible-playbook -i hosts.yml -u dorian my-standard.yml
