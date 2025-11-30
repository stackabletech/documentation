#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for script in $(find . -name '[0-9][0-9]*sh' | sort)
do
    printf "##########################################\n"
    printf '#  %-38s#\n' "$script"
    printf "##########################################\n"
    bash "$script"
done