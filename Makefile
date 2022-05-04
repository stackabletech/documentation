PLAYBOOK := local-antora-playbook.yml
ANTORAFLAGS :=

build:
	node_modules/.bin/gulp --cwd ui bundle
	node_modules/.bin/antora generate $(PLAYBOOK) $(ANTORAFLAGS)

.PHONY: build
