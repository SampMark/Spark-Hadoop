### **scripts/**

#### **Arquivos:**

- `bootstrap.sh`: é executado em cada container (_master_ e _workers_), define `set -e` (erro aborta script), valida variáveis de ambiente, configura SSH, define senhas, atualiza lista de workers e, caso seja master, chama `services.sh`.

- `init.sh`: inicializa diretórios HDFS (`namenode`, `datanode`) e formata HDFS no master.

- `preflight_check.sh`: Verifica pré-requisitos (ex.: variáveis de ambiente, conectividade, versões de Java etc.) antes de iniciar o cluster. Em cada checagem importante (p.ex., `command -v java` ou teste de conexão SSH) envia mensagem de erro e encerra imediatamente caso falhe.


- `services.sh`: inicia/para _daemons_ Hadoop (**NameNode**, **DataNode**, **ResourceManager**, **NodeManager**) e Spark (Master, Worker, History Server) no master.

- `start_services.sh`: chamado pelos _workers_ para iniciar serviços específicos (**DataNode**, **NodeManager**, **Spark Worker**).

- `download_all.sh`: baixa pacotes do Hadoop, Spark e suas dependências (do S3 ou mirror) antes do _build_.

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