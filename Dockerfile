# =============================================================================
# Dockerfile para Cluster Hadoop e Spark
#
# Autor: Marcus V D Sampaio/Organização: IFRN - Baseado no script de Carlos M D Viegas
# Versão: 1.1
# Data: 2024-05-07
#
# Descrição:
#   Este Dockerfile cria uma imagem Docker contendo um ambiente completo com
#   Apache Hadoop e Apache Spark, baseado em Ubuntu 24.04. A imagem é projetada
#   para ser flexível e configurável em tempo de execução.
#
# Como Funciona (Fluxo de Trabalho):
#   1. Pré-requisito: O usuário executa um script inicial (ex: `init.sh` via
#      `docker compose run --rm init`) que baixa os arquivos .tar.gz do Hadoop
#      e Spark para o contexto de build do Docker.
#   2. Build Multi-Stage:
#      - Estágios 'build-hadoop' e 'build-spark': Estes estágios copiam os
#        arquivos .tar.gz pré-baixados e os extraem. Isso isola a preparação
#        dos binários.
#      - Estágio 'final': Este é o estágio principal que constrói a imagem final.
#        - Instala todas as dependências do sistema (Java, Python, SSH, etc.).
#        - Instala as bibliotecas Python necessárias.
#        - Cria um usuário não-privilegiado ('myuser') para executar os serviços.
#        - Copia os binários extraídos de Hadoop e Spark dos estágios anteriores.
#        - Copia todos os scripts (.sh), templates de configuração (.template)
#          e outros arquivos necessários para dentro da imagem.
#        - Realiza a configuração final do ambiente do usuário (ex: chaves SSH).
#   3. Entrypoint: O ponto de entrada da imagem é definido como o script `entrypoint.sh`.
#      Este script é executado quando um contêiner é iniciado, e é responsável por:
#      - Gerar os arquivos de configuração finais a partir dos templates.
#      - Definir permissões.
#      - Entregar a execução para o script principal (bootstrap.sh).
#
# =============================================================================


# =============================================================================
# ESTÁGIO 1: Preparação do Hadoop
# Este estágio espera que o arquivo hadoop-*.tar.gz, caso já tenha sido baixado
# para o contexto de build pelo script `init.sh`.
# =============================================================================
FROM ubuntu:24.04 AS build-hadoop

# Usar bash com pipefail para capturar erros em pipelines
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Argumento de build para a versão do Hadoop, passado via docker-compose
ARG HADOOP_VERSION

# Variáveis de ambiente para o estágio
ENV MY_USERNAME=myuser
ENV MY_WORKDIR=/home/${MY_USERNAME}
ENV HADOOP_VERSION=${HADOOP_VERSION}
ENV HADOOP_HOME=${MY_WORKDIR}/hadoop

WORKDIR ${MY_WORKDIR}

# Copia o tarball do Hadoop para o diretório de trabalho do estágio
COPY hadoop-*.tar.gz ${MY_WORKDIR}/

# Valida a existência do arquivo e o extrai
RUN \
    # Verifica se o tarball do Hadoop existe
    if [ ! -f "${MY_WORKDIR}/hadoop-${HADOOP_VERSION}.tar.gz" ]; then \
        echo "🚨 ERRO DE BUILD 🚨: Arquivo hadoop-${HADOOP_VERSION}.tar.gz não encontrado." && \
        echo "⚠️ Execute 'docker compose run --rm init' primeiro para baixar as dependências. ⚠️" && \
        exit 1; \
    fi && \
    # Extrai o Hadoop para o sistema de arquivos do contêiner
    tar -zxf "hadoop-${HADOOP_VERSION}.tar.gz" -C ${MY_WORKDIR} && \
    # Remove o tarball para economizar espaço
    rm -f "hadoop-${HADOOP_VERSION}.tar.gz" && \
    # Renomeia o diretório extraído para um nome genérico 'hadoop' para facilitar o acesso
    mv "${MY_WORKDIR}/hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}"


# =============================================================================
# ESTÁGIO 2: Preparação do Spark
# Similar ao estágio do Hadoop, espera um tarball do Spark pré-baixado.
# =============================================================================
FROM ubuntu:24.04 AS build-spark

# Usar bash com pipefail
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Argumento de build para a versão do Spark
ARG SPARK_VERSION

# Variáveis de ambiente para o estágio
ENV MY_USERNAME=myuser
ENV MY_WORKDIR=/home/${MY_USERNAME}
ENV SPARK_VERSION=${SPARK_VERSION}
ENV SPARK_HOME=${MY_WORKDIR}/spark

WORKDIR ${MY_WORKDIR}

# Copia o tarball do Spark
COPY spark-*.tgz ${MY_WORKDIR}/

# Valida a existência do arquivo e o extrai
RUN \
    # Verifica se o tarball do Spark existe
    if [ ! -f "${MY_WORKDIR}/spark-${SPARK_VERSION}-bin-hadoop3.tgz" ]; then \
        echo "🚨 ERRO DE BUILD 🚨: Arquivo spark-${SPARK_VERSION}-bin-hadoop3.tgz não encontrado." && \
        echo "⚠️ Execute 'docker compose run --rm init' primeiro para baixar as dependências. ⚠️" && \
        exit 1; \
    fi && \
    # Extrai o Spark
    tar -zxf "spark-${SPARK_VERSION}-bin-hadoop3.tgz" -C ${MY_WORKDIR} && \
    # Remove o tarball
    rm -f "spark-${SPARK_VERSION}-bin-hadoop3.tgz" && \
    # Renomeia o diretório extraído para 'spark'
    mv "${MY_WORKDIR}/spark-${SPARK_VERSION}-bin-hadoop3" "${SPARK_HOME}"


# =============================================================================
# ESTÁGIO 3: Imagem Final
# Constrói a imagem final combinando os resultados dos estágios anteriores
# com as dependências do sistema e configurações.
# =============================================================================
FROM ubuntu:24.04 AS final

LABEL maintainer="Marcus V D Sampaio <prof.marcus.sampaio@gmail.com>"
LABEL description="Imagem Docker com Apache Hadoop, Apache Spark e JupyterLab para clusters de Big Data."

# Usar bash com pipefail
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Argumentos de build passados pelo docker-compose
ARG HADOOP_VERSION
ARG SPARK_VERSION
ARG APT_MIRROR

