### ⚠️🚧👷 EM CONSTRUÇÃO 👷🚧⚠️

---

## Implantação de clusters Spark-Hadoop (_Cluster Deployment_) em ambiente Docker

## Introdução

O **Apache Hadoop** (versão 3.4.1) é um framework de código aberto para armazenamento e processamento distribuído de grandes conjuntos de dados, _Big Data_. A [**documentação oficial**](https://hadoop.apache.org/docs/current/) destaca a contínua evolução do Hadoop, com foco em melhorias de desempenho, novas funcionalidades e maior integração com ecossistemas de nuvem. O Hadoop é composto por três módulos:

1. **Hadoop Distributed File System (HDFS)** é o sistema de arquivos distribuído do Hadoop, projetado para armazenar grandes volumes de dados em clusters de máquinas _commodity_. O HDFS oferece alta tolerância a falhas e alto _throughput_ de dados.
2. **Yet Another Resource Negotiator (YARN)** é o framework de gerenciamento de recursos e agendamento de tarefas do Hadoop, sendo responsável por alocar recursos do sistema para as várias aplicações que rodam no cluster e por agendar as tarefas a serem executadas.
3. **MapReduce** é um modelo de programação e um framework de software para escrever aplicações que processam grandes quantidades de dados em paralelo em grandes clusters.

Por sua vez, o **Apache Spark** (versão 3.5.6) é um motor de análise unificado e de alta performance para processamento de dados em larga escala, de uso geral e acessível. Sua principal vantagem é a capacidade de realizar computação em memória, o que acelera significativamente o processamento em comparação com paradigmas baseados em disco como o **MapReduce**. Além disso, oferece APIs ricas e de alto nível em Java, Scala, Python e R, e um conjunto de ferramentas integradas para diversas tarefas de análise de dados.

O poder do Spark reside em seus componentes bem integrados, que podem ser combinados para criar fluxos de trabalho de análise complexos:
1. **Spark Core e RDDs** é a base de toda a plataforma. 
   * **Resilient Distributed Datasets (RDDs)** é a abstração fundamental do Spark, uma coleção de elementos tolerante a falhas que pode ser operada em paralelo. Embora as APIs de alto nível como DataFrames sejam agora recomendadas, os RDDs ainda são uma parte crucial da base do Spark e oferecem controle de baixo nível quando necessário.
   As transformações em RDDs (e DataFrames) são "preguiçosas" (_lazy evaluation_), o que significa que o Spark não calcula o resultado imediatamente. Em vez disso, ele constrói um grafo de execução (DAG) e só executa os cálculos quando uma ação (como coletar os resultados) é invocada, permitindo otimizações significativas.
2. **Spark SQL** é o módulo do Spark para trabalhar com dados estruturados - 'DataFrames' e 'Datasets', são a principal API para manipulação de dados. O Spark otimiza a execução por meio do [_Catalyst_](https://www.databricks.com/glossary/catalyst-optimizer).
   * **Motor SQL distribuído** permite executar consultas SQL diretamente em DataFrames, podendo ler e escrever dados de uma variedade de fontes de dados estruturados, como JSON, Hive, Parquet e JDBC. 
   * **Adaptive Query Execution (AQE**), é um framework que otimiza dinamicamente as consultas com base nas estatísticas de tempo de execução, ajustando o número de partições de _shuffle_ e otimizando junções (joins).
3. **Structured Streaming** é o motor de processamento de stream tolerante a falhas e escalável do Spark, construído sobre a API do Spark SQL.
4. **MLlib (Machine Learning Library)** é a biblioteca de aprendizado de máquina do Spark, projetada para ser escalável e fácil de usar.


## 1. Visão Geral do Projeto

Bem-vindo ao repositório **Spark-Hadoop**! Este projeto foi cuidadosamente construído para provisionar, de forma simples e rápida, um cluster completo que combina o poder do Apache Spark e do Apache Hadoop, via Docker, um cluster que combina o **Apache Spark** e **Apache Hadoop**, com integração ao **JupyterLab**. 

O objetivo é oferecer um ambiente “_all-in-one_”, isolado e pronto para uso, que abstrai a complexidade da configuração manual.  É a ferramenta interessante para estudantes, desenvolvedores e engenheiros de dados, no desenvolvimento e testes de aplicações em Big Data, tornando simples os procedimentos de:

1. *Implantar clusters funcionais* de Spark e Hadoop em contêineres Docker isolados;
2. *Aprendizado na prática*, acessando _dashboards web_ de todos os serviços (HDFS, YARN, Spark UI, JupyterLab) para entender como as peças se conectam;
3. *Executar jobs de Big Data*, tanto no modelo clássico MapReduce do Hadoop quanto com o processamento em memória de alta performance do Spark.

### **1.1. Arquitetura do Cluster**
O ambiente Docker provisiona um cluster distribuído que combina:

- **Apache Hadoop 3.4.x**, fornece o HDFS (_Hadoop Distributed File System_) para armazenamento de dados massivos e tolerante a falhas, e o YARN (_Yet Another Resource Negotiator_) para um gerenciamento robusto dos recursos computacionais (CPU e memória) do(s) cluster(s).
- **Apache Spark 4.0.x**, atua como o motor de processamento de dados em larga escala, executando tarefas sobre o YARN e lendo/escrevendo dados no HDFS.
- **JupyterLab**, oferece um ambiente de notebook interativo, pré-configurado com um kernel `PySpark`, permitindo a análise de dados e o desenvolvimento de forma ágil e visual.

A **arquitetura padrão** é composta por:
- 1 **Nó Mestre** (`master`), orquestra o cluster, executando os serviços de gerenciamento:
   - **HDFS NameNode**, é "cérebro" do HDFS, gerencia os metadados do sistema de arquivos.
   - **YARN ResourceManager**, é o "chefe" do YARN, aloca recursos para as aplicações.
   - **Spark History Server**, é uma UI web para visualizar o histórico de aplicações Spark concluídas.
   - **JupyterLab**, servidor que fornece a interface de notebooks.

- `N` **Nós de Trabalho** (`workers`), são os "operários" do cluster que podem ser replicados dinamicamente, executando as tarefas de armazenamento e processamento:
   - **HDFS DataNode**, armazena os blocos de dados reais.  
   - **YARN NodeManager**, gerencia os recursos de uma máquina individual e executa as tarefas.
   - "Spark Worker", o número de `workers` é facilmente configurável em arquivo `.env`.

---

## 2. Pré-requisitos
Antes de começar, certifique-se dos seguintes requisitos, softwares instalados e funcionando em sua máquina:

- **Sistema Operacional**, preferencialmente, uma distribuição Linux (como Ubuntu ou CentOS).
- **Java Development Kit (JDK)**, o Hadoop e o Spark rodam na JVM. É crucial instalar uma versão compatível (ex: JDK 11 para Hadoop 3.x). A variável de ambiente `JAVA_HOME` deve ser configurada e apontar para o diretório de instalação do Java.
- **SSH (Secure Shell)**, essencial para que o nó mestre possa se comunicar e gerenciar os nós de trabalho sem a necessidade de senhas a cada comando. Isso é feito gerando um par de chaves SSH (`ssh-keygen`) e copiando a chave pública para o arquivo `authorized_keys` em todos os nós (inclusive no próprio mestre).
- **Docker Engine** na versão 20.10.0 ou superior.
- **Docker Compose** na versão V2 (`docker compose`), é fortemente recomendada.
- **Recursos mínimos** de pelo menos 8 GB de RAM alocados para o Docker, para uma experiência fluida com 2 workers.
- **Portas Livres**, verifique se as portas padrão (ex: 8088, 9870, 8888, 18080) não estão em uso por outras aplicações.

---

## 3. ✨Início Rápido
Siga estes passos para provisionar seu cluster Spark–Hadoop no ar em poucos minutos.

**3.1. Clonar o repositório Spark-Hadoop**
Abra seu terminal e clone este repositório para sua máquina local.
```
git clone https://github.com/SampMark/Spark-Hadoop.git
cd Spark-Hadoop
```
**3.2. Configurar variáveis de ambiente**
Crie seu arquivo `.env` a partir do template, caso necessário, ajuste as versões e número de workers:

```
cp .env.template .env
# Edite .env conforme sua necessidade (HADOOP_VERSION, SPARK_VERSION, SPARK_WORKER_INSTANCES, DOWNLOAD_HADOOP_SPARK, etc.)
```

**3.3. Gerar o `docker-compose.yml` e baixar binários**

Utilize o script de inicialização para processar o template e (opcionalmente) baixar os _tarballs_ do Hadoop e Spark:

```
docker compose -f compose-init.yml run --rm init
```
Obsercação: verifique as mensagens de log para garantir que docker-compose.yml foi gerado e que os arquivos foram baixados com sucesso.


**3.4. Construir as imagens Docker**
Com o Docker em execução, execute o seguinte comando na raiz do projeto para construir as imagens e iniciar todos os serviços em _background_:
```
docker compose up
```
**3.5. Subir o cluster**
Para iniciar todos os serviços em background:
```
docker compose up -d
```
   * `up`: Cria e inicia os contêineres.
   * `-d`: Modo "detached" (os contêineres rodam em background).

Para acompanhar logs em tempo real (ex.: master):
```
docker compose logs -f spark-master
```
O primeiro início pode demorar alguns minutos, pois o Docker irá baixar as imagens base e as distribuições do Hadoop e Spark. 
Após a conclusão, seu cluster estará pronto para uso!

**3.6. Recriar o cluster após alterações**
Caso modifique o `.env` ou os templates, pare e remova os contêineres antes de subir novamente:
```
docker compose down
docker compose up -d --build
```

**3.7. Acessar as UIs Web**

* HDFS NameNode: http://localhost:${HDFS_UI_PORT:-9870}
* YARN ResourceManager: http://localhost:${YARN_UI_PORT:-8088}
* Spark History Server: http://localhost:${SPARK_HISTORY_UI_PORT:-18080}
* JupyterLab: http://localhost:${JUPYTER_PORT:-8888}

---

## 4. Customização do Ambiente (arquivo `.env`)
A principal forma de customizar o cluster (número de workers, versões, alocação de memória, etc.) é através do arquivo .env. Isso evita a necessidade de editar manualmente os arquivos XML ou scripts.

Abaixo estão as variáveis mais importantes que você pode ajustar:

| Variável                      | Padrão (.env)   | Descrição                                                                 |
| :---------------------------- | :-------------: | :------------------------------------------------------------------------ |
| `SPARK_WORKER_INSTANCES`      | `2`             | Número de nós workers (DataNodes/NodeManagers) a serem criados no cluster |
| `HADOOP_VERSION`              | `3.4.0`         | Versão do Apache Hadoop a ser utilizada                                   |
| `SPARK_VERSION`               | `3.3.4`         | Versão do Apache Spark a ser utilizada                                    |
| `HDFS_REPLICATION_FACTOR`     | `2`             | Fator de replicação padrão do HDFS (`dfs.replication`). Deve ser ≤ número de workers |
| `YARN_NODEMANAGER_MEMORY_MB`  | `4096`          | Memória total (MB) que cada NodeManager pode alocar para contêineres (`yarn.nodemanager.resource.memory-mb`) |
| `SPARK_DRIVER_MEMORY`         | `1g`            | Memória padrão para o Driver do Spark (`spark.driver.memory`)             |
| `SPARK_EXECUTOR_MEMORY`       | `1536m`         | Memória padrão por Executor do Spark (`spark.executor.memory`)            |
| `SPARK_EXECUTOR_CORES`        | `2`             | Número de vCores por Executor do Spark (`spark.executor.cores`)           |
| `JUPYTERLAB_PORT`             | `8888`          | Porta local mapeada para a interface do JupyterLab                        |
| `SPARK_HISTORY_UI_PORT`       | `18080`         | Porta local mapeada para a UI do Spark History Server                     |

**Importante**: caso altere o `.env`, pode ser necessário recriar os contêineres para que as mudanças tenham efeito: 
```
docker compose down && docker compose up -d
```
---

## 5. Acessando os Serviços e UIs Web
Após iniciar o cluster, o usuário pode acessar as interfaces web dos diferentes serviços através do navegador.

| Serviço              | Porta (Local) | URL de Acesso          | Descrição |
| :------------------- | :-----------: | :--------------------: |-------------------------------------------------- |
| HDFS NameNode        | 9870          | http://localhost:9870  | UI para monitorar o estado do HDFS.               |
| YARN ResourceManager | 8088          | http://localhost:8088  | UI para monitorar o cluster, filas e aplicações.  |
| Spark History Server | 18080         | http://localhost:18080 | UI para visualizar o histórico de aplicações Spark. |
| JupyterLab           | 8888          | http://localhost:8888  | Ambiente interativo para notebooks PySpark.       |

---

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

---

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
---

## 8. 🔗Referências e Documentação Oficial
Para um entendimento mais profundo dos componentes, consulte a documentação oficial:

* ZAHARIA, Matei _et al_. **Resilient Distributed Datasets: A Fault-Tolerant Abstraction for In-Memory Cluster Computing**. In: USENIX Symposium on Networked Systems Design and Implementation (NSDI), 9., 2012, San Jose, CA. Anais. Berkeley: USENIX Association, 2012. p. 1-14. Disponível em: [https://www.usenix.org/system/files/conference/nsdi12/nsdi12-final138.pdf](https://www.usenix.org/system/files/conference/nsdi12/nsdi12-final138.pdf) Acesso em: 01 Jun. 2025.

* MCDONALD, Carol. **Introduction to Spark Processing**. In: MCDONALD, Carol. ACCELERATING APACHE SPARK 3: Leveraging NVIDIA GPUs to Power the Next Era of Analytics and Al. [S.l.]: NVIDIA, 2021. cap. 1, p. 12-30. Disponível em: [https://images.nvidia.com/aem-dam/Solutions/deep-learning/deep-learning-ai/solutions/Accelerating-Apache-Spark-3-08262021.pdf](https://images.nvidia.com/aem-dam/Solutions/deep-learning/deep-learning-ai/solutions/Accelerating-Apache-Spark-3-08262021.pdf) Acesso em: 03 Jun. 2025.

* [Documentação do Apache Hadoop 3.x](https://hadoop.apache.org/docs/stable/)
* [Documentação do Apache Spark 3.3.x](https://spark.apache.org/docs/3.3.4/)
* [Documentação do Docker](https://docs.docker.com/)
* [Documentação do Docker Compose](https://docs.docker.com/compose/)
* [Repositório GitHub `haddop-spark` Prof. Carlos M. D. Viegas](https://github.com/cmdviegas/hadoop-spark)

---

## 📂 9. Estrutura de diretórios e arquivos

```
spark-hadoop/
├── .dockerignore
├── .env                            ← Arquivo principal para customização do cluster.
├── .env.template
├── .gitattributes
├── .gitignore
├── .password
├── CHANGELOG.md
├── CONTRIBUTING.md
├── docker-compose.template.yml     ← Define os serviços (master, workers) e redes do Docker.
├── docker-compose.yml              ← gerado por init.sh
├── LICENSE.apache                  ← Apache 2.0 (Hadoop)
├── LICENSE.mit                     ← MIT (scripts e infra)
├── pgsql
├── README.md
├── requirements.txt
├── config_files/                   ← Contém os TEMPLATES de configuração.
│   ├── README.md
│   ├── hadoop/                     ← Templates para .xml.
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
│   ├── data/                    ← Coloque seus datasets aqui.
│   ├── notebooks/               ← Crie seus notebooks Jupyter aqui.
│   └── scripts/                 ← Guarde seus scripts Python/Scala aqui.
├── scripts/
│   ├── download_all.sh
│   ├── init.sh
│   ├── preflight_check.sh
│   ├── bootstrap.sh             ← Script interno que cuida da formatação do HDFS e da inicialização dos serviços.
│   └── start_services.sh
└── tests/
    ├── smoke_test_hadoop.sh
    └── smoke_test_spark.sh
```
---

## 10. Licenças

- `Apache Spark` e `Apache Hadoop` são software livre e de código aberto, licenciados sob a [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

- Este script é um software livre e de código aberto, licenciado sob [MIT License](https://opensource.org/license/mit).

