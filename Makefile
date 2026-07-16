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

# The netlify repo is checked out without any blobs. Antora needs local
# release branches and their blobs in the object database, so this target
# creates/updates the local branches and materializes their blobs via
# pathspec checkouts - without ever switching HEAD (enabling branch previews!).
# ui/ is excluded: release branches still reference it as a submodule and
# its blobs are not needed (the UI bundle is built from the current checkout).
netlify-fetch:
	# netlify messes with some files, restore everything to how it was:
	git reset --hard
	# fetch, because netlify does caching and we want to get the latest commits
	git fetch --all
	for remote in $(shell git branch -r | grep -E 'release[/-]'); do \
		branch="$${remote#origin/}"; \
		git fetch -q origin "+refs/heads/$$branch:refs/heads/$$branch"; \
		git checkout -q "$$branch" -- ':(exclude)ui' . ; \
	done
	# restore the working tree of the current commit and drop files that
	# only exist on other branches (ignored files like node_modules stay)
	git reset --hard -q $(CURRENT_COMMIT)
	git clean -fdq

netlify-build: netlify-fetch build-prod build-search-index purge-cache

# Purge the bunny.net pull zone cache after a production build so freshly
# deployed content is served instead of stale cached responses. Skipped when
# the bunny.net credentials are not set (e.g. local builds).
purge-cache:
	@if [ -n "$$BUNNY_API_KEY" ] && [ -n "$$BUNNY_PULL_ZONE_ID" ]; then \
		echo "Purging bunny.net pull zone $$BUNNY_PULL_ZONE_ID"; \
		curl --fail --show-error --silent \
			-X POST "https://api.bunny.net/pullzone/$$BUNNY_PULL_ZONE_ID/purgeCache" \
			-H "AccessKey: $$BUNNY_API_KEY" \
			-H "content-type: application/json"; \
	else \
		echo "Skipping bunny.net purge (BUNNY_API_KEY / BUNNY_PULL_ZONE_ID not set)"; \
	fi

.PHONY: build-only-dev build-local build-prod build-ui clean netlify-build netlify-fetch purge-cache
