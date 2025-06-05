# -----------------------------------------------------------------------------
# Imagem base: Ubuntu 22.04
# -----------------------------------------------------------------------------
ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

ARG MY_USERNAME
ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# 1) Instala pacotes de sistema: SSH, Java, Python, utilitários
# -----------------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    openjdk-${JAVA_VERSION}-jdk-headless \
    python3 python3-pip \
    openssh-server \
    wget curl gnupg2 \
    procps \
    lsb-release \
 && pip3 install --no-cache-dir jupyterlab \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2) Cria usuário não-root
# -----------------------------------------------------------------------------
RUN useradd -m -s /bin/bash ${MY_USERNAME}

# -----------------------------------------------------------------------------
# 3) Configuração de SSH
# -----------------------------------------------------------------------------
RUN mkdir -p /var/run/sshd \
 && echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config \
 && echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

# -----------------------------------------------------------------------------
# 4) Diretórios de Hadoop e Spark
# -----------------------------------------------------------------------------
ARG HADOOP_HOME=/usr/local/hadoop
ARG SPARK_HOME=/usr/local/spark
RUN mkdir -p ${HADOOP_HOME} ${SPARK_HOME} \
 && chown -R ${MY_USERNAME}:${MY_USERNAME} ${HADOOP_HOME} ${SPARK_HOME}

# -----------------------------------------------------------------------------
# 5) Copia scripts e configurações base
# -----------------------------------------------------------------------------
COPY scripts /home/${MY_USERNAME}/scripts
RUN chown -R ${MY_USERNAME}:${MY_USERNAME} /home/${MY_USERNAME}/scripts \
 && chmod +x /home/${MY_USERNAME}/scripts/*.sh

# Define volume para receber configs processados por init
VOLUME /config_processed

# -----------------------------------------------------------------------------
# 6) Variáveis de ambiente
# -----------------------------------------------------------------------------
ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64 \
    HADOOP_HOME=${HADOOP_HOME} \
    SPARK_HOME=${SPARK_HOME} \
    HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop \
    SPARK_CONF_DIR=${SPARK_HOME}/conf \
    PATH=${PATH}:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin

# -----------------------------------------------------------------------------
# 7) Copia entrypoint e instruções de execução
# -----------------------------------------------------------------------------
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Default: mantem container vivo
CMD ["sleep", "infinity"]
# -----------------------------------------------------------------------------