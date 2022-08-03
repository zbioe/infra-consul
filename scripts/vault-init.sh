#!/usr/bin/env sh

set -euo pipefail

function put() {
    secret=$1
    key=$2
    value=$3
    vault kv patch "secret/$secret" "$key"="$value" 2>/dev/null ||
        vault kv put "secret/$secret" "$key"="$value"
}

secret="consul"
domain="d"

jq --version || apk add --update jq

vault secrets enable pki
vault secrets tune -max-lease-ttl=8760h pki
vault write pki/root/generate/internal \
    common_name=$domain \
    ttl=8760h

vault write pki/config/urls \
    issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
    crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

vault write pki/roles/$domain \
    allowed_domains=$domain \
    allow_subdomains=true \
    max_ttl=72h

vault write -field=certificate pki/root/generate/internal \
    common_name="$domain" \
    ttl=87600h >CA_cert.crt

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

put $secret encryption.hcl 'encrypt = "MFS5Jn2SrIWNNmNbwREZsS+g+iPgjGt4LzI9P0DmjlQ="'
put $secret encryption 'MFS5Jn2SrIWNNmNbwREZsS+g+iPgjGt4LzI9P0DmjlQ='
