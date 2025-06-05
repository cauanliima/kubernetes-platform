kubectl exec -it vault-0 -- /bin/sh

vault login
vault auth enable kubernetes
vault write auth/kubernetes/config \
      kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
vault policy write app-python-policy - <<EOF
path "app/data/python" {
   capabilities = ["read"]
}
EOF
vault write auth/kubernetes/role/app-python-role \
      bound_service_account_names="*" \
      bound_service_account_namespaces=app \
      policies=app-python-policy \
      ttl=24h
