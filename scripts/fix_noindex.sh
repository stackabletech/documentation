#!/usr/bin/env bash
set -euo pipefail


index_file="$(dirname "$0")/../build/site/index.html"

sed -i '/noindex/d' $index_file
