# Plataforma Kubernetes com observabilidade

Plataforma de laboratório para implantar aplicações e serviços de infraestrutura em Kubernetes, com foco em observabilidade, monitoramento e GitOps. O provisionamento combina RKE2, Helm e Argo CD; a coleta e visualização de métricas e traces usa Prometheus, OpenTelemetry, Tempo e Grafana.

## Destaques

- **Instalação automatizada:** o script `install.sh` instala o cluster e inicia os serviços configurados nos manifests.
- **GitOps:** aplicações são declaradas como recursos do Argo CD, com sincronização automática, autocorreção e remoção de recursos que deixaram de existir na fonte.
- **Observabilidade integrada:** instrumentação OpenTelemetry envia telemetria para o Collector, que encaminha métricas ao Prometheus e traces ao Tempo; o Grafana consulta essas fontes.
- **Exemplos observáveis:** APIs .NET e Python, carga contínua, respostas lentas, erros HTTP 500 e manifests de stress permitem explorar cenários operacionais.
- **Ecossistema de apoio:** inclui registry de imagens, repositório de charts Helm, gerenciamento de certificados, segredos e monitoramento complementar.

> **Escopo:** este projeto é uma base de laboratório/demonstração, não uma configuração pronta para produção. Revise capacidade, persistência, autenticação, TLS, políticas de rede, retenção e recuperação antes de qualquer uso em ambiente real.

## Arquitetura e ferramentas

| Ferramenta | Implantação e função |
| --- | --- |
| **RKE2** | Distribuição Kubernetes instalada pelo `install.sh`; executa o cluster. O script habilita o serviço `rke2-server` no nó em que é executado. |
| **kubectl e Helm** | Instalados pelo script e usados para administrar o cluster e implantar charts. |
| **Local Path Provisioner** | Aplicado diretamente pelo script; fornece volumes persistentes usando armazenamento local do nó e configura a classe `local-path` como padrão. |
| **Argo CD** | Instalado pelo chart local em `argocd/`. Gerencia as aplicações definidas em `services/` e sincroniza automaticamente suas configurações. |
| **Ingress NGINX** | Controlador de entrada instalado via Argo CD; permite encaminhar tráfego HTTP para serviços do cluster. |
| **cert-manager** | Instalado via Argo CD com CRDs; automatiza a gestão de certificados Kubernetes e fornece integração para webhooks do OpenTelemetry Operator. |
| **OpenTelemetry Operator** | Instalado via Argo CD; habilita a configuração de instrumentação automática de aplicações. |
| **OpenTelemetry Collector** | Recebe OTLP (gRPC/HTTP), processa e exporta telemetria. Configurado para encaminhar traces ao Tempo e ao Coroot, e expor métricas para coleta pelo Prometheus. |
| **Prometheus** | Coleta métricas, incluindo as expostas pelo Collector. O Alertmanager e o Pushgateway estão desabilitados na configuração atual. |
| **Grafana** | Interface de visualização, com fontes de dados Prometheus e Tempo pré-configuradas e dashboards definidos no chart. O script informa a NodePort atribuída. A importação manual de dashboard adicional ainda pode ser necessária. |
| **Grafana Tempo** | Backend de traces distribuídos, integrado ao Collector e ao Grafana. |
| **Coroot** | Plataforma complementar de observabilidade, configurada com ClickHouse e acesso NodePort; recebe telemetria do Collector. |
| **Netdata** | Monitoramento de métricas do sistema e do cluster; instalado via Argo CD. A NodePort é informada pelo script. |
| **Zabbix** | Monitoramento tradicional com banco PostgreSQL habilitado; configurado no namespace `monitoring`. |
| **HashiCorp Vault** | Armazenamento de segredos. A configuração atual habilita modo de desenvolvimento e o script configura autenticação Kubernetes, um segredo KV e uma policy de demonstração para a aplicação Python. |
| **ChartMuseum** | Repositório Helm usado para publicar o chart da API .NET, que depois é implantado pelo Argo CD. Persistência está desabilitada na configuração atual. |
| **Harbor** | Registry de imagens de contêineres; exposto por NodePorts HTTP e HTTPS. |
| **API .NET de matemática** | Aplicação de exemplo em .NET 8, com endpoints de multiplicação, potência e health check. É empacotada em chart Helm e instrumentada pelo OpenTelemetry Operator. |
| **Aplicação Python / Vault** | Aplicação apontada pelo recurso Argo CD `python-k8s-vault`; demonstra integração da aplicação com segredos e instrumentação. O manifesto referencia um repositório Git externo. |

As definições de serviços ficam em `services/`. A maioria é declarada como recurso `Application` do Argo CD, que obtém o chart Helm de um repositório externo e cria o namespace de destino. O `install.sh` aplica esses manifests, publica o chart .NET no ChartMuseum, aplica a instrumentação e configura o Vault.

## Estrutura do projeto

```text
kubernetes-platform/
├── install.sh                  # Instala o cluster e configura os serviços
├── test.sh                     # Smoke tests HTTP das APIs de exemplo
├── argocd/                     # Chart e valores do Argo CD
├── services/                   # Applications e configurações dos serviços
├── dotnet-k8s-math/            # API .NET e chart Helm
├── python-error-500/           # Exemplo Flask que simula falhas e latência
└── stress_test/                # Manifests para carga, crash e OOM
```

