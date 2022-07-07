PLAYBOOK := local-antora-playbook.yml
ANTORAFLAGS :=

build:
	node_modules/.bin/gulp --cwd ui bundle
	node_modules/.bin/antora generate $(PLAYBOOK) $(ANTORAFLAGS)

clean:
	rm -r build
	# 'cache' is the configured cache dir in the playbook
	rm -r cache

.PHONY: build
