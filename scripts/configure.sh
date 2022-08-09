#!/bin/sh

dir="$(dirname -- "$(readlink -f -- "$0")")"

vnamespace=vault
cnamespace=consul

vault auth disable k1
vault auth enable -path=k1 kubernetes
# kubectl delete namespace vault --ignore-not-found=true

# helm install vault hashicorp/vault \
#     --create-namespace --namespace $vnamespace \
#     --values "$dir/helm/vault-injector.yml"
# sleep 10

VAULT_HELM_SECRET_NAME=$(kubectl get secrets --namespace $vnamespace --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')
kubectl describe secret --namespace $vnamespace "$VAULT_HELM_SECRET_NAME"

TOKEN_REVIEW_JWT=$(kubectl get secret --namespace $vnamespace "$VAULT_HELM_SECRET_NAME" --output='go-template={{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --namespace $vnamespace --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --namespace $vnamespace --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')
issuer=$("$dir/issuer.sh" $vnamespace | cut -f2 -d\")

#
vault write auth/k1/config \
    token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
    kubernetes_host="$KUBE_HOST" \
    kubernetes_ca_cert="$KUBE_CA_CERT" \
    issuer="$issuer" # kubernetes_host="https://kubernetes.default:42511" \

vault write auth/k1/role/d \
    bound_service_account_names="*" \
    bound_service_account_namespaces="*" \
    policies="root" \
    ttl=24h

# kubectl delete namespace consul --ignore-not-found=true
# helm install consul hashicorp/consul --create-namespace -n $cnamespace --values "$dir/helm/k1.yaml"
