#!/usr/bin/env bash
set -euo pipefail


trino_version="476"
trino_download_url="https://repo.stackable.tech/repository/packages/trino-cli/trino-cli-${trino_version}-executable.jar"

trino_login() {
    local username="$1"
    local password="$2"


    trino_binary="./trino.jar"

    if [[ ! -f "$trino_binary" ]]; then
        echo "Downloading trino client ...";
        curl -s --output "$trino_binary" "$trino_download_url"
        chmod +x "$trino_binary"
    fi

    trino_addr=$(stackablectl svc list -o json | jq --raw-output '.trino| .[0] | .endpoints | .["coordinator-https"]')

    output=$(echo "$password" | "$trino_binary" --insecure --output-format=CSV_UNQUOTED --server "$trino_addr" --user "$username" --execute "SHOW CATALOGS" --password)

    if [[ "$output" =~ .*system.* ]]; then
        return 0
    fi
    return 1
}

username="alice"
password="alice"

echo "Testing trino login with $username:$password ..."
if trino_login "$username" "$password"; then
    echo "Login sucessful"
else
    echo "Login unsuccessful"
    exit 1
fi
