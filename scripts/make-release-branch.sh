#!/usr/bin/env bash
set -euo pipefail

# This script creates a new 'release-{major}.{minor}'  branch for the documetation,
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

REMOTE_REF="origin/main"
LOCAL_REF="HEAD"

# ------------------------------
# Args parsing
# ------------------------------

VERSION=""
PUSH=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version) VERSION="$2"; shift ;;
        -p|--push) PUSH=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if the required version argument is provided
if [ -z "$VERSION" ]; then
echo "Usage: make-release-branch.sh -v <version> [-p]"
echo "The version needs to be provided as <major>.<minor>.<patch>."
echo "Use -p to automatically push at the end."
exit 1
fi

# Validate the version format (major.minor.patch)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use the major.minor.patch format."
    exit 1
fi

echo "Settings: Version: $VERSION, Push: $PUSH"

DOCS_DIRECTORY="$(dirname "$0")/.."
ANTORA_YAML_FILE=$DOCS_DIRECTORY/antora.yml

# Extract major.minor part of the version
DOCS_VERSION=$(echo "$VERSION" | cut -d. -f1,2)

# ------------------------------
# Checking prerequisites
# ------------------------------

# Ask the user if they have written release notes and merged them into main
echo "Release notes for the new version should already be written and commited to the main branch,"
echo "so they show up in both the nightly and future versions, as well as the new release branch"
echo "that is about the be created."
read -r -p "Did you already write release notes and merge them into main? (yes/no): " RELEASE_NOTES_ANSWER

# Convert the user input to lowercase for case-insensitive comparison
RELEASE_NOTES_ANSWER_LOWERCASE=$(echo "$RELEASE_NOTES_ANSWER" | tr '[:upper:]' '[:lower:]')

# Check the user's response
if [ "$RELEASE_NOTES_ANSWER_LOWERCASE" != "yes" ]; then
    echo "Please write release notes and merge them into main before running this script."
    exit 1
fi

# Check if on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref $LOCAL_REF)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Not on the main branch. Please switch to the main branch."
    exit 1
fi

# Check if the branch is up to date with the origin
git fetch

if [ "$(git rev-parse $LOCAL_REF)" != "$(git rev-parse $REMOTE_REF)" ]; then
    echo "Your branch is not up to date with the origin main branch."
    echo
    # This lists the local and remote commit hash, commit message, author name and email, and author date
    git log --format="%C(auto, yellow)%h: %Creset%s by %C(auto,yellow)%an <%ae>%Creset at %C(auto,blue)%ad (%S)" "$LOCAL_REF" -1
    git log --format="%C(auto, yellow)%h: %Creset%s by %C(auto,yellow)%an <%ae>%Creset at %C(auto,blue)%ad (%S)" "$REMOTE_REF" -1
    exit 1
fi

# Check if the working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "Working directory is not clean. Please commit or stash your changes."
    exit 1
fi

echo "All checks passed. You are on the main branch, up to date with the origin, and the working directory is clean."

# ------------------------------
# Updating the antora.yaml file
# ------------------------------

# Set version key to docs_version
sed -i "s/^version:.*/version: \"$DOCS_VERSION\"/" "$ANTORA_YAML_FILE"

# Set prerelease to false
sed -i "s/^prerelease:.*/prerelease: false/" "$ANTORA_YAML_FILE"

# Set crd-docs-version key to the 'version' variable
sed -i "s/^\(\s*\)crd-docs-version:.*/\1crd-docs-version: \"$VERSION\"/" "$ANTORA_YAML_FILE"

# Display changes using git diff
git diff "$ANTORA_YAML_FILE"

# ------------------------------
# Wrap up: commit and push
# ------------------------------

# Ask the user whether to proceed
read -r -p "Do you want to proceed with these changes? (yes/no): " PROCEED_ANSWER

# Convert the user input to lowercase for case-insensitive comparison
PROCEED_ANSWER_LOWERCASE=$(echo "$PROCEED_ANSWER" | tr '[:upper:]' '[:lower:]')

# Check the user's response
if [ "$PROCEED_ANSWER_LOWERCASE" != "yes" ]; then
    echo "Aborted. Nothing was committed."
    exit 1
fi

# User wants to proceed
# Checkout a new branch
BRANCH_NAME="release-$DOCS_VERSION"
git checkout -b "$BRANCH_NAME"

# Commit the changes
git add "$ANTORA_YAML_FILE"
git commit -m "chore: Update version in antora.yml to $VERSION"

# Push the branch if requested
if [ "$PUSH" = true ]; then
    echo "Pushing changes to origin ..."
    git push origin "$BRANCH_NAME"
else
    echo "Skipping push to origin. You still need to run:"
    echo "git push origin \"$BRANCH_NAME\""
    echo "to complete the process."
fi
