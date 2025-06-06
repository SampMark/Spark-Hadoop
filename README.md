# Implantação de clusters Spark-Hadoop (_Cluster Deployment_) com ambiente Docker

## 1. Visão Geral

O repositório **Spark-Hadoop** é projetado para provisionar, via Docker e Docker Compose, um cluster que combina o **Apache Spark** e **Apache Hadoop**, com integração ao **JupyterLab**.O objetivo é oferecer um ambiente “_all-in-one_” (completo e isolado) para estudos, desenvolvimento e testes de aplicações em Big Data, tornando simples os procedimentos de:

1. Implantar clusters Spark + Hadoop em _containers_ isolados;
2. Acessar a dashboards web (HDFS, YARN, Spark UI, JupyterLab) via mapeamento de portas;
3. Rodar jobs MapReduce e Spark, inclusive com notebooks interativos.

O ambiente Docker provisiona um cluster distribuído que combina:
- **Apache Hadoop 3.4.x** (HDFS para armazenamento distribuído + YARN para gerenciamento de recursos).
- **Apache Spark 3.3.x** (para processamento de dados em larga escala).
- **JupyterLab** (para computação interativa com kernels PySpark).

A **arquitetura padrão** consiste em:
- 1 nó **master** executa os serviços centrais:
   - HDFS NameNode  
   - YARN ResourceManager  
   - Spark Master  
   - Spark History Server  
   - JupyterLab

- `N` nós **workers** (replicados dinamicamente), executam os serviços de dados e processamento:
   - HDFS DataNode  
   - YARN NodeManager  
   - Spark Worker (o número de workers é facilmente configurável).

## 2. Pré-requisitos
Antes de começar, certifique-se de que você tem os seguintes softwares instalados e funcionando em sua máquina:

- Docker Engine: Versão 20.10.0 ou superior.
- Docker Compose: Versão V2 (docker compose) é recomendada.
- Portas Livres: Verifique se as portas padrão (ex: 8088, 9870, 8888, 18080) não estão em uso por outras aplicações.

## 3. 🚀Início Rápido
Siga estes passos para colocar seu cluster no ar em poucos minutos.

**Passo 1: Clonar o Repositório**
Abra seu terminal e clone este repositório para sua máquina local.
```
git clone https://github.com/SampMark/hadoop_spark.git
cd hadoop_spark
```
**Passo 2: Construir e Iniciar o Cluster**
Com o Docker em execução, execute o seguinte comando na raiz do projeto para construir as imagens e iniciar todos os serviços em background:
```
docker compose up -d --build
```
   * `up`: Cria e inicia os contêineres.
   * `-d`: Modo "detached" (os contêineres rodam em background).
   * `--build`: Força a construção da imagem Docker na primeira vez ou se o Dockerfile for alterado.

O primeiro início pode demorar alguns minutos, pois o Docker irá baixar as imagens base e as distribuições do Hadoop e Spark. Após a conclusão, seu cluster estará pronto para uso!

## 4. Customização do Ambiente (arquivo `.env`)
A principal forma de customizar o cluster (número de workers, versões, alocação de memória, etc.) é através do arquivo .env. Isso evita a necessidade de editar manualmente os arquivos XML ou scripts.

Abaixo estão as variáveis mais importantes que você pode ajustar:

|

| Variável | Padrão (.env.example) | Descrição |
| SPARK_WORKER_INSTANCES | 2 | O número de nós workers (DataNodes/NodeManagers) a serem criados no cluster. |
| HADOOP_VERSION | 3.4.0 | A versão do Apache Hadoop a ser baixada e utilizada. |
| SPARK_VERSION | 3.3.4 | A versão do Apache Spark a ser baixada e utilizada. |
| HDFS_REPLICATION_FACTOR | 2 | O fator de replicação padrão do HDFS (dfs.replication). Deve ser ≤ ao número de workers. |
| YARN_NODEMANAGER_MEMORY_MB | 4096 | Memória total (em MB) que cada NodeManager pode alocar para contêineres (yarn.nodemanager.resource.memory-mb). |
| SPARK_DRIVER_MEMORY | 1g | Memória padrão para o Driver do Spark (spark.driver.memory). |
| SPARK_EXECUTOR_MEMORY | 1536m | Memória padrão por Executor do Spark (spark.executor.memory). |
| SPARK_EXECUTOR_CORES | 2 | Número de vCores padrão por Executor do Spark (spark.executor.cores). |
| JUPYTERLAB_PORT | 8888 | Porta local que será mapeada para a interface do JupyterLab. |
| SPARK_HISTORY_UI_PORT | 18080 | Porta local que será mapeada para a UI do Spark History Server. |

**Importante**: caso altere o `.env`, pode ser necessário recriar os contêineres para que as mudanças tenham efeito: 
```
docker compose down && docker compose up -d
```
---

