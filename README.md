# Spark e Hadoop Cluster Deployment

## 1. Visão Geral

O repositório **Spark-Hadoop** é projetado para provisionar, via Docker e Docker Compose, um cluster que combina o **Apache Spark** e **Apache Hadoop** e integração com **JupyterLab**. Em suma, o repositório fornece um ambiente **Docker** para um **cluster distribuído** que combina:

- **Apache Hadoop 3.4.x** (HDFS + YARN);
- **Apache Spark 3.3.x** (Spark Master, Spark Workers, Spark History Server);
- **JupyterLab** para notebooks interativos com kernels PySpark.

Você terá, por padrão:
1. O nó **master** que executa os seguintes serviços:
   - HDFS NameNode  
   - YARN ResourceManager  
   - Spark Master  
   - Spark History Server  
   - JupyterLab (se habilitado)

2. N nós **worker** (replicados dinamicamente), executam:
   - HDFS DataNode  
   - YARN NodeManager  
   - Spark Worker  

O objetivo é oferecer um ambiente “tudo-em-um” para pesquisas e testes de Big Data, tornando simples:

1. Implantar um cluster Hadoop + Spark em containers isolados;
2. Acessar dashboards web (HDFS, YARN, Spark UI, JupyterLab) via mapeamento de portas;
3. Rodar jobs MapReduce e Spark (inclusive com notebooks interativos).

---

## 📂 Estrutura de Diretórios

spark-hadoop/
├── scripts/ ← Scripts de automação (download, init, etc.)
├── config_files/ ← Templates de configuração para Hadoop, Spark, Jupyter, SSH
├── myfiles/ ← Espaço do usuário (data/, notebooks/, scripts/)
├── docker/ ← Dockerfile e entrypoint
├── tests/ ← Smoke tests para Hadoop e Spark
├── .env.example ← Exemplo de variáveis de ambiente
├── docker-compose.yml ← Gerado pelo init.sh
├── docker-compose.template.yml
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
└── LICENSE.apache


---

## 🚀 Quick Start

1. **Clone e entre na pasta**  
   ```bash
   git clone https://github.com/SampMark/hadoop_spark.git
   cd hadoop_spark


## :page_facing_up: License

`Apache Spark` e `Apache Hadoop` são software livre e de código aberto, licenciados sob a [Apache License](https://github.com/cmdviegas/docker-hadoop-cluster/blob/master/LICENSE.apache) and are also free, open-source software.


Este script é um software livre e de código aberto, licenciado sob [MIT License](https://github.com/cmdviegas/docker-hadoop-cluster/blob/master/LICENSE).

