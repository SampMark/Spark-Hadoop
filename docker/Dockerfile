# =============================================================================
# Dockerfile para Cluster Hadoop e Spark
#
# Autor: Marcus V D Sampaio/Organização: IFRN 
# Data: 2025-06-16
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

### Argumentos de Build
# Argumentos usados para definir as versões do Hadoop, Spark, Java e Ubuntu.
# Podem ser substituídos durante o build usando a opção --build-arg.
ARG HADOOP_VERSION=3.4.1
ARG SPARK_VERSION=3.5.6
ARG JAVA_VERSION=11
ARG UBUNTU_VERSION=24.04
ARG APT_MIRROR=http://archive.ubuntu.com/ubuntu

################################################################################
# Estágio 1: Inicialização (init)
################################################################################
# Propósito: Executar o script init.sh para gerar o docker-compose.yml
# Este estágio é responsável por configurar o ambiente inicial, baixar as
# dependências necessárias e preparar o ambiente para os estágios de build.
# Ele não contém os binários do Hadoop ou Spark, apenas o script de inicialização.
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS init

LABEL maintainer="Marcus V D Sampaio <marcus.sampaio@ifrn.edu.br>"
LABEL description="Imagem Docker com Apache Hadoop e Spark e JupyterLab para clusters de Big Data."

# SHELL definido como bash para suportar 'pipefail'
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG APT_MIRROR
ENV DEBIAN_FRONTEND=noninteractive

