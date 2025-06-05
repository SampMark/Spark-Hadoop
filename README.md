# Spark e Hadoop Cluster Deployment

## 1. Visão Geral

O repositório **Spark-Hadoop** é projetado para provisionar, via Docker e Docker Compose, um cluster que combina o **Apache Spark** e **Apache Hadoop** e integração com **JupyterLab**. Em suma, o repositório fornece um ambiente **Docker** para um **cluster distribuído** que combina:

- **Apache Hadoop 3.4.x** (HDFS + YARN);
- **Apache Spark 3.3.x** (Spark Master, Spark Workers, Spark History Server);
- **JupyterLab** para notebooks interativos com kernels PySpark.

Você terá, por padrão:
1. O nó **master** executa os seguintes serviços:
   - HDFS NameNode  
   - YARN ResourceManager  
   - Spark Master  
   - Spark History Server  
   - JupyterLab (se habilitado)

2. Os nós **workers** (replicados dinamicamente), executam:
   - HDFS DataNode  
   - YARN NodeManager  
   - Spark Worker  

O objetivo é oferecer um ambiente “_all-in-one_” para pesquisas e testes de Big Data, tornando simples os procedimentos de:

1. Implantar clusters Spark + Hadoop em _containers_ isolados;
2. Acessar a dashboards web (HDFS, YARN, Spark UI, JupyterLab) via mapeamento de portas;
3. Rodar jobs MapReduce e Spark, inclusive com notebooks interativos.

---

## 📂 Estrutura de diretórios

´´´
spark-hadoop/
├── .dockerignore
├── .env
├── .env.example
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
´´´
---

## 🚀 Quick Start

1. **Clone e entre na pasta**  
   ```bash
   git clone https://github.com/SampMark/hadoop_spark.git
   cd hadoop_spark


## :page_facing_up: License

`Apache Spark` e `Apache Hadoop` são software livre e de código aberto, licenciados sob a [Apache License](https://github.com/cmdviegas/docker-hadoop-cluster/blob/master/LICENSE.apache) and are also free, open-source software.


Este script é um software livre e de código aberto, licenciado sob [MIT License](https://github.com/cmdviegas/docker-hadoop-cluster/blob/master/LICENSE).

