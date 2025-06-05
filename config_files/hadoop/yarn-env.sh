#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Arquivo de Configuração de Ambiente do YARN (yarn-env.sh)
#
# Descrição:
#   Este arquivo define variáveis de ambiente específicas para os componentes YARN
#   (ResourceManager, NodeManager, TimelineServer, etc.). As configurações aqui
#   definidas têm precedência sobre as configurações globais em 'hadoop-env.sh'
#   para os processos YARN.
#
# Autor: Marcus V D Sampaio/Organização: IFRN - Baseado no template Apache Hadoop
# Versão: 1.1 (Baseada no Hadoop 3.x)
# Data: 2024-06-05
#
# Inspiração Original: Apache Software Foundation
#
# Licença:
#   Apache License, Version 2.0 (conforme o original do Hadoop)
#
# Regras de Precedência para Configurações YARN:
#   1. yarn-env.sh (este arquivo)
#   2. hadoop-env.sh (configurações globais do Hadoop)
#   3. Padrões hard-coded no Hadoop.
#
#   Variáveis no formato YARN_XYZ têm precedência sobre HADOOP_XYZ para processos YARN.
#
# Boas Práticas e Recomendações:
#   - JAVA_HOME: Geralmente herdado de 'hadoop-env.sh'. Defina aqui apenas se
#     necessário um Java diferente especificamente para YARN (raro).
#   - YARN_LOG_DIR e YARN_PID_DIR: Podem ser definidos para customizar os locais
#     de logs e PIDs dos daemons YARN, sobrescrevendo HADOOP_LOG_DIR/HADOOP_PID_DIR.
#   - Configurações de Heap (YARN_xyz_HEAPSIZE e YARN_xyz_OPTS): Essenciais para
#     o desempenho e estabilidade do ResourceManager e NodeManagers. Ajuste
#     conforme os recursos da máquina e a carga de trabalho.
#   - Comentários: Mantenha os comentários originais e adicione os seus para
#     clarificar customizações.
# -----------------------------------------------------------------------------

# === Variáveis de Ambiente Globais para YARN (Opcional) ===

# 1. YARN_LOG_DIR: Diretório para armazenar os arquivos de log dos daemons YARN.
#    Sobrescreve HADOOP_LOG_DIR para processos YARN.
#    Padrão: ${HADOOP_LOG_DIR}.
# export YARN_LOG_DIR="/var/log/hadoop-yarn/${USER}"

# 2. YARN_PID_DIR: Diretório para armazenar os arquivos PID dos daemons YARN.
#    Sobrescreve HADOOP_PID_DIR para processos YARN.
#    Padrão: ${HADOOP_PID_DIR}.
# export YARN_PID_DIR="/var/run/hadoop-yarn/${USER}"

# 3. YARN_NICENESS: Nível de prioridade para os processos daemon do YARN.
#    Padrão: Herda de HADOOP_NICENESS ou 0.
# export YARN_NICENESS=0

# === Configurações Específicas para o ResourceManager (RM) ===

# 1. YARN_RESOURCEMANAGER_HEAPSIZE: Tamanho máximo do heap (-Xmx) para o ResourceManager.
#    Em MB se nenhuma unidade for fornecida.
#    Este valor pode ser sobrescrito por uma configuração -Xmx em YARN_RESOURCEMANAGER_OPTS
#    ou HADOOP_OPTS.
#    Padrão: Mesmo que HADOOP_HEAPSIZE_MAX (se definido), ou auto-ajustado pela JVM.
#    É ALTAMENTE RECOMENDADO definir este valor explicitamente.
# export YARN_RESOURCEMANAGER_HEAPSIZE="2g" # Exemplo: 2 Gigabytes

