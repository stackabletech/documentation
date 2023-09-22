PLAYBOOK := local-antora-playbook.yml
ANTORAFLAGS :=

build:
	node_modules/.bin/gulp --cwd ui bundle
	node_modules/.bin/antora generate $(PLAYBOOK) $(ANTORAFLAGS)

.PHONY: clean
clean:
	rm -rf build
	# 'cache' is the configured cache dir in the playbook
	rm -rf cache

.PHONY: build