## 5. Acessando os Serviços e UIs Web
Após iniciar o cluster, o usuário pode acessar as interfaces web dos diferentes serviços através do navegador.

| Serviço | Porta (Local) | URL de Acesso | Descrição |
| HDFS NameNode | 9870 | http://localhost:9870 | UI para monitorar o estado do HDFS. |
| YARN ResourceManager | 8088 | http://localhost:8088 | UI para monitorar o cluster, filas e aplicações. |
| Spark History Server | 18080 | http://localhost:18080 | UI para visualizar o histórico de aplicações Spark. |
| JupyterLab | 8888 | http://localhost:8888 | Ambiente interativo para notebooks PySpark. |

## 6. Exemplos práticos de uso
O usuário pode interagir com o cluster executando comandos dentro do contêiner master ou submetendo jobs.

#### 6.1. Interagindo com HDFS
Execute comandos HDFS a partir do contêiner `spark-master`:
```
# Listar o conteúdo do diretório raiz do HDFS
docker compose exec spark-master hdfs dfs -ls /

# Criar um novo diretório
docker compose exec spark-master hdfs dfs -mkdir /meu-diretorio-teste

# Copiar um arquivo local (do README.md) para o HDFS
docker compose exec spark-master hdfs dfs -put README.md /meu-diretorio-teste
```

#### 6.2. Submetendo um Job Spark (SparkPi)
Execute o exemplo `SparkPi` para calcular o valor de Pi. Este job será submetido ao YARN.

```
docker compose exec spark-master spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master yarn \
  --deploy-mode client \
  --num-executors 2 \
  --executor-memory 512m \
  $SPARK_HOME/examples/jars/spark-examples_*.jar 100
```

Após a execução, o usuário verá o job concluído na UI do YARN (http://localhost:8088) e na UI do Spark History Server (http://localhost:18080).

## 7. Gerenciando o Cluster
Use os seguintes comandos `docker compose para gerenciar o ciclo de vida do seu cluster.

* **Iniciar o cluster em background:**
```
docker compose up -d
```

* **Parar e remover os contêineres:**
```
docker compose down
```

* **Verificar o status dos contêineres:**
```
docker compose ps
```

* **Visualizar os logs de um serviço (ex: master):**
```
docker compose logs -f spark-master
```

8. Referências e Documentação Oficial
Para um entendimento mais profundo dos componentes, consulte a documentação oficial:

* [Documentação do Apache Hadoop 3.x](https://hadoop.apache.org/docs/stable/)
* [Documentação do Apache Spark 3.3.x](https://spark.apache.org/docs/3.3.4/)
* [Documentação do Docker](https://docs.docker.com/)
* [Documentação do Docker Compose](https://docs.docker.com/compose/)
* [Repositório GitHub `haddop-spark` Prof. Carlos M. D. Viegas](https://github.com/cmdviegas/hadoop-spark)

## 📂 9. Estrutura de diretórios

```
spark-hadoop/
├── .dockerignore
├── .env
├── .gitattributes
├── .gitignore
├── .password
├── CHANGELOG.md
├── CONTRIBUTING.md
├── docker-compose.template.yml
├── docker-compose.yml      ← gerado por init.sh
├── LICENSE.apache          ← Apache 2.0 (Hadoop)
├── LICENSE.mit             ← MIT (scripts e infra)
├── pgsql
├── README.md
├── config_files/
│   ├── README.md
│   ├── hadoop/
│   │   ├── core-site.xml.template
│   │   ├── hadoop-env.sh.template
│   │   ├── hdfs-site.xml.template
│   │   ├── mapred-site.xml.template
│   │   ├── yarn-env.sh.template
│   │   └── yarn-site.xml.template
│   ├── jupyterlab/
│   │   ├── overrides.json.template
│   │   └── jupyter_notebook_config.py.template
│   ├── spark/
│   │   ├── spark-defaults.conf.template
│   │   └── spark-env.sh.template
│   └── system/
│       ├── README.md
│       ├── bash_common
│       └── ssh_config.template
├── docker/
│   ├── Dockerfile
│   └── entrypoint.sh
├── myfiles/
│   ├── README.md
│   ├── data/
│   ├── notebooks/
│   └── scripts/
├── scripts/
│   ├── download_all.sh
│   ├── init.sh
│   ├── preflight_check.sh
│   ├── bootstrap.sh
│   └── start_services.sh
└── tests/
    ├── smoke_test_hadoop.sh
    └── smoke_test_spark.sh
```

---

## 11. Licenças

- `Apache Spark` e `Apache Hadoop` são software livre e de código aberto, licenciados sob a [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

- Este script é um software livre e de código aberto, licenciado sob [MIT License](https://opensource.org/license/mit).