# 2. YARN_RESOURCEMANAGER_OPTS: Opções JVM específicas para o ResourceManager.
#    Estas opções são anexadas a HADOOP_OPTS e podem sobrescrever flags similares.
#    Importante para tuning de performance, GC, JMX, etc.
#    Exemplo básico com Xms e Xmx (se YARN_RESOURCEMANAGER_HEAPSIZE não for usado para Xmx):
export YARN_RESOURCEMANAGER_OPTS="-Xms1g -Xmx1g ${YARN_RESOURCEMANAGER_OPTS:-}"
# Exemplo mais completo com JMX, logs de GC detalhados e usando G1GC:
# export YARN_RESOURCEMANAGER_OPTS="\
#   -Xms2g -Xmx2g \
#   -Dcom.sun.management.jmxremote.authenticate=false \
#   -Dcom.sun.management.jmxremote.ssl=false \
#   -Dcom.sun.management.jmxremote.port=8034 \
#   -XX:+UseG1GC -XX:MaxGCPauseMillis=200 \
#   -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps \
#   -Xloggc:${YARN_LOG_DIR:-${HADOOP_LOG_DIR:-${HADOOP_HOME}/logs}}/rm-gc.log-$(date +'%Y%m%d%H%M') \
#   -Drm.audit.logger=INFO,RMAUDIT \
#   ${YARN_RESOURCEMANAGER_OPTS:-}"
#   Nota: ${YARN_RESOURCEMANAGER_OPTS:-} no final permite que esta variável seja
#   sobrescrita ou complementada por uma variável de ambiente de mesmo nome.

# === Configurações Específicas para o NodeManager (NM) ===

# 1. YARN_NODEMANAGER_HEAPSIZE: Tamanho máximo do heap (-Xmx) para o NodeManager.
#    Em MB se nenhuma unidade for fornecida.
#    Padrão: Mesmo que HADOOP_HEAPSIZE_MAX.
#    RECOMENDADO definir explicitamente.
# export YARN_NODEMANAGER_HEAPSIZE="2g" # Exemplo: 2 Gigabytes

# 2. YARN_NODEMANAGER_OPTS: Opções JVM específicas para o NodeManager.
#    Anexadas a HADOOP_OPTS.
#    Ajuste o heap e outras opções com base nos recursos do nó e no perfil dos contêineres.
export YARN_NODEMANAGER_OPTS="-Xms1g -Xmx1g ${YARN_NODEMANAGER_OPTS:-}"
# Exemplo com JMX e logs de GC:
# export YARN_NODEMANAGER_OPTS="\
#   -Xms2g -Xmx2g \
#   -Dcom.sun.management.jmxremote.authenticate=false \
#   -Dcom.sun.management.jmxremote.ssl=false \
#   -Dcom.sun.management.jmxremote.port=8043 \
#   -XX:+UseG1GC \
#   -Xloggc:${YARN_LOG_DIR:-${HADOOP_LOG_DIR:-${HADOOP_HOME}/logs}}/nm-gc.log-$(date +'%Y%m%d%H%M') \
#   -Dnm.audit.logger=INFO,NMAUDIT \
#   ${YARN_NODEMANAGER_OPTS:-}"

# === Configurações Específicas para o Timeline Server (ATS) ===
# O Timeline Server armazena informações genéricas sobre aplicações concluídas.
# ATS v1.x e ATS v2 têm configurações e daemons diferentes.
# As variáveis abaixo são mais relevantes para ATS v1.x ou o componente de escrita do ATS v2.

# 1. YARN_TIMELINESERVER_HEAPSIZE: Tamanho máximo do heap (-Xmx) para o TimelineServer.
#    Padrão: Mesmo que HADOOP_HEAPSIZE_MAX.
# export YARN_TIMELINESERVER_HEAPSIZE="1g" # Exemplo

# 2. YARN_TIMELINESERVER_OPTS: Opções JVM específicas para o TimelineServer.
#    Anexadas a HADOOP_OPTS.
export YARN_TIMELINESERVER_OPTS="-Xms1g -Xmx1g ${YARN_TIMELINESERVER_OPTS:-}"
# Exemplo:
# export YARN_TIMELINESERVER_OPTS="\
#  -Xms1g -Xmx1g \
#  -Dcom.sun.management.jmxremote.port=8190 \
#  ${YARN_TIMELINESERVER_OPTS:-}"

# Para ATS v2, pode haver daemons específicos como TimelineServiceV2 (Writer/Reader).
# Consulte a documentação do Hadoop para variáveis específicas do ATS v2 se estiver usando.
# export YARN_TIMELINE_WRITER_OPTS="..."
# export YARN_TIMELINE_READER_OPTS="..."

# === Configurações Específicas para o Web App Proxy Server ===
# O Proxy Server é usado quando a UI do YARN é acessada através de um proxy.

# 1. YARN_PROXYSERVER_HEAPSIZE: Tamanho máximo do heap (-Xmx) para o WebAppProxyServer.
#    Padrão: Mesmo que HADOOP_HEAPSIZE_MAX.
# export YARN_PROXYSERVER_HEAPSIZE="1g" # Exemplo

