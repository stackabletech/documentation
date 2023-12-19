#!/usr/bin/env bash
set -euo pipefail

# This script takes a major.minor.patch version and
# - updates the antora.yml file accordingly
# - creates a release branch
# - pushes the release branch

# Check if a version argument is provided
if [ -z "$1" ]; then
    echo "Please provide a version as a command-line argument (major.minor.patch)."
    exit 1
fi

# Validate the version format (major.minor.patch)
if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use the major.minor.patch format."
    exit 1
fi

docs_dir="$(dirname "$0")/.."
antora_yaml=$docs_dir/antora.yml

version="$1"

# Extract major.minor part of the version
docs_version=$(echo "$version" | cut -d. -f1,2)

# Ask the user if they have written release notes and merged them into main
echo "Release notes for the new version should already be written and commited to the main branch,"
echo "so the show up in both the nightly and future versions, as well as the new release branch"
echo "that is about the be created."
read -p "Did you already write release notes and merge them into main? (yes/no): " release_notes_answer

# Convert the user input to lowercase for case-insensitive comparison
release_notes_answer_lowercase=$(echo "$release_notes_answer" | tr '[:upper:]' '[:lower:]')

# Check the user's response
if [ "$release_notes_answer_lowercase" != "yes" ]; then
    echo "Please write release notes and merge them into main before running this script."
    exit 1
fi

# Check if on main branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "main" ]; then
    echo "Not on the main branch. Please switch to the main branch."
    exit 1
fi

# Check if the branch is up to date with the origin
git fetch
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "Your branch is not up to date with the origin main branch. Please pull the latest changes."
    exit 1
fi

# Check if the working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "Working directory is not clean. Please commit or stash your changes."
    exit 1
fi

echo "All checks passed. You are on the main branch, up to date with the origin, and the working directory is clean."

# Set version key to docs_version
sed -i "s/^version:.*/version: \"$docs_version\"/" "$antora_yaml"

# Set prerelease to false
sed -i "s/^prerelease:.*/prerelease: false/" "$antora_yaml"

# Set crd-docs-version key to the 'version' variable
sed -i "s/^\(\s*\)crd-docs-version:.*/\1crd-docs-version: \"$version\"/" "$antora_yaml"

# Display changes using git diff
git diff "$antora_yaml"

# Ask the user whether to proceed
read -p "Do you want to proceed with these changes? (yes/no): " proceed_answer

# Convert the user input to lowercase for case-insensitive comparison
proceed_answer_lowercase=$(echo "$proceed_answer" | tr '[:upper:]' '[:lower:]')

# Check the user's response
if [ "$proceed_answer_lowercase" != "yes" ]; then
    echo "Aborted. Nothing was commited."
    exit 1
fi

# User wants to proceed
# Checkout a new branch
branch_name="release/$docs_version"
git checkout -b "$branch_name"

# Commit the changes
git add "$antora_yaml"
git commit -m "Update version in antora.yml to $version"

# Push the branch
git push origin "$branch_name"