#!/usr/bin/env bash
set -euo pipefail

# This script should be used as part of the release process of a new platform version.
# It updates all the playbook files to include the new release branches of the operators
# as well as the documentation itself (use the make-release-branch.sh script first).
#
# These pre-requisites get checked by the script:
# - all the operators have release branches
# - the documentation has a release branch with the correct name
# - main branch of the documentation is checked out, up to date and working directory clean.
#
# Run the script without arguments to get the usage instructions.

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: 'yq' is not installed. It is needed to update yaml files later in the script."
    echo "This script was tested with yq v4.40.5"
    echo "Please install 'yq' from https://github.com/mikefarah/yq and then run the script again."
    exit 1
fi

# ------------------------------
# Args parsing
# ------------------------------

DOCS_VERSION=""
PUSH=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version) DOCS_VERSION="$2"; shift ;;
        -p|--push) PUSH=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if the required version argument is provided
if [ -z "$DOCS_VERSION" ]; then
echo "Usage: publish-new-version.sh -v <version> [-p]"
echo "The version needs to be provided as <major>.<minor>."
echo "Use -p to automatically push at the end."
exit 1
fi

# Validate the version format (major.minor.patch)
if [[ ! "$DOCS_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use the major.minor format."
    exit 1
fi

BRANCH="release-$DOCS_VERSION"

# ------------------------------
# Checking prerequisites
# ------------------------------

# Check if the release branch exists upstream
if ! git rev-parse --quiet --verify "$BRANCH" > /dev/null; then
    echo "Release branch '$BRANCH' is missing upstream in the documentation repository."
    echo "Please create the $BRANCH branch first using the make-release-branch.sh script."
    echo "Aborting."
    exit 1
fi

echo "Did you create all the release branches in the operators?"
echo "Did you also create a release branch in the demos repository?"
read -r -p "(yes/no): " OPERATORS_BRANCHES_ANSWER

# Convert the user input to lowercase for case-insensitive comparison
OPERATORS_BRANCHES_ANSWER_LOWERCASE=$(echo "$OPERATORS_BRANCHES_ANSWER" | tr '[:upper:]' '[:lower:]')

if [ "$OPERATORS_BRANCHES_ANSWER_LOWERCASE" != "yes" ]; then
    echo "Please create all the branches in the operators before proceeding."
    exit 1
fi

# Check if on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
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

echo "All checks passed."

# ------------------------------
# Updating playbooks
# ------------------------------

echo "Updating playbooks."

DOCS_DIRECTORY="$(dirname "$0")/.."
PLAYBOOK_FILES=("$DOCS_DIRECTORY/antora-playbook.yml" "$DOCS_DIRECTORY/local-antora-playbook.yml")

# Loop through each playbook file
for yaml_file in "${PLAYBOOK_FILES[@]}"; do
    # Update all sources except stackable-cockpit.
    yq "with(.content.sources.[]; select(.url | test(\".*(stackable-cockpit).*\") | not) | .branches |= .[:1] + [\"release-25.7\"] + .[1:])" -i "$yaml_file"
done

# ------------------------------
# Wrap up: commit and push
# ------------------------------

# Display changes and ask for user confirmation
git diff
read -r -p "Do you want to proceed with these changes? (yes/no): " PROCEED_ANSWER

# Convert the user input to lowercase for case-insensitive comparison
PROCEED_ANSWER_LOWERCASE=$(echo "$PROCEED_ANSWER" | tr '[:upper:]' '[:lower:]')

# Check the user's response
if [ "$PROCEED_ANSWER_LOWERCASE" != "yes" ]; then
    echo "Aborted. Nothing was committed."
    exit 1
fi

PR_BRANCH="pr-$DOCS_VERSION"

git checkout -b "$PR_BRANCH"

git add .
git commit -m "chore: Add release branches to the playbooks for release $DOCS_VERSION"

# Push the branch if requested
if [ "$PUSH" = true ]; then
    echo "Pushing changes to origin ..."
    git push -u origin "$PR_BRANCH"
    echo ""
    echo "The changes have been pushed to GitHub!"
    echo "Raise the PR against the main branch."
    echo "Click the link above to create the PR in GitHub, and then verify that the build works with Netlify previews."
    echo "Once the branch is merged, the changes will automatically be deployed and be live."
else
    echo ""
    echo "Skipping push to origin."
    echo "Please push the branch manually and create PR."
    echo "Raise the PR against the main branch."
    echo "Once the changes are merged, they will automatically be deployed and be live."
fi