# 2. YARN_PROXYSERVER_OPTS: Opções JVM específicas para o WebAppProxyServer.
#    Anexadas a HADOOP_OPTS.
export YARN_PROXYSERVER_OPTS="-Xms512m -Xmx512m ${YARN_PROXYSERVER_OPTS:-}"

# === Configurações para Outros Componentes YARN (Comentadas por Padrão) ===
# Descomente e configure se você usar esses componentes.

# Shared Cache Manager (para reuso de recursos entre aplicações)
# export YARN_SHAREDCACHEMANAGER_OPTS=

# Router (para federação YARN)
# export YARN_ROUTER_HEAPSIZE=
# export YARN_ROUTER_OPTS="-Drouter.audit.logger=INFO,ROUTERAUDIT"

# Global Policy Generator (para federação YARN)
# export YARN_GLOBALPOLICYGENERATOR_HEAPSIZE=
# export YARN_GLOBALPOLICYGENERATOR_OPTS=

# Registry DNS (obsoleto aqui, configurar em hadoop-env.sh)
# export YARN_REGISTRYDNS_SECURE_USER=yarn
# export YARN_REGISTRYDNS_SECURE_EXTRA_OPTS="-jvm server"

# === Configurações de Serviços YARN (YARN Services) ===
# Para executar serviços de longa duração no YARN (ex: Apache Slider, HBase no YARN).

# Diretório contendo exemplos de serviços YARN
# export YARN_SERVICE_EXAMPLES_DIR="${HADOOP_YARN_HOME}/share/hadoop/yarn/yarn-service-examples"

# Controle sobre o uso do Docker runtime para contêineres YARN Services
# export YARN_CONTAINER_RUNTIME_DOCKER_RUN_OVERRIDE_DISABLE=true

# --- Análise da Linha `export YARN_HEAPSIZE=2000` do arquivo original ---
# A variável `YARN_HEAPSIZE` com valor `2000` (presumivelmente 2000MB) não é uma
# variável de ambiente padrão do Hadoop/YARN para configurar o heap de daemons específicos
# como ResourceManager ou NodeManager.
#
# Possíveis interpretações e ações:
# 1. Era uma tentativa de definir um heap padrão para TODOS os daemons YARN:
#    Nesse caso, é melhor usar HADOOP_HEAPSIZE_MAX em hadoop-env.sh ou configurar
#    YARN_xyz_HEAPSIZE para cada daemon individualmente neste arquivo, pois têm
#    requisitos diferentes.
#
# 2. Era uma tentativa de configurar o heap padrão para contêineres YARN:
#    A configuração de memória para contêineres YARN é feita principalmente através
#    de propriedades em `yarn-site.xml` (ex: `yarn.scheduler.minimum-allocation-mb`,
#    `yarn.scheduler.maximum-allocation-mb`, `yarn.nodemanager.resource.memory-mb`).
#    Esta variável em `yarn-env.sh` não afetaria diretamente o heap dos contêineres.
#
# 3. Era uma variável customizada para outros scripts:
#    Se este for o caso, ela pode ser mantida se outros scripts no seu ambiente
#    dependerem dela, mas deve ser documentado seu propósito.
#
# Recomendação:
#   - Remover ou comentar esta linha (`export YARN_HEAPSIZE=2000`), pois ela não
#     corresponde a uma configuração padrão de daemon YARN e pode causar confusão.
#   - Focar em configurar `YARN_RESOURCEMANAGER_HEAPSIZE`, `YARN_NODEMANAGER_HEAPSIZE`,
#     e as respectivas `_OPTS` para um controle preciso do heap dos daemons.
#
# A linha original era:
# # Maximum heap size for YARN containers
# export YARN_HEAPSIZE=2000
# O comentário "Maximum heap size for YARN containers" é incorreto para este arquivo/variável.
# Se o objetivo era realmente influenciar o heap dos contêineres, isso é feito de outra forma.
# Vou comentar a linha e adicionar esta explicação.

# Linha do arquivo original:
# # Maximum heap size for YARN containers
# export YARN_HEAPSIZE=2000
# Análise: Esta variável e comentário não correspondem à forma padrão de configurar
# o heap de daemons YARN ou de contêineres YARN. O heap de daemons é configurado
# por YARN_xyz_HEAPSIZE ou YARN_xyz_OPTS. O heap de contêineres é gerenciado
# pelas configurações em yarn-site.xml e pela aplicação submetida.
# Recomenda-se comentar ou remover esta linha e usar as variáveis padrão.

# Fim do arquivo yarn-env.sh
# -----------------------------------------------------------------------------