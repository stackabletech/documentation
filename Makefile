CURRENT_COMMIT := $(shell git rev-parse HEAD)

# The build targets differ along two axes:
#
#   Operator docs source:
#     - "local sibling dirs" = reads from ../airflow-operator/docs/, etc. (no network)
#     - "GitHub"             = clones from github.com/stackabletech/* into ./cache/
#                              (pass ANTORAFLAGS=--fetch to update cached repos)
#
#   Documentation repo versions:
#     - "working tree only"               = only your current checkout (incl. uncommitted changes)
#     - "working tree + release branches" = current checkout plus release-25.11, release-25.7, etc.
#
#                        | operator docs from    | documentation versions
#   ---------------------+-----------------------+-------------------------------
#   build-truly-local    | local sibling dirs    | working tree only
#   build-only-dev       | GitHub (main only)    | working tree only
#   build-local          | GitHub (main only)    | working tree + release branches
#   build-prod           | GitHub (all branches) | working tree + release branches
#

# Operator docs from local sibling dirs, working tree only. No network needed.
# Assumes all operator repos are checked out as sibling directories (e.g. ../airflow-operator/).
# Useful when you're working on a change in an operator and want to see your documentation changes rendered
build-truly-local: build-ui
	node_modules/.bin/antora generate truly-local-playbook.yml $(ANTORAFLAGS)

# Operator docs from GitHub (main only), working tree + release branches.
# Use ANTORAFLAGS=--fetch on first run or to update cached operator repos.
build-local: build-ui
	node_modules/.bin/antora generate local-antora-playbook.yml $(ANTORAFLAGS)

# Operator docs from GitHub (main only), working tree only.
# Use ANTORAFLAGS=--fetch on first run or to update cached operator repos.
build-only-dev: build-ui
	node_modules/.bin/antora generate only-dev-antora-playbook.yml $(ANTORAFLAGS)

# Full production build: all branches from all repos. Always fetches from remote.
build-prod: build-ui
	node_modules/.bin/antora generate antora-playbook.yml --fetch $(ANTORAFLAGS)

build-ui:
	node_modules/.bin/gulp --cwd ui bundle

build-search-index:
	npm run build-search-index

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
	for remote in $(shell git branch -r | grep -E 'release[/-]'); do \
		git checkout --recurse-submodules "$${remote#origin/}" ; git pull; \
	done
	# go back to the initial commit to start the build
	git -c advice.detachedHead=false checkout --recurse-submodules $(CURRENT_COMMIT)

netlify-build: netlify-fetch build-prod build-search-index

.PHONY: build-only-dev build-local build-prod build-ui clean netlify-build netlify-fetch
