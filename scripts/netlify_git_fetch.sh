#!/usr/bin/bash

current_commit=$(git rev-parse HEAD)

git fetch --all

git stash

for remote in $(git branch -r | grep release/); do
    git switch "${remote#origin/}"
done

git checkout "$current_commit"

git stash pop
