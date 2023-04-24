#!/usr/bin/bash

current_branch=$(git branch --show-current)

git fetch --all

git stash

for remote in $(git branch -r | grep release/); do
    git switch "${remote#origin/}"
done

git switch "$current_branch"

git stash pop
