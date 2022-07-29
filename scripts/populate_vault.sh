#!/usr/bin/env bash

set -euo pipefail

function put() {
    datacenter=$1
    value=$2
    key=$3
    vault kv put "secret/$datacenter" "$key"="$value"
}

domain="d"
put c1 domain $domain
put c2 domain $domain
put c1 datacenter_name c1
put c2 datacenter_name c2
put c1 primary_datacenter c1
put c2 primary_datacenter c1