## Pré-requisitos

- Host Linux compatível com os comandos do script, acesso administrativo via `sudo` e conexão à Internet.
- Acesso à Internet para baixar RKE2, kubectl, Helm, charts, imagens e dependências.
- Recursos suficientes no host para executar os serviços de observabilidade e suas dependências (incluindo ClickHouse e PostgreSQL).
- Execução de comandos na pasta `kubernetes-platform/`, pois o script usa caminhos relativos para `argocd/` e `services/`.

O `install.sh` instala pacotes via `apt-get`, desabilita swap e altera `/etc/fstab` para desabilitá-la permanentemente. Ele também habilita e inicia o serviço RKE2 e instala binários no sistema. Leia e adapte o script para o seu ambiente antes de executá-lo.

## Instalação

Em uma máquina Linux preparada para o laboratório:

```bash
cd kubernetes-platform
chmod +x install.sh test.sh
./install.sh
```

Ao final, o script exibe o token de junção de worker e os endereços/portas de alguns serviços. Para adicionar nós, use o token no procedimento de configuração do RKE2 apropriado ao ambiente.

O script não é totalmente não interativo: ele espera que aplicações Argo CD atinjam estado `Healthy` e, após a instalação, ainda orienta a completar configurações do Vault e do Grafana. Verifique a saída do script e o estado das aplicações antes de usar os serviços.

## Acessos

Os acessos NodePort listados pelo script usam `localhost`, o que pressupõe que o navegador ou cliente alcance o nó Kubernetes local. Em cluster remoto, substitua `localhost` pelo endereço de um nó acessível.

| Serviço | Endereço/porta configurado |
| --- | --- |
| Aplicação Python | `http://<nó>:31001` |
| Argo CD | `http://<nó>:30080` |
| ChartMuseum | `http://<nó>:32180` |
| Coroot | `http://<nó>:30180` |
| Grafana | NodePort dinâmica, impressa pelo script |
| Netdata | NodePort dinâmica, impressa pelo script |
| Vault | `http://<nó>:30280` |
| API .NET de matemática | `http://<nó>:31002` |
| Harbor | NodePorts `30002` (HTTP) e `30003` (HTTPS), conforme configurado no manifest |
| Zabbix | NodePort `30580`, conforme configurado no chart |

Os demais serviços podem ser acessados internamente pelo cluster ou por meio de configurações adicionais de Ingress/NodePort. Consulte os manifests de `services/` para os detalhes efetivos.

## Testes e cenários de demonstração

### Smoke tests

Após os pods estarem prontos, execute:

```bash
./test.sh
```

O script envia requisições HTTP à API .NET (`multiply` e `power`) e à rota `/teste` da aplicação Python. São verificações manuais simples de resposta; não constituem uma suíte automatizada com assertions ou validação de códigos HTTP.

### Cenários auxiliares

- `python-error-500/api.py` implementa uma API Flask que pode retornar erro HTTP 500 ou respostas com atraso. O diretório contém manifests e dependências para esse exemplo; ele **não é aplicado automaticamente** pelo `install.sh`.
- `python-error-500/manifest_code_in` contém outro cenário Flask, com rota de sucesso e rota `/error`, além de um Job que envia requisições com falha HTTP 500. Aplique-o apenas quando desejar gerar esse cenário.
- `stress_test/stress.yaml` executa carga de CPU e memória; `manifest_crash` simula um processo que encerra com erro e `manifest_mem-oom` provoca consumo de memória até atingir o limite. Esses manifests também **não são executados automaticamente**.

Os cenários de carga e OOM podem degradar o cluster. Use-os somente em ambiente isolado, monitore o consumo de recursos e remova os workloads após o teste. Por exemplo:

```bash
kubectl apply -f stress_test/stress.yaml
kubectl get pods -n default
kubectl delete -f stress_test/stress.yaml
```

Para inspecionar o estado geral da plataforma:

```bash
kubectl get applications -n argo
kubectl get pods --all-namespaces
kubectl get services --all-namespaces
```

## Segurança e operação

- **Não use credenciais padrão em ambientes compartilhados ou de produção.** Há credenciais e tokens estáticos nos manifests e scripts. Remova-os do código, substitua-os por Secrets/gerenciador de segredos e rotacione qualquer credencial que já tenha sido exposta ou reutilizada.
- O script imprime o token de junção de worker no terminal. Trate essa saída como segredo e não a compartilhe nem a registre em logs públicos.
- O Argo CD está configurado sem autenticação no servidor (`server.disable.auth: true`) e em modo HTTP inseguro. Restrinja esse acesso e configure autenticação e TLS antes de expor o serviço.
- O Vault está em modo de desenvolvimento e usa configuração de demonstração; não oferece a durabilidade ou o modelo de segurança esperados para produção.
- O script baixa e executa componentes externos e aplica versões de charts definidas nos manifests. Revise fontes, versões, permissões e alterações upstream antes de executar.
- O Local Path Provisioner usa armazenamento local do nó; disponibilidade e recuperação dos dados dependem desse nó. Prometheus e ChartMuseum também estão configurados sem persistência habilitada.
- Restrinja NodePorts, monitore consumo de CPU/memória/disco, defina retenção e backups e revise permissões de sincronização automática do Argo CD conforme o ambiente.
