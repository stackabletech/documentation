#!/usr/bin/env bash
set -euo pipefail

# This script creates a new 'release/{major}.{minor}'  branch for the documetation,
# off of the 'main' branch. 
#
# The script reminds you about some pre-requisites before actually running. These are:
#
# - Write the release notes for the release and have them committed into main.
# - Have the main branch checked out, and up to date with origin. 
# - Have a clean working directory.
#
# This script takes a major.minor.patch version as an argument and
# - updates the antora.yml file accordingly
# - creates a release branch
# - pushes the release branch
#
# Usage:
# make-release-branch.sh -v <version> [-p]
# the version is _required_ and -p for push is optional.
# If you do not push, you have to push manually afterwards with a regular 'git push'

# ------------------------------
# Args parsing
# ------------------------------

version=""
push=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version) version="$2"; shift ;;
        -p|--push) push=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if the required version argument is provided
if [ -z "$version" ]; then
echo "Usage: make-release-branch.sh -v <version> [-p]"
echo "The version needs to be provided as <major>.<minor>.<patch>."
echo "Use -p to automatically push at the end."
exit 1
fi

# Validate the version format (major.minor.patch)
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use the major.minor.patch format."
    exit 1
fi

echo "Settings: Version: $version, Push: $push"

docs_dir="$(dirname "$0")/.."
antora_yaml=$docs_dir/antora.yml

# Extract major.minor part of the version
docs_version=$(echo "$version" | cut -d. -f1,2)

# ------------------------------
# Checking prerequisites
# ------------------------------

# Ask the user if they have written release notes and merged them into main
echo "Release notes for the new version should already be written and commited to the main branch,"
echo "so they show up in both the nightly and future versions, as well as the new release branch"
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

# ------------------------------
# Updating the antora.yaml
# ------------------------------

# Set version key to docs_version
sed -i "s/^version:.*/version: \"$docs_version\"/" "$antora_yaml"

# Set prerelease to false
sed -i "s/^prerelease:.*/prerelease: false/" "$antora_yaml"

# Set crd-docs-version key to the 'version' variable
sed -i "s/^\(\s*\)crd-docs-version:.*/\1crd-docs-version: \"$version\"/" "$antora_yaml"

# Display changes using git diff
git diff "$antora_yaml"

# ------------------------------
# Wrap up: commit and push
# ------------------------------

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

# Push the branch if requested
if [ "$push" = true ]; then
    echo "Pushing changes to origin ..."
    git push origin "$branch_name"
else
    echo "Skipping push to origin. You still need to run:"
    echo "git push origin \"$branch_name\""
    echo "to complete the process."
fi
