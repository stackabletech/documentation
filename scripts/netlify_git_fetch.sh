#!/usr/bin/bash

# netlify messes with some files, restore everything to how it was
git restore .
git submodule foreach git reset --hard

# save current commit for later
current_commit=$(git rev-parse HEAD)

# update
git fetch --all

# checkout all release branches once, so we fetch the files
for remote in $(git branch -r | grep release/); do
    git switch "${remote#origin/}"
done

# go back to the initial commit to start the build
git checkout "$current_commit"

