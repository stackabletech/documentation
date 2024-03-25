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

docs_version=""
push=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version) docs_version="$2"; shift ;;
        -p|--push) push=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if the required version argument is provided
if [ -z "$docs_version" ]; then
echo "Usage: publish-new-version.sh -v <version> [-p]"
echo "The version needs to be provided as <major>.<minor>."
echo "Use -p to automatically push at the end."
exit 1
fi

# Validate the version format (major.minor.patch)
if [[ ! "$docs_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use the major.minor format."
    exit 1
fi

# Define the branches to add. The documentation repo uses a '/' while the operators use a '-'
docs_branch="release/$docs_version"
operator_branch="release-$docs_version"

# ------------------------------
# Checking prerequisites
# ------------------------------

# Check if the release branch exists upstream
if ! git rev-parse --quiet --verify "$docs_branch" > /dev/null; then
    echo "Release branch '$docs_branch' is missing upstream in the documentation repository."
    echo "Please create the $docs_branch branch first using the make-release-branch.sh script."
    echo "Aborting."
    exit 1
fi

echo "Did you create all the release branches in the operators?"
echo "Did you also create a release branch in the demos repository?"
read -p "(yes/no): " operators_branches_answer

# Convert the user input to lowercase for case-insensitive comparison
operators_branches_answer_lowercase=$(echo "$operators_branches_answer" | tr '[:upper:]' '[:lower:]')

if [ "$operators_branches_answer_lowercase" != "yes" ]; then
    echo "Please create all the branches in the operators before proceeding."
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

echo "All checks passed."

# ------------------------------
# Updating playbooks
# ------------------------------

echo "Updating playbooks."

# Define the branches to add. The documentation repo uses a '/' while the operators use a '-'
docs_branch="release/$docs_version"
operator_branch="release-$docs_version"
insert_position=1

docs_dir="$(dirname "$0")/.."
playbook_files=("$docs_dir/antora-playbook.yml" "$docs_dir/local-antora-playbook.yml")

# Loop through each playbook file
for yaml_file in "${playbook_files[@]}"; do
    # Insert the docs_branch
    yq ".content.sources[0].branches |= (.[:$insert_position] + [\"$docs_branch\"] + .[$insert_position:])" -i "$yaml_file"

    # Update all the operator and demos sources.
    yq "with(.content.sources.[]; select(.url |test(\".*(operator|demos).*\")) | .branches |= .[:$insert_position] + [\"$operator_branch\"] + .[$insert_position:])" -i "$yaml_file"
done

# ------------------------------
# Wrap up: commit and push
# ------------------------------

# Display changes and ask for user confirmation
git diff
read -p "Do you want to proceed with these changes? (yes/no): " proceed_answer

# Convert the user input to lowercase for case-insensitive comparison
proceed_answer_lowercase=$(echo "$proceed_answer" | tr '[:upper:]' '[:lower:]')

# Check the user's response
if [ "$proceed_answer_lowercase" != "yes" ]; then
    echo "Aborted. Nothing was commited."
    exit 1
fi

publish_branch="publish-$docs_version"

git checkout -b "$publish_branch"

git add .
git commit -m "Add release branches to the playbooks for release $docs_version."

# Push the branch if requested
if [ "$push" = true ]; then
    echo "Pushing changes to origin ..."
    git push -u origin "$publish_branch"
else
    echo "Skipping push to origin."
fi

echo "The changes have been pushed to GitHub!"
echo "Click the link above to create the PR in GitHub, and then verify that the build works with Netlify previews."
echo "Once the branch is merged, the changes are live."