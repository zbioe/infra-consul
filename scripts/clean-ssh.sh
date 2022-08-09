#!/usr/bin/env bash

set -euo pipefail

env=${1:-"*"}

for ip in $(jq -r '.[].value.ip.pub' ./env/$env/output.json); do
    ssh-keygen -R "$ip"
done
