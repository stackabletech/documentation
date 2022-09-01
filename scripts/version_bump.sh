#!/usr/bin/env bash
set -euo pipefail

# Creates two commits:
# - the first commit with the new version and tagged
# - the second commit bumped back to nightly

if [ $# -eq 0 ]
then
  echo "Version required. I.e.: ./script.sh 22.06"
  exit 1
fi

docs_dir="$(dirname "$0")/.."
antora_file=$docs_dir/antora.yml

export new_version="$1"

yq eval --inplace '.version = strenv(new_version)' $antora_file
yq eval --inplace '.prerelease = false' $antora_file

git commit -m "Set version $new_version"
git tag -a "docs/$new_version" -m "Documentation for release $new_version"

yq eval --inplace '.version = "nightly"' $antora_file
yq eval --inplace '.prerelease = true' $antora_file

git commit -m "Bumped back to nightly"