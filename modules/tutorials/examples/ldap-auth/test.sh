#!/usr/bin/env bash
set -euxo pipefail
shopt -s lastpipe

sleep 5 | echo -n lala | read myvar
echo $myvar
