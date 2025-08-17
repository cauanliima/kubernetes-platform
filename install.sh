#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor

wait_for_app_ready() {
  local APP_NAME="$1"
  local NAMESPACE="argo"

  echo "Aguardando a aplicação '$APP_NAME' no namespace '$NAMESPACE' ficar Healthy..."

  while true; do
    STATUS=$(kubectl get application "$APP_NAME" -n "$NAMESPACE" -o json 2>/dev/null)

    if [ -z "$STATUS" ]; then
      echo "⚠️ Aplicação '$APP_NAME' não encontrada no namespace '$NAMESPACE'."
      sleep 5
      continue
    fi

    HEALTH_STATUS=$(echo "$STATUS" | jq -r '.status.health.status')
    echo "Status atual - Health: $HEALTH_STATUS"

    if [[ "$HEALTH_STATUS" == "Healthy" ]]; then
      echo "✅ Aplicação '$APP_NAME' está Healthy."
      break
    fi

    sleep 5
  done
}

echo "Instalar dependências"
sudo apt-get update -y
sudo apt-get install -y curl wget tar jq

echo "Desabilitando swap temporariamente"
sudo swapoff -a
# Faz backup do fstab antes
sudo cp /etc/fstab /etc/fstab.bak.$(date +%F-%T)
# Comentando linhas de swap no /etc/fstab para desabilitar permanentemente
sudo sed -i '/^[^#].*swap/ s/^/#/' /etc/fstab

echo "Instalar RKE2"
curl -sfL https://get.rke2.io | sh -

echp "Ativar o serviço rke2-server"
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


echo "Configurar o kubeconfig"
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

echo "Configurar provisionardor de volumes"
mkdir /opt/local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "Instalando ArgoCD no cluster"
helm dependency build argocd
helm upgrade -i argocd -n argo ./argocd --create-namespace --wait --timeout 5m


echo "Instalando serviços no cluster"
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

echo "Adicionar chart do dotnet-k8s-math no chartmuseum"
wait_for_app_ready "chartmuseum"
helm plugin install https://github.com/chartmuseum/helm-push.git
helm repo add --username admin --password cauan@123 chartmuseum http://localhost:32180
helm cm-push dotnet-k8s-math/chart chartmuseum -f

echo "Configurar intrumentation de serviços"
wait_for_app_ready "cert-manager"
kubectl apply -f services/openTelemetryOperator/service.yaml
wait_for_app_ready "opentelemetry-operator"
kubectl apply -f services/openTelemetryOperator/intrumentation.yaml

echo "Configurando vault"
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
  bound_service_account_namespaces=python-k8s-vault \
  policies=app-python-policy \
  ttl=24h
EOF

echo "reiniciar serviços que usam vault, instrumentação e chartmuseum"
kubectl rollout restart deployment -n python-k8s-vault
kubectl rollout restart deployment -n dotnet-k8s-math

# Mensagem de término
echo -e "$GREEN✅ Configuração finalizada! $NC"
echo -e "$YELLOW⚠️ Após os serviços subirem, efetue a configuração do Vault e do Grafana. $NC"
echo ""

echo -e "$CYAN🚀 Cluster RKE2 server instalado com sucesso! $NC"
echo -e "Use o seguinte token nos nós workers:"
sudo cat /var/lib/rancher/rke2/server/node-token
echo ""

# Pega as portas NodePort dinamicamente
NETDATA_PORT=$(kubectl get svc netdata -n netdata -o jsonpath='{.spec.ports[0].nodePort}')
GRAFANA_PORT=$(kubectl get svc grafana -n grafana -o jsonpath='{.spec.ports[0].nodePort}')

echo -e "$GREEN✅ Serviços NodePort e credenciais: $NC"
echo "python-app-service : http://localhost:31001"
echo "argocd-server : http://localhost:30080"
echo "chartmuseum : http://localhost:32180"
echo "coroot : http://localhost:30180"
echo -e "grafana : http://localhost:$GRAFANA_PORT"
echo -e "netdata : http://localhost:$NETDATA_PORT"
echo "vault : http://localhost:30280"
echo ""

echo -e "$YELLOW🔑 Credenciais adicionais: $NC"
echo "Vault token root: cauan@123"
echo ""

# Pega senha do grafana via kubectl
GRAFANA_PASS=$(kubectl get secret grafana -n grafana -o jsonpath="{.data.admin-password}" | base64 -d)
echo -e "Grafana senha admin: $GRAFANA_PASS"
echo ""

echo "Chartmuseum senha admin: cauan@123"
echo ""

echo "Faça a importação do dashboard do grafana de forma manual"
