PLAYBOOK := local-antora-playbook.yml
ANTORAFLAGS :=
CURRENT_COMMIT := $(shell git rev-parse HEAD)


# The netlify repo is checked out without any blobs. This script
# iterates through the release branches and checks them out one-by-one
# to fetch all the files.
# Then we can build directly from here, making it possible to build
# with antora using the HEAD (enabling branch previews!)
netlify-fetch:
	git submodule update --init --recursive
	# netlify messes with some files, restore everything to how it was:
	git reset --hard --recurse-submodule
	# fetch, because netlify does caching and we want to get the latest commits
	git fetch --all
	# checkout all release branches once, so we fetch the files
	for remote in $(shell git branch -r | grep release/); do \
		git checkout --recurse-submodules "$${remote#origin/}" ;\
	done
	# go back to the initial commit to start the build
	git -c advice.detachedHead=false checkout --recurse-submodules $(CURRENT_COMMIT)
.PHONY: netlify-fetch


build:
	node_modules/.bin/gulp --cwd ui bundle
	node_modules/.bin/antora generate $(PLAYBOOK) $(ANTORAFLAGS)

.PHONY: clean


clean:
	rm -r build
	# 'cache' is the configured cache dir in the playbook
	rm -r cache

.PHONY: build
