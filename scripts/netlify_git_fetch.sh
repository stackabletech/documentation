#!/usr/bin/bash

# init submodule
git submodule update --init --recursive

# netlify messes with some files, restore everything to how it was
git reset --hard --recurse-submodule

# save current commit for later
current_commit=$(git rev-parse HEAD)

# update
git fetch --all

# checkout all release branches once, so we fetch the files
for remote in $(git branch -r | grep release/); do
    git checkout --recurse-submodules "${remote#origin/}"
done

# go back to the initial commit to start the build
git -c advice.detachedHead=false checkout --recurse-submodules "$current_commit"

