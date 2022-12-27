#!/usr/bin/env bash
set -euo pipefail

echo "Installing release"
# tag::stackablectl-release-install[]
stackablectl release install 22.11
# end::stackablectl-release-install[]