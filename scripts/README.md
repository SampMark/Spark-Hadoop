### **scripts/**

#### **Arquivos:**

- `init.sh`: gera dinamicamente o arquivo `docker-compose.yml` a partir de um modelo (`docker-compose.template.yml`), ajustando parâmetros como número de nós workers (variável `NUM_WORKER_NODES`), e aciona o download dos binários (`download_all.sh`).

- `download_all.sh`: baixa pacotes das distribuições do Hadoop, Spark e suas dependências (do S3 ou _mirror_) antes do _build_. Faz verificação de hash SHA512 para garantir integridade.

- `preflight_check.sh`: verifica pré-requisitos (ex.: variáveis de ambiente, conectividade, versões de Java etc.) antes de iniciar o cluster e valida as variáveis no arquivo `.env`, alertando para configurações ausentes ou inválidas antes de iniciar. Em cada checagem importante (p.ex., `command -v java` ou teste de conexão SSH) envia mensagem de erro e encerra imediatamente caso falhe.

- `bootstrap.sh`: é executado dentro de cada contêiner no startup (_master_ e _workers_). Configura chaves SSH para comunicação entre nós, define senhas/usuários necessários, aplica ajustes no ambiente, e no nó master chama o script de inicialização dos serviços Hadoop/Spark. Atualiza lista de workers e, caso seja master, chama `services.sh`.

- `services.sh`:  orquestra (inicia/pára) todos _daemons_ Hadoop (**NameNode**, **DataNode**, **ResourceManager**, **NodeManager**) e Spark (Master, Worker, History Server) no master, isto é,gerencia todo o ciclo de vida dos daemons de um cluster Hadoop/Spark — incluindo HDFS, YARN, MapReduce History Server, Spark History Server, JupyterLab e (opcionalmente) Spark Connect. 


#### Padrões de Codificação (_shell scripts_)

- Os scripts principais (`bootstrap.sh`, `init.sh`, `services.sh`, etc.) começam com `#!/usr/bin/env bash` e definem “fail-fast” `set -euo pipefail` (ou apenas `set -e`) para que em caso de falha o processo seja abortado.

- As versões de Hadoop/Spark, número de nós, nome do usuário e senhas para JupyterLab foram referenciadas em `.env` (exemplo em `.env.example`). O script `bootstrap.sh` verifica a presença dessas variáveis (ex.: `HADOOP_VERSION`, `SPARK_VERSION`, `NUM_WORKER_NODES`) e usa `export` para injetá-las no ambiente.

**Modularidade:**

  * Scripts específicos para cada etapa: `preflight_check.sh` → `init.sh` → `services.sh`.
  * Cada container (master ou worker) compartilha `bootstrap.sh`, mas, via checagem de variável de ambiente (`$IS_MASTER`), decide se chama `services.sh` ou `start_services.sh`.

* **Uso de loops:**

Esta seção explica como os loops são usados ​​nos scripts de configuração do projeto. 

  * A lógica de configuração de múltiplos nós de workers está em `bootstrap.sh`: lê `NUM_WORKER_NODES` e gera `/etc/hadoop/workers` dinamicamente, criando entradas `worker1`, `worker2`, etc.
  * O script automatiza a configuração dos arquivos de configuração SSH, usa ferramentas como ssh-keygen para gerar chaves  (`ssh-keygen`, `ssh-copy-id`) para estabelecer trust entre master e workers. Isso é essencial para clusters Hadoop, pois permite que o nó mestre se comunique e coordene com todos os nós de trabalho de forma segura e automática.