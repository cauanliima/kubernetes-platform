#!/bin/bash

wait_for_app_ready() {
  local APP_NAME="$1"
  local NAMESPACE="argo"

  echo "Aguardando o aplicativo '$APP_NAME' no namespace '$NAMESPACE' atingir o estado desejado..."

  while true; do
    STATUS=$(kubectl get application "$APP_NAME" -n "$NAMESPACE" -o json 2>/dev/null)

    if [ -z "$STATUS" ]; then
      echo "Aplicação '$APP_NAME' não encontrada no namespace '$NAMESPACE'."
      sleep 5
      continue
    fi

    SYNC_STATUS=$(echo "$STATUS" | jq -r '.status.sync.status')
    HEALTH_STATUS=$(echo "$STATUS" | jq -r '.status.health.status')

    echo "Sync: $SYNC_STATUS | Health: $HEALTH_STATUS"

    if [[ "$SYNC_STATUS" == "$HEALTH_STATUS" ]]; then
      echo "✅ A aplicação '$APP_NAME' atingiu o estado desejado: $SYNC_STATUS"
      break
    fi

    sleep 5
  done
}

# Instalar dependências
sudo apt-get update -y
sudo apt-get install -y curl wget tar jq

# Instalar RKE2
curl -sfL https://get.rke2.io | sh -

# Ativar o serviço server
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service


# Instalando serviços e programas

echo "Instalando o kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /bin/


echo "Instalando Helm"
wget https://get.helm.sh/helm-v3.14.2-linux-amd64.tar.gz
tar -zxvf helm-v3.14.2-linux-amd64.tar.gz
rm helm-v3.14.2-linux-amd64.tar.gz
chmod +x  linux-amd64/helm
mv  linux-amd64/helm /bin
rm -r linux-amd64

echo "Aguardando o serviço rke2-server ficar ativo..."
while true; do
    STATUS=$(systemctl is-active rke2-server)

    if [ "$STATUS" = "active" ]; then
        echo "✅ Serviço rke2-server está ativo!"
        break
    else
        echo "⏳ Status atual: $STATUS. Verificando novamente em 2 segundos..."
        sleep 2
    fi
done

# Obter o token do cluster para os workers se conectarem
sudo cat /var/lib/rancher/rke2/server/node-token

# Configurar o kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

echo "Cluster RKE2 server instalado com sucesso!"
echo "Use o seguinte token nos nós workers:"
sudo cat /var/lib/rancher/rke2/server/node-token


mkdir /opt/local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml

kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "Instalando ArgoCD"
helm dependency build argocd
helm upgrade -i argocd -n argo ./argocd --create-namespace --wait --timeout 5m

helm plugin install https://github.com/chartmuseum/helm-push.git
helm repo add --username admin --password cauan@123 chartmuseum http://localhost:32180
helm cm-push dotnet-k8s-math/chart chartmuseum

echo "Instalando serviços"
DIRETORIO=("services")
for dir in "${DIRETORIO[@]}"; do
  # Verificar se o diretório existe
  if [ -d "$dir" ]; then
    echo "🔍 Aplicando arquivos no diretório: $dir"
    # Procurar arquivos .yaml e .yml dentro do diretório
    for arquivo in "$dir"/*.yaml "$dir"/*.yml; do
      if [ -f "$arquivo" ]; then
        echo "🚀 Aplicando $arquivo..."
        kubectl apply -f "$arquivo"
      fi
    done
  fi
done

# Configurar intrumentation de serviços
wait_for_app_ready "cert-manager"

kubectl apply -f manifests/intrumentation.yaml

kubectl rollout restart deployment -n python-k8s-vault
kubectl rollout restart deployment -n dotnet-k8s-math


#Configuração vault
wait_for_app_ready "vault"

VAULT_TOKEN=cauan@123

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


#Avisos
echo "Acesse o argocd IP:30080"
echo "Configuração finalizada, após is serviços subirem efetue a configuração do vault e do grafana"
