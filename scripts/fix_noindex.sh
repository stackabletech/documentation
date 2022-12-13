#!/usr/bin/env bash
set -euo pipefail

# This script removes the 'noindex' meta tag from the main entrypoint into the docs.
# The index.html is a 301 redirect to the /home/stable/index.html path, where the landing page is.
# 
# We have problems with Google not indexing the docs, and we hope that this might fix these
# problems. 
#
# The github issue: https://github.com/stackabletech/documentation/issues/324

index_file="$(dirname "$0")/../build/site/index.html"

sed -i '/noindex/d' $index_file
