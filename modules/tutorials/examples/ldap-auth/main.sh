#!/usr/bin/env bash
set -euo pipefail

bash 10-install-release.sh

bash 20-setup-bitnami.sh

bash 30-superset-base.sh

