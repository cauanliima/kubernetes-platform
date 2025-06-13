read -s -p "Digite o Vault Token: " VAULT_TOKEN
echo

kubectl exec -i vault-0 -n vault -- /bin/sh <<EOF
vault login $VAULT_TOKEN

vault auth enable kubernetes

vault write auth/kubernetes/config \
  kubernetes_host="https://\$KUBERNETES_PORT_443_TCP_ADDR:443"

vault secrets enable -path=app -version=2 kv

vault kv put app/python teste="teste"

vault policy write app-python-policy - <<EOP
path "app/data/python" {
   capabilities = ["read"]
}
EOP

vault write auth/kubernetes/role/app-python-role \
  bound_service_account_names="*" \
  bound_service_account_namespaces=app \
  policies=app-python-policy \
  ttl=24h
EOF
