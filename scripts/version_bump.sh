#!/usr/bin/env bash
set -euo pipefail

# Creates two commits:
# - the first commit with the new version and tagged
# - the second commit bumped back to nightly

if [ ! $# -eq 1 ]
then
  echo "Version required. I.e.: ./script.sh 22.06"
  exit 1
fi

if [ ! -z "$(git status --porcelain)" ]; then 
  echo "There are uncommitted changes, please resolve before running this script."
  exit 1
fi

export new_version="$1"

docs_dir="$(dirname "$0")/.."
antora_file=$docs_dir/antora.yml

branch_name="version-bump-$new_version"

git checkout -b "$branch_name"


echo "Updating $antora_file to version $new_version"
yq eval --inplace '.version = strenv(new_version)' $antora_file
yq eval --inplace '.prerelease = false' $antora_file

echo "Committing ..."
git add "$antora_file"
git commit -m "Set version $new_version"
git tag -a "docs/$new_version" -m "Documentation for release $new_version"

echo "Updating $antora_file to nightly"
yq eval --inplace '.version = "nightly"' $antora_file
yq eval --inplace '.prerelease = true' $antora_file

echo "Committing..."
git add "$antora_file"
git commit -m "Bumped back to nightly"

echo ""
echo "Done! Please push manually:"
echo "git push --set-upstream origin $branch_name"