# Instala dependências
RUN \
    echo "Configuring APT mirror to ${APT_MIRROR}..." && \
    # Substituído 'cat <<EOF' por uma série de comandos 'echo' para maior robustez.
    # Esta abordagem é mais segura e menos propensa a erros de sintaxe no Dockerfile.
    echo "deb ${APT_MIRROR} noble main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb ${APT_MIRROR} noble-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb ${APT_MIRROR} noble-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb ${APT_MIRROR} noble-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    # Continua com a instalação dos pacotes
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      bash \
      gettext \
      curl \
      wget \
      gnupg \
      lsb-release \
      ca-certificates && \
    # Limpeza para reduzir o tamanho da imagem
    apt-get clean && rm -rf /var/lib/apt/lists/*
    
# Cria diretório de trabalho
WORKDIR /app
# WORKDIR /usr/local/bin

# Copia todos os arquivos e scripts necessários para o diretório de trabalho.
COPY init.sh .
COPY docker-compose.template.yml .
COPY scripts/ ./scripts/
# COPY init.sh /usr/local/bin/init.sh

# Garante que os scripts tenham permissão de execução.
RUN chmod +x init.sh && \
    if [ -f "scripts/download_all.sh" ]; then chmod +x scripts/download_all.sh; fi
# RUN chmod +x /usr/local/bin/init.sh

# Define o entrypoint para o script de inicialização
ENTRYPOINT ["./init.sh"]
# ENTRYPOINT ["/usr/local/bin/init.sh"]

# =============================================================================
# ESTÁGIO 2: Build do Hadoop (Preparação e Validação)
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS build-hadoop

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Argumento de build para a versão do Hadoop
ARG HADOOP_VERSION=3.4.1

# Variáveis de ambiente para o estágio
ENV MY_USERNAME=myuser
ENV MY_WORKDIR=/opt
# ENV MY_WORKDIR=/home/${MY_USERNAME}
ENV HADOOP_VERSION=${HADOOP_VERSION}
ENV HADOOP_HOME=${MY_WORKDIR}/hadoop
ENV HADOOP_TARBALL="hadoop-${HADOOP_VERSION}.tar.gz"

WORKDIR ${MY_WORKDIR}

# Copia o tarball e o checksum do contexto de build.
# O Dockerfile DEPENDE que esses arquivos tenham sido pré-baixados.
COPY hadoop-${HADOOP_VERSION}.tar.gz hadoop-${HADOOP_VERSION}.tar.gz.sha512 ./

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
# ESTÁGIO 3: Build do Spark (Preparação e Validação)
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS build-spark

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Argumentos de build para a versão do Spark
ARG SPARK_VERSION=3.5.6
ARG SPARK_PROFILE=hadoop3

# Variáveis de ambiente para o estágio
ENV MY_USERNAME=myuser
ENV MY_WORKDIR=/opt
# ENV MY_WORKDIR=/home/${MY_USERNAME}
ENV SPARK_VERSION=${SPARK_VERSION}
ENV SPARK_HOME=${MY_WORKDIR}/spark
ENV SPARK_TARBALL="spark-${SPARK_VERSION}-bin-${SPARK_PROFILE}.tar.gz"

WORKDIR ${MY_WORKDIR}

# Copia o tarball e o checksum do contexto.
# ATENÇÃO: Se houver mais de um arquivo que combine com o wildcard (spark-*.tar.gz ou spark-*.tar.gz.sha512),
# o build pode falhar devido à ambiguidade. Certifique-se de que apenas UM arquivo de cada tipo esteja presente no contexto.
COPY spark-${SPARK_VERSION}-bin-${SPARK_PROFILE}.tar.gz spark-${SPARK_VERSION}-bin-${SPARK_PROFILE}.tar.gz.sha512 ./

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
    # 3. Extrai o Spark e renomeia o diretório extraído
    echo "Extraindo Spark..." && \
    tar -zxf "${SPARK_TARBALL}" -C ${MY_WORKDIR} && \
    EXTRACTED_DIR=$(tar -tzf "${SPARK_TARBALL}" | head -1 | cut -f1 -d"/") && \
    mv "${MY_WORKDIR}/${EXTRACTED_DIR}" "${SPARK_HOME}" && \
    # 4. Limpeza
    rm -f "${SPARK_TARBALL}" "${SPARK_TARBALL}.sha512"

# =============================================================================
# ESTÁGIO 4: Imagem Final
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS final

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
ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64
ENV DEBIAN_FRONTEND=noninteractive

RUN \
    # Instala todas as dependências do sistema
    # Limitação: Se o arquivo sources.list tiver um formato customizado ou múltiplos mirrors não padrão, esta substituição pode não funcionar corretamente.
    if [ -n "$APT_MIRROR" ]; then \
      sed -i "s|http://archive.ubuntu.com/ubuntu|${APT_MIRROR}|g" /etc/apt/sources.list; \
    fi && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      openjdk-11-jdk-headless \
      ssh \
      openssh-client \
      openssh-server \
      openssl \
      ca-certificates \
      procps \
      net-tools \
      lsof \
      sudo \
      gosu \
      python3.12 \
      python3-pip \
      python3.12-venv \
      python3.12-dev \
      python3.12-distutils \
      python3.12-apt \
      python3.12-tk \
      jupyterlab \
      nano \
      dos2unix \
      wget \
      curl \
      iputils-ping \
    && \
    apt-get autoremove -yqq --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    if [ ! -e /usr/bin/python ] || [ "$(readlink -f /usr/bin/python)" != "/usr/bin/python3.12" ]; then \
      ln -sf /usr/bin/python3.12 /usr/bin/python; \
    else \
      echo "Warning: /usr/bin/python already exists and points to $(readlink -f /usr/bin/python)"; \
    fi && \
    if [ ! -e /usr/bin/python3 ] || [ "$(readlink -f /usr/bin/python3)" != "/usr/bin/python3.12" ]; then \
      ln -sf /usr/bin/python3.12 /usr/bin/python3; \
    else \
      echo "Warning: /usr/bin/python3 already exists and points to $(readlink -f /usr/bin/python3)"; \
    fi

# Instala dependências Python
ENV PATH="/opt/venv/bin:$PATH"
COPY ./requirements.txt /tmp/requirements.txt

RUN \
    python3 -m venv /opt/venv && \
    python3 -m pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm -f /tmp/requirements.txt

# RUN \
#     python3.12 -m pip install --upgrade pip && \
#     python3.12 -m venv /opt/venv && \
#     /opt/venv/bin/pip install --no-cache-dir -q -r /tmp/requirements.txt && \
#     rm -f /tmp/requirements.txt
# ENV PATH="/opt/venv/bin:$PATH"

# Configuração do usuário
RUN \
    groupadd --gid 1000 ${MY_GROUP} || true && \
    useradd --uid 1000 --gid ${MY_GROUP} --shell /bin/bash --create-home ${MY_USERNAME} && \
    usermod -aG sudo ${MY_USERNAME} && \
    echo "${MY_USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${MY_USERNAME}

# RUN \
#     userdel --remove ubuntu || true && \
#     groupadd --gid 1000 ${MY_GROUP} || true && \
#     useradd --uid 1000 --gid ${MY_GROUP} --shell /bin/bash --create-home ${MY_USERNAME} && \
#     usermod -aG sudo ${MY_USERNAME} && \
#     echo "${MY_USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${MY_USERNAME}
WORKDIR ${MY_WORKDIR}

# Copia binários e arquivos da aplicação
# COPY --from=build-hadoop --chown=${MY_USERNAME}:${MY_GROUP} /home/myuser/hadoop ${HADOOP_HOME}/
# COPY --from=build-spark --chown=${MY_USERNAME}:${MY_GROUP} /home/myuser/spark ${SPARK_HOME}/
COPY --from=build-hadoop /opt/hadoop ${HADOOP_HOME}/
COPY --from=build-spark /opt/spark ${SPARK_HOME}/
COPY --chown=${MY_USERNAME}:${MY_GROUP} scripts/ ${MY_WORKDIR}/scripts/
COPY --chown=${MY_USERNAME}:${MY_GROUP} docker/entrypoint.sh ${MY_WORKDIR}/docker/entrypoint.sh
COPY --chown=${MY_USERNAME}:${MY_GROUP} .bash_common ${MY_WORKDIR}/.bash_common

# Copia o arquivo de configuração do JupyterLab
COPY --chown=${MY_USERNAME}:${MY_GROUP} jupyter_notebook_config.py ${MY_WORKDIR}/.jupyter/jupyter_notebook_config.py
# Cria diretório de trabalho e configura permissões
RUN \
    mkdir -p ${MY_WORKDIR}/.jupyter && \
    mkdir -p ${MY_WORKDIR}/derby-metastore && \
    chown -R ${MY_USERNAME}:${MY_GROUP} ${MY_WORKDIR} && \
    chmod 755 ${MY_WORKDIR}/docker/entrypoint.sh && \
    chmod 644 ${MY_WORKDIR}/.bash_common && \
    chmod 644 ${MY_WORKDIR}/.jupyter/jupyter_notebook_config.py
# Configura o diretório de trabalho e o usuário
WORKDIR ${MY_WORKDIR}

# Configurações finais, permissões e SSH
RUN \
    find "${MY_WORKDIR}/scripts" -name '*.sh' -exec dos2unix -q -k {} + && \
    dos2unix -q -k ${MY_WORKDIR}/docker/entrypoint.sh && \
    echo -e '\n# Carrega configurações comuns do cluster\n[ -f "${HOME}/.bash_common" ] && . "${HOME}/.bash_common"\n' >> "${MY_WORKDIR}/.bashrc" && \
    echo 'source /opt/venv/bin/activate' >> "${MY_WORKDIR}/.bashrc" && \
    chown -R ${MY_USERNAME}:${MY_GROUP} ${HADOOP_HOME} ${SPARK_HOME} && \
    ssh-keygen -q -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key && \
    ssh-keygen -q -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key && \
    ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key && \
    mkdir -p ${MY_WORKDIR}/.ssh && \
    ssh-keygen -q -t rsa -N "" -f ${MY_WORKDIR}/.ssh/id_rsa && \
    cat ${MY_WORKDIR}/.ssh/id_rsa.pub >> ${MY_WORKDIR}/.ssh/authorized_keys && \
    chown -R ${MY_USERNAME}:${MY_GROUP} ${MY_WORKDIR}/.ssh && \
    chmod 0700 ${MY_WORKDIR}/.ssh && \
    chmod 0600 ${MY_WORKDIR}/.ssh/authorized_keys ${MY_WORKDIR}/.ssh/id_rsa

# RUN \
#     if find "${MY_WORKDIR}/scripts" -maxdepth 1 -name '*.sh' | grep -q .; then \
#       find "${MY_WORKDIR}/scripts" -maxdepth 1 -name '*.sh' -exec dos2unix -q -k {} +; \
#     fi && \
#     dos2unix -q -k ${MY_WORKDIR}/docker/entrypoint.sh && \
#     echo -e '\n# Carrega configurações comuns do cluster\n[ -f "${HOME}/.bash_common" ] && . "${HOME}/.bash_common"\n' >> "${MY_WORKDIR}/.bashrc" && \
    
#     # Ativa o virtual environment automaticamente para shells interativos
#     echo 'source /opt/venv/bin/activate' >> "${MY_WORKDIR}/.bashrc" && \

#     if [ ! -f "${MY_WORKDIR}/.ssh/id_rsa" ]; then \
#       ssh-keygen -q -t rsa -N "" -f ${MY_WORKDIR}/.ssh/id_rsa; \
#     fi && \
#     cat ${MY_WORKDIR}/.ssh/id_rsa.pub >> ${MY_WORKDIR}/.ssh/authorized_keys && \
#     # Adicionado .ssh/config à configuração de permissões
#     chmod 0700 ${MY_WORKDIR}/.ssh && \
#     chmod 0600 ${MY_WORKDIR}/.ssh/authorized_keys ${MY_WORKDIR}/.ssh/id_rsa && \
#     chmod 0644 ${MY_WORKDIR}/.ssh/id_rsa.pub && \
#     # Cria diretório de log para o metastore do Spark SQL.
#     mkdir -p ${MY_WORKDIR}/derby-metastore
ENTRYPOINT ["${MY_WORKDIR}/docker/entrypoint.sh"]
CMD ["bash", "${MY_WORKDIR}/scripts/bootstrap.sh", "MASTER"]