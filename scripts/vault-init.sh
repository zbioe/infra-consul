#!/usr/bin/env sh

set -eu

put() {
  path=$1
  key=$2
  value=$3
  vault kv patch "kv/$path" "$key"="$value" 2>/dev/null ||
    vault kv put "kv/$path" "$key"="$value"
}

domain="d"

jq --version || apk add --update jq

vault secrets enable pki
vault secrets tune -max-lease-ttl=8760h pki
vault write -field=certificate pki/root/generate/internal \
  common_name="$domain" \
  ttl=87600h >CA_cert.crt

vault write pki/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

vault write pki/roles/$domain \
  allowed_domains=$domain \
  allow_subdomains=true \
  max_ttl=72h

vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int

vault write -format=json pki_int/intermediate/generate/internal \
  common_name="$domain Intermediate Authority" |
  jq -r '.data.csr' >pki_intermediate.csr

vault write -format=json pki/root/sign-intermediate csr=@pki_intermediate.csr \
  format=pem_bundle ttl="43800h" |
  jq -r '.data.certificate' >intermediate.cert.pem

vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem

vault write pki_int/roles/$domain \
  allowed_domains="$domain" \
  allow_subdomains=true \
  allow_bare_domains=true \
  allow_glob_domains=true \
  allow_any_name=true \
  generate_lease=true \
  max_ttl="720h"

vault policy write ca - <<EOF
path "pki/cert/ca" {
  capabilities = ["read"]
}
EOF

vault policy write server - <<EOF
path "pki_int/issue/${domain}" {
  capabilities = ["create", "update"]
}
path "pki/cert/ca" {
  capabilities = ["read"]
}
path "kv/*" {
  capabilities = ["read"]
}


EOF

vault policy write client - <<EOF
path "pki_int/issue/${domain}" {
  capabilities = ["update"]
}
path "pki/cert/ca" {
  capabilities = ["read"]
}
path "kv/*" {
  capabilities = ["read", "list"]
}

path "pki/*" {
  capabilities = ["read", "list"]
}

path "pki_int/*" {
  capabilities = ["read", "list"]
}

path "pki_exp/*" {
  capabilities = ["read", "list"]
}
path "/sys/mounts" {
  capabilities = ["read"]
}

path "/sys/mounts/connect_root" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "/sys/mounts/connect_inter" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "/connect_root/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "/connect_inter/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

EOF

vault secrets enable -version=2 kv
put consul/config/encryption key 'MFS5Jn2SrIWNNmNbwREZsS+g+iPgjGt4LzI9P0DmjlQ='
vault audit enable file file_path="/tmp/audit.log"
