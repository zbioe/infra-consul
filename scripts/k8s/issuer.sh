#!/usr/bin/env bash
# https://k8s-stag-eastus2-1-dns-70312bdc.hcp.eastus2.azmk8s.io/
kubectl proxy &>/dev/null &
sleep 0.1
curl --silent http://127.0.0.1:8001/api/v1/namespaces/vault/serviceaccounts/default/token \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"apiVersion": "authentication.k8s.io/v1", "kind": "TokenRequest"}' |
  jq -r '.status.token' |
  cut -d . -f2 |
  base64 -d 2>/dev/null |
  jq -r ".iss"

# Kill the background proxy process when you're done
kill %%
