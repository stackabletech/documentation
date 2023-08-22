#!/usr/bin/env bash
set -euo pipefail

echo "Installing the base stack"
# tag::stackablectl-install[]
stackablectl stack install trino-superset-s3
# end::stackablectl-install[]