# =============================================================================
# Dockerfile para Cluster Hadoop e Spark (VERSÃO REVISADA)
#
# Autor: Marcus V D Sampaio/Organização: IFRN - Baseado no script de Carlos M D Viegas
# Versão: 1.2 (Revisado com base nas melhores práticas)
# Data: 2025-06-11
#
# Descrição:
#   Este Dockerfile cria uma imagem Docker contendo um ambiente completo com
#   Apache Hadoop e Apache Spark, baseado em Ubuntu 24.04. A imagem é projetada
#   para ser flexível e configurável em tempo de execução.
#
# Como Funciona (Fluxo de Trabalho Revisado):
#   1. Pré-requisito: O usuário executa um script 'init.sh' que baixa os
#      arquivos .tar.gz do Hadoop e Spark, e seus respectivos arquivos .sha512,
#      para o contexto de build.
#   2. Build Multi-Stage:
#      - Estágios 'build-hadoop' e 'build-spark': Copiam os arquivos .tar.gz e
#        .sha512. VALIDAM a integridade dos arquivos e os extraem.
#        O build FALHARÁ se os arquivos não existirem ou se o checksum for inválido.
#      - Estágio 'final': Constrói a imagem final combinando os binários preparados
#        com as dependências do sistema e configurações.
# =============================================================================

# =============================================================================
# ESTÁGIO 1: Preparação e Validação do Hadoop
# =============================================================================
FROM ubuntu:24.04 AS build-hadoop

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Argumento de build para a versão do Hadoop
ARG HADOOP_VERSION=3.4.1

# Variáveis de ambiente para o estágio
ENV MY_USERNAME=myuser
ENV MY_WORKDIR=/home/${MY_USERNAME}
ENV HADOOP_VERSION=${HADOOP_VERSION}
ENV HADOOP_HOME=${MY_WORKDIR}/hadoop
ENV HADOOP_TARBALL="hadoop-${HADOOP_VERSION}.tar.gz"

WORKDIR ${MY_WORKDIR}

# Copia o tarball e o checksum do contexto de build.
# O Dockerfile agora DEPENDE que esses arquivos tenham sido pré-baixados.
COPY hadoop-*.tar.gz hadoop-*.tar.gz.sha512 ./

# Valida, verifica o checksum e extrai. Remove a lógica de 'wget'.
RUN \
    # 1. Verifica se os arquivos necessários existem
    if [ ! -f "${HADOOP_TARBALL}" ] || [ ! -f "${HADOOP_TARBALL}.sha512" ]; then \
      echo "🚨 ERRO DE BUILD 🚨: Arquivo ${HADOOP_TARBALL} e/ou seu checksum .sha512 não encontrado." && \
      echo "⚠️ Execute o script de inicialização para baixar as dependências primeiro. ⚠️" && \
      exit 1; \
    fi && \
    # 2. Valida a integridade do arquivo usando o checksum
    echo "Verificando checksum do Hadoop..." && \
    sha512sum -c "${HADOOP_TARBALL}.sha512" && \
    # 3. Extrai o Hadoop
    echo "Extraindo Hadoop..." && \
    tar -zxf "${HADOOP_TARBALL}" -C ${MY_WORKDIR} && \
    # 4. Limpeza
    rm -f "${HADOOP_TARBALL}" "${HADOOP_TARBALL}.sha512" && \
    # 5. Renomeia para um nome genérico
    mv "${MY_WORKDIR}/hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}"

# =============================================================================
# ESTÁGIO 2: Preparação e Validação do Spark
# =============================================================================
FROM ubuntu:24.04 AS build-spark

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Argumentos de build para a versão do Spark
ARG SPARK_VERSION=3.5.6
ARG SPARK_PROFILE=hadoop3

# Variáveis de ambiente para o estágio
ENV MY_USERNAME=myuser
ENV MY_WORKDIR=/home/${MY_USERNAME}
ENV SPARK_VERSION=${SPARK_VERSION}
ENV SPARK_HOME=${MY_WORKDIR}/spark
ENV SPARK_TARBALL="spark-${SPARK_VERSION}-bin-${SPARK_PROFILE}.tgz"

WORKDIR ${MY_WORKDIR}

# Copia o tarball e o checksum do contexto.
COPY spark-*.tgz spark-*.tgz.sha512 ./

# Valida, verifica o checksum e extrai.
RUN \
    # 1. Verifica se os arquivos necessários existem
    if [ ! -f "${SPARK_TARBALL}" ] || [ ! -f "${SPARK_TARBALL}.sha512" ]; then \
      echo "🚨 ERRO DE BUILD 🚨: Arquivo ${SPARK_TARBALL} e/ou seu checksum .sha512 não encontrado." && \
      echo "⚠️ Execute o script de inicialização para baixar as dependências primeiro. ⚠️" && \
      exit 1; \
    fi && \
    # 2. Valida a integridade do arquivo
    echo "Verificando checksum do Spark..." && \
    sha512sum -c "${SPARK_TARBALL}.sha512" && \
    # 3. Extrai o Spark
    echo "Extraindo Spark..." && \
    tar -zxf "${SPARK_TARBALL}" -C ${MY_WORKDIR} && \
    # 4. Limpeza
    rm -f "${SPARK_TARBALL}" "${SPARK_TARBALL}.sha512" && \
    # 5. Renomeia para um nome genérico
    mv "${MY_WORKDIR}/spark-${SPARK_VERSION}-bin-${SPARK_PROFILE}" "${SPARK_HOME}"

# =============================================================================
# ESTÁGIO 3: Imagem Final
# =============================================================================
FROM ubuntu:24.04 AS final

LABEL maintainer="Marcus V D Sampaio <prof.marcus.sampaio@gmail.com>"
LABEL description="Imagem Docker com Apache Hadoop, Apache Spark e JupyterLab para clusters de Big Data."

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG HADOOP_VERSION
ARG SPARK_VERSION
ARG APT_MIRROR

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

RUN \
    # <<< CORREÇÃO >>>: Lógica de APT_MIRROR mantida, mas ciente das limitações com o novo formato de sources.
    if [ -n "$APT_MIRROR" ]; then \
      sed -i "s|http://archive.ubuntu.com/ubuntu|${APT_MIRROR}|g" /etc/apt/sources.list.d/ubuntu.sources; \
    fi && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      openjdk-11-jdk-headless \
      ssh \
      sudo \
      python3.12 \
      python3-pip \
      nano \
      dos2unix \
      wget \
      curl \
      iputils-ping \
      gosu \
    && \
    apt-get autoremove -yqq --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/python3.12 /usr/bin/python3

# Instala dependências necessárias para o projeto
COPY ./requirements.txt /tmp/requirements.txt

RUN \
    pip install --no-cache-dir --break-system-packages -q -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

RUN \
    userdel --remove ubuntu || true && \
    groupadd --gid 1000 ${MY_GROUP} || true && \
    useradd --uid 1000 --gid ${MY_GROUP} --shell /bin/bash --create-home ${MY_USERNAME} && \
    usermod -aG sudo ${MY_USERNAME} && \
    echo "${MY_USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${MY_USERNAME}

WORKDIR ${MY_WORKDIR}

# Consolida as instruções COPY para reduzir camadas.
# Copia binários preparados e depois todos os arquivos da aplicação.
COPY --from=build-hadoop --chown=${MY_USERNAME}:${MY_GROUP} ${HADOOP_HOME} ${HADOOP_HOME}/
COPY --from=build-spark --chown=${MY_USERNAME}:${MY_GROUP} ${SPARK_HOME} ${SPARK_HOME}/
COPY --chown=${MY_USERNAME}:${MY_GROUP} . ${MY_WORKDIR}/

USER ${MY_USERNAME}
RUN \
    dos2unix -q -k ${MY_WORKDIR}/scripts/*.sh ${MY_WORKDIR}/docker/entrypoint.sh && \
    echo -e '\n# Carrega configurações comuns do cluster\n[ -f "${HOME}/.bash_common" ] && . "${HOME}/.bash_common"\n' >> "${MY_WORKDIR}/.bashrc" && \
    ssh-keygen -q -t rsa -N "" -f ${MY_WORKDIR}/.ssh/id_rsa && \
    cat ${MY_WORKDIR}/.ssh/id_rsa.pub >> ${MY_WORKDIR}/.ssh/authorized_keys && \
    # Adicionado .ssh/config à configuração de permissões
    chmod 0700 ${MY_WORKDIR}/.ssh && \
    chmod 0600 ${MY_WORKDIR}/.ssh/authorized_keys ${MY_WORKDIR}/.ssh/id_rsa && \
    chmod 0644 ${MY_WORKDIR}/.ssh/id_rsa.pub && \
    # Cria diretório de log para o metastore do Spark SQL.
    mkdir -p ${MY_WORKDIR}/derby-metastore

# Configura o entrypoint e o comando padrão
ENTRYPOINT ["/home/myuser/docker/entrypoint.sh"]
CMD ["bash", "/home/myuser/scripts/bootstrap.sh", "MASTER"]