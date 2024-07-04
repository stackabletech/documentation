CURRENT_COMMIT := $(shell git rev-parse HEAD)

build-local: build-ui
	node_modules/.bin/antora generate local-antora-playbook.yml

build-only-dev: build-ui
	node_modules/.bin/antora generate only-dev-antora-playbook.yml

build-prod: build-ui
	node_modules/.bin/antora generate antora-playbook.yml --fetch

build-ui:
	node_modules/.bin/gulp --cwd ui bundle

build-search-index:
	npx pagefind --site build/site

serve:
	python3 -m http.server -d build/site

clean:
	rm -rf build
	# 'cache' is the configured cache dir in the playbook
	rm -rf cache

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
		git checkout --recurse-submodules "$${remote#origin/}" ; git pull; \
	done
	# go back to the initial commit to start the build
	git -c advice.detachedHead=false checkout --recurse-submodules $(CURRENT_COMMIT)

netlify-build: netlify-fetch build-prod build-search-index

.PHONY: build-only-dev build-local build-prod build-ui clean netlify-build netlify-fetch
