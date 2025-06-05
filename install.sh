#!/bin/bash

# Instalar dependências
sudo apt-get update -y
sudo apt-get install -y curl wget tar

# Instalar RKE2
curl -sfL https://get.rke2.io | sh -

# Ativar o serviço server
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

# Aguardar o RKE2 iniciar
echo "Aguardando o RKE2 iniciar..."
sleep 20

# Obter o token do cluster para os workers se conectarem
sudo cat /var/lib/rancher/rke2/server/node-token

# Configurar o kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

echo "Cluster RKE2 server instalado com sucesso!"
echo "Use o seguinte token nos nós workers:"
sudo cat /var/lib/rancher/rke2/server/node-token

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

echo "Instalando ArgoCD"
helm dependency build argocd
helm upgrade -i argocd -n argo ./argocd --create-namespace

echo "Instalando serviços"
DIRETORIO=("serviços" "manifests")
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

echo "Configuração finalizada, efetue a configuração do vault e do grafana"