# --- Variáveis de Ambiente Globais ---
# Definidas para serem usadas pelos scripts e aplicações dentro do contêiner.
ENV MY_USERNAME=myuser
ENV MY_GROUP=myuser
ENV MY_WORKDIR=/home/${MY_USERNAME}
ENV HADOOP_VERSION=${HADOOP_VERSION}
ENV SPARK_VERSION=${SPARK_VERSION}
ENV HADOOP_HOME=${MY_WORKDIR}/hadoop
ENV SPARK_HOME=${MY_WORKDIR}/spark
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
ENV SPARK_CONF_DIR=${SPARK_HOME}/conf
ENV PATH=${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV DEBIAN_FRONTEND=noninteractive
ENV APT_MIRROR="${APT_MIRROR:-http://archive.ubuntu.com/ubuntu}"

# --- Instalação de Dependências do Sistema ---
RUN \
    # Opcional: Altera o espelho do APT se um for fornecido, pode acelerar o build em algumas regiões
    sed -i "s|http://archive.ubuntu.com/ubuntu|${APT_MIRROR}|g" /etc/apt/sources.list.d/ubuntu.sources && \
    # Atualiza a lista de pacotes e instala as dependências em uma única camada para otimizar o tamanho
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        # Essenciais para Hadoop/Spark
        openjdk-11-jdk-headless \
        ssh \
        sudo \
        # Essenciais para Python/Jupyter
        python3.12 \
        python3-pip \
        # Utilitários gerais
        nano \
        dos2unix \
        wget \
        curl \
        iputils-ping \
        gosu \
    && \
    # --- Limpeza do Cache do APT ---
    # Remove caches e listas para reduzir o tamanho final da imagem
    apt-get autoremove -yqq --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # --- Criação de Links Simbólicos para Python ---
    # Garante que `python` e `python3` apontem para a versão instalada
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/python3.12 /usr/bin/python3

# --- Instalação de Dependências Python ---
# Copia o arquivo de requisitos primeiro para aproveitar o cache do Docker.
# O build só re-executará este passo se o requirements.txt mudar.
COPY requirements.txt /tmp/requirements.txt
RUN \
    pip install --no-cache-dir --break-system-packages -q -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# --- Criação do Usuário e Grupos ---
RUN \
    # Remove o usuário padrão 'ubuntu', se existir
    userdel --remove ubuntu || true && \
    # Cria o grupo e o usuário da aplicação ('myuser' por padrão)
    groupadd --gid 1000 ${MY_GROUP} || true && \
    useradd --uid 1000 --gid ${MY_GROUP} --shell /bin/bash --create-home ${MY_USERNAME} && \
    # Adiciona o usuário ao grupo sudo e concede permissões sudo sem senha
    usermod -aG sudo ${MY_USERNAME} && \
    echo "${MY_USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${MY_USERNAME}

# Define o diretório de trabalho padrão
WORKDIR ${MY_WORKDIR}

# --- Cópia dos Binários e Arquivos da Aplicação ---
# Copia os binários do Hadoop e Spark dos estágios de build anteriores
COPY --from=build-hadoop --chown=${MY_USERNAME}:${MY_GROUP} ${HADOOP_HOME} ${HADOOP_HOME}/
COPY --from=build-spark --chown=${MY_USERNAME}:${MY_GROUP} ${SPARK_HOME} ${SPARK_HOME}/

# Copia todos os scripts, templates de configuração e outros arquivos necessários.
# O .dockerignore deve ser usado para excluir arquivos desnecessários (ex: .git, README.md).
# O `chown` garante que o usuário da aplicação seja o proprietário dos arquivos.
COPY --chown=${MY_USERNAME}:${MY_GROUP} . ${MY_WORKDIR}/

# --- Configuração Final do Ambiente do Usuário ---
# Muda para o usuário não-privilegiado para executar comandos que não requerem root
USER ${MY_USERNAME}
RUN \
    # Converte scripts de DOS para UNIX para evitar problemas de formato de linha
    dos2unix -q -k ${MY_WORKDIR}/scripts/*.sh ${MY_WORKDIR}/docker/entrypoint.sh && \
    # Adiciona a fonte do .bash_common ao .bashrc para carregar variáveis de ambiente e aliases
    echo -e '\n# Carrega configurações comuns do cluster\n[ -f "${HOME}/.bash_common" ] && . "${HOME}/.bash_common"\n' >> "${MY_WORKDIR}/.bashrc" && \
    # Configura SSH para acesso sem senha (necessário para os scripts de gerenciamento do Hadoop)
    ssh-keygen -q -t rsa -N "" -f ${MY_WORKDIR}/.ssh/id_rsa && \
    cat ${MY_WORKDIR}/.ssh/id_rsa.pub >> ${MY_WORKDIR}/.ssh/authorized_keys && \
    # Define permissões restritas para os arquivos SSH
    chmod 0600 ${MY_WORKDIR}/.ssh/authorized_keys ${MY_WORKDIR}/.ssh/config && \
    # Define permissões de execução para os scripts principais
    chmod +x ${MY_WORKDIR}/scripts/*.sh ${MY_WORKDIR}/docker/entrypoint.sh && \
    # Cria o diretório de log para o Derby (metastore do Spark SQL)
    mkdir -p ${MY_WORKDIR}/derby-metastore

# --- Definição do Entrypoint e Comando Padrão ---
# Volta para o usuário root temporariamente para definir o diretório de trabalho global
USER root
WORKDIR /

# O Entrypoint é o script que prepara o ambiente em tempo de execução
ENTRYPOINT ["/home/myuser/docker/entrypoint.sh"]

# O Comando padrão passado para o Entrypoint.
# Quando um contêiner master é iniciado, ele executará `entrypoint.sh bootstrap.sh MASTER`.
# Quando um contêiner worker é iniciado, ele executará `entrypoint.sh bootstrap.sh WORKER`.
CMD ["bash", "/home/myuser/scripts/bootstrap.sh", "MASTER"]
