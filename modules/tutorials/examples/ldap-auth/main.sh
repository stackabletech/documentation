#!/usr/bin/env bash
set -euo pipefail

for script in $(find -name '[0-9][0-9]*sh' | sort)
do
    echo "Executing $script"
    bash $script
done