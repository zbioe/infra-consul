#!/usr/bin/env bash

set -euo pipefail

env=${1:-local}

for ip in $(${pkgs.jq}/bin/jq -r '.[].value.ip.pub' ./env/$env/output.json); do
    ssh-keygen -R "$ip"
done
