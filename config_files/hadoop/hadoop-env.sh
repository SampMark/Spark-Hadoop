#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Arquivo de Configuração de Ambiente do Hadoop (hadoop-env.sh)
#
# Descrição:
#   Este arquivo define variáveis de ambiente específicas para o Hadoop.
#   Ele atua como o arquivo mestre para todos os projetos Hadoop (HDFS, YARN, MapReduce),
#   e as configurações aqui definidas serão lidas por todos os comandos Hadoop.
#   É o local primário para configurar opções como JAVA_HOME, HADOOP_HOME,
#   configurações de heap da JVM, logs, e opções específicas para daemons.
#
# Autor: [Marcus V D Sampaio] - Baseado no template Apache Hadoop
# Versão: 1.1 (Baseada no Hadoop 3.x)
# Data: 2024-06-05
#
# Inspiração Original:
#   Apache Software Foundation
#
# Licença:
#   Apache License, Version 2.0 (conforme o original do Hadoop)
#
# Boas Práticas e Recomendações:
#   - JAVA_HOME: Essencial. Deve apontar para uma instalação JDK compatível.
#   - HADOOP_CONF_DIR: Geralmente não precisa ser definido aqui se este arquivo
#     estiver no local padrão ( HADOOP_HOME/etc/hadoop).
#   - HADOOP_LOG_DIR e HADOOP_PID_DIR: Recomenda-se definir para locais fora
#     do diretório de instalação do Hadoop, especialmente se este for volátil
#     (como em contêineres sem volumes persistentes para logs/pids).
#   - Configurações de Heap (HADOOP_HEAPSIZE_MAX/MIN e específicas por daemon):
#     Ajuste conforme os recursos da máquina e a carga de trabalho.
#   - HADOOP_OPTS: Para opções globais da JVM. Opções específicas por daemon
#     (HDFS_NAMENODE_OPTS, etc.) têm precedência.
#   - Comentários: Mantenha os comentários originais do Apache e adicione os seus
#     para clarificar customizações.
#   - Variáveis não utilizadas: Comente ou remova variáveis que não estão sendo
#     customizadas para manter o arquivo limpo.
# -----------------------------------------------------------------------------

# === Configurações Genéricas para o HADOOP ===

# 1. JAVA_HOME: Implementação Java a ser utilizada.
#    Esta é a variável de ambiente MAIS CRÍTICA.
#    O Hadoop requer um JDK (Java Development Kit), não apenas um JRE.
#    Verifique a compatibilidade da versão do Java com a sua versão do Hadoop.
#    Exemplo para OpenJDK 11 (comum para Hadoop 3.x):
export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
# Para descobrir o JAVA_HOME automaticamente (se houver apenas um JDK principal):
# export JAVA_HOME=${JAVA_HOME:-$(readlink -f /usr/bin/java | sed "s:/bin/java::")}
# Certifique-se de que este caminho é válido e aponta para um JDK.

# 2. HADOOP_HOME: Localização da instalação do Hadoop.
#    Geralmente, o Hadoop tenta determinar isso automaticamente.
#    Descomente e ajuste se necessário, especialmente se os scripts não
#    estiverem sendo executados a partir do diretório bin/sbin do Hadoop.
# export HADOOP_HOME="/opt/hadoop" # Exemplo

# 3. HADOOP_CONF_DIR: Diretório de configuração do Hadoop.
#    Onde este arquivo (hadoop-env.sh) e outros (core-site.xml, etc.) residem.
#    Normalmente HADOOP_HOME/etc/hadoop.
#    Não é recomendado definir aqui se estiver no local padrão.
# export HADOOP_CONF_DIR="${HADOOP_HOME}/etc/hadoop"

# 4. HADOOP_LOG_DIR: Diretório para armazenar os arquivos de log dos daemons.
#    Padrão: ${HADOOP_HOME}/logs.
#    Recomendado: Definir para um local persistente, especialmente em contêineres.
export HADOOP_LOG_DIR="${HADOOP_LOG_DIR:-${HADOOP_HOME}/logs}"
# Exemplo para Docker, montando um volume em /var/log/hadoop:
# export HADOOP_LOG_DIR="/var/log/hadoop/${USER}" # Adicionar ${USER} é uma boa prática

# 5. HADOOP_PID_DIR: Diretório para armazenar os arquivos PID dos daemons.
#    Padrão: /tmp.
#    Recomendado: Definir para um local mais estável, como /var/run/hadoop.
export HADOOP_PID_DIR="${HADOOP_PID_DIR:-/var/run/hadoop}"
# Exemplo para Docker, montando um volume em /var/run/hadoop:
# export HADOOP_PID_DIR="/var/run/hadoop/${USER}"

# 6. HADOOP_IDENT_STRING: String para identificar esta instância do Hadoop.
#    Padrão: $USER. Usado em nomes de arquivos de log e PID.
#    Pode ser útil customizar em ambientes com múltiplos clusters/usuários.
export HADOOP_IDENT_STRING="${USER}"

# 7. HADOOP_OPTS: Opções globais da JVM para todos os comandos Hadoop.
#    O valor original fornecido já inclui -Djava.net.preferIPv4Stack=true
#    e -Djava.library.path=${HADOOP_COMMON_LIB_NATIVE_DIR}.
#    -XX:-PrintWarnings: Suprime avisos da JVM (pode ser útil em produção, mas oculte problemas).
#    -Djava.net.preferIPv4Stack=true: Força o uso de IPv4, útil se IPv6 não estiver configurado ou causar problemas.
#    -Djava.library.path: Caminho para as bibliotecas nativas do Hadoop. HADOOP_COMMON_LIB_NATIVE_DIR
#                         deve ser definido (geralmente HADOOP_HOME/lib/native).
# Mantenha ou ajuste conforme necessário.
export HADOOP_OPTS="${HADOOP_OPTS} -XX:-PrintWarnings -Djava.net.preferIPv4Stack=true"
# Adicionar -Djava.library.path se HADOOP_COMMON_LIB_NATIVE_DIR não for pego automaticamente:
# Se HADOOP_HOME estiver definido:
# export HADOOP_OPTS="${HADOOP_OPTS} -Djava.library.path=${HADOOP_HOME}/lib/native"
# Nota: A variável HADOOP_COMMON_LIB_NATIVE_DIR é geralmente definida pelos scripts do Hadoop.
# Se você estiver tendo problemas com bibliotecas nativas (ex: snappy, lz4), verifique este caminho.

# 8. HADOOP_HEAPSIZE_MAX e HADOOP_HEAPSIZE_MIN: Tamanho do Heap da JVM (global).
#    Define -Xmx e -Xms para os daemons, a menos que substituído por configurações
#    específicas do daemon (ex: HDFS_NAMENODE_OPTS).
#    Se não definido, a JVM auto-ajusta (o que pode não ser ideal para daemons de longa duração).
#    Valores em MB se nenhuma unidade for fornecida.
#    Exemplos (ajuste aos seus recursos):
# export HADOOP_HEAPSIZE_MAX="2g"  # 2 GB Max Heap
# export HADOOP_HEAPSIZE_MIN="1g"  # 1 GB Min Heap
# Para daemons, é recomendado definir _OPTS específicos (veja abaixo).

# 9. HADOOP_SSH_OPTS: Opções para SSH usado pelos scripts de gerenciamento (start-dfs.sh, etc.).
#    -o BatchMode=yes: Não pedir senhas/passphrases.
#    -o StrictHostKeyChecking=no: Não perguntar sobre chaves de host desconhecidas (CUIDADO: implicações de segurança).
#                                  Útil em ambientes dinâmicos/contêineres.
#    -o ConnectTimeout=10s: Timeout para conexão.
export HADOOP_SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10s"

# 10. HADOOP_WORKERS: Arquivo que lista os nós worker (DataNodes, NodeManagers).
#     Padrão: ${HADOOP_CONF_DIR}/workers.
#     Normalmente não precisa ser alterado.
# export HADOOP_WORKERS="${HADOOP_CONF_DIR}/workers"

# 11. HADOOP_ROOT_LOGGER: Configuração de log padrão para comandos interativos.
#     Padrão: INFO,console.
#     O valor original "WARN,DRFA" sugere um appender customizado (DRFA).
#     Se DRFA não estiver configurado em log4j.properties, pode causar erro.
#     Recomenda-se manter o padrão ou ajustar conforme sua configuração log4j.
export HADOOP_ROOT_LOGGER="INFO,console"
# Para suprimir o aviso sobre HADOOP_HOME não estar definido (se você gerencia HADOOP_HOME de outra forma):
# export HADOOP_HOME_WARN_SUPPRESS="true"

# 12. HADOOP_DAEMON_ROOT_LOGGER: Configuração de log para daemons.
#     Padrão: INFO,RFA (RollingFileAppender).
# export HADOOP_DAEMON_ROOT_LOGGER="INFO,RFA"


# === Configurações Específicas por Daemon ===
# Estas opções são anexadas a HADOOP_OPTS e têm precedência.

# --- HDFS ---
# HDFS_NAMENODE_OPTS: Opções JVM para o NameNode.
#   Exemplo: configurar JMX, logs de GC.
#   O padrão "-Dhadoop.security.logger=INFO,RFAS" é para logs de segurança.
#   Para produção, é crucial ajustar o heap (-Xms, -Xmx) e possivelmente GC.
export HDFS_NAMENODE_OPTS="-Xms1g -Xmx1g -Dhadoop.security.logger=INFO,RFAS ${HADOOP_NAMENODE_OPTS:-}"
# Exemplo com JMX e GC detalhado:
# export HDFS_NAMENODE_OPTS="-Xms2g -Xmx2g \
#   -Dcom.sun.management.jmxremote.authenticate=false \
#   -Dcom.sun.management.jmxremote.ssl=false \
#   -Dcom.sun.management.jmxremote.port=8004 \
#   -XX:+UseG1GC -XX:MaxGCPauseMillis=200 \
#   -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps \
#   -Xloggc:${HADOOP_LOG_DIR}/namenode-gc.log \
#   -Dhadoop.security.logger=INFO,RFAS \
#   ${HADOOP_NAMENODE_OPTS:-}"


# HDFS_SECONDARYNAMENODE_OPTS: Opções JVM para o SecondaryNameNode.
#   Semelhante ao NameNode, mas geralmente requer menos heap.
export HDFS_SECONDARYNAMENODE_OPTS="-Xms1g -Xmx1g -Dhadoop.security.logger=INFO,RFAS ${HADOOP_SECONDARYNAMENODE_OPTS:-}"

# HDFS_DATANODE_OPTS: Opções JVM para o DataNode.
#   O padrão "-Dhadoop.security.logger=ERROR,RFAS" é mais restritivo para logs de segurança.
#   Ajuste o heap conforme a capacidade do nó e o número de blocos.
export HDFS_DATANODE_OPTS="-Xms1g -Xmx1g -Dhadoop.security.logger=ERROR,RFAS ${HADOOP_DATANODE_OPTS:-}"

# Para DataNodes seguros (usando jsvc e portas privilegiadas):
# export HDFS_DATANODE_SECURE_USER=hdfs
# export HDFS_DATANODE_SECURE_EXTRA_OPTS="-jvm server"

# HDFS_JOURNALNODE_OPTS: Opções JVM para o JournalNode (para HDFS HA com Quorum Journal Manager).
# export HDFS_JOURNALNODE_OPTS="-Xms512m -Xmx512m ${HADOOP_JOURNALNODE_OPTS:-}"

# HDFS_ZKFC_OPTS: Opções JVM para o ZKFailoverController (para HDFS HA com Zookeeper).
# export HDFS_ZKFC_OPTS="-Xms512m -Xmx512m ${HADOOP_ZKFC_OPTS:-}"


# --- YARN ---
# YARN_RESOURCEMANAGER_OPTS: Opções JVM para o ResourceManager.
#   Crucial ajustar heap.
export YARN_RESOURCEMANAGER_OPTS="-Xms1g -Xmx1g ${HADOOP_RESOURCEMANAGER_OPTS:-}"
# Exemplo com mais heap:
# export YARN_RESOURCEMANAGER_OPTS="-Xms2g -Xmx2g ${HADOOP_RESOURCEMANAGER_OPTS:-}"

# YARN_NODEMANAGER_OPTS: Opções JVM para o NodeManager.
#   Heap deve ser ajustado com base nos recursos do nó e na memória alocada para contêineres.
export YARN_NODEMANAGER_OPTS="-Xms1g -Xmx1g ${HADOOP_NODEMANAGER_OPTS:-}"

# YARN_TIMELINESERVER_OPTS: Opções JVM para o Timeline Server (ATS v1.x ou v2).
# export YARN_TIMELINESERVER_OPTS="-Xms1g -Xmx1g ${HADOOP_TIMELINESERVER_OPTS:-}"


# --- MapReduce ---
# MAPRED_HISTORYSERVER_OPTS: Opções JVM para o MapReduce JobHistory Server.
#   Geralmente não requer muito heap, a menos que haja um histórico muito grande.
export MAPRED_HISTORYSERVER_OPTS="-Xms1g -Xmx1g ${HADOOP_HISTORYSERVER_OPTS:-}"

# HADOOP_JOB_HISTORYSERVER_HEAPSIZE: Heap específico para o JobHistory Server (alternativa a _OPTS).
# export HADOOP_JOB_HISTORYSERVER_HEAPSIZE="1000" # Em MB


# --- Outras Configurações Avançadas (geralmente não precisam ser alteradas) ---

# HADOOP_CLIENT_OPTS: Opções JVM para comandos cliente do Hadoop (hdfs dfs, etc.).
# export HADOOP_CLIENT_OPTS="-Xmx512m"

# HADOOP_USER_CLASSPATH_FIRST: Se "yes", o HADOOP_CLASSPATH definido pelo usuário
#                              tem precedência sobre o classpath do Hadoop.
# export HADOOP_USER_CLASSPATH_FIRST="yes"

# JSVC_HOME: Caminho para jsvc, se usado para daemons seguros.
# export JSVC_HOME="/usr/bin" # Ou /opt/commons-daemon/bin/jsvc

# --- Configurações Específicas do Seu Ambiente (Adicionar conforme necessário) ---
# Exemplo: Se você tiver bibliotecas customizadas que precisam estar no classpath de todos os daemons:
# export HADOOP_CLASSPATH="${HADOOP_CLASSPATH}:/opt/custom_libs/*"

# Exemplo: Configurações de GC padrão para todos os daemons (pode ser referenciado em _OPTS específicos)
# export HADOOP_DAEMON_GC_SETTINGS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200"
# E então, por exemplo:
# export HDFS_NAMENODE_OPTS="-Xms2g -Xmx2g ${HADOOP_DAEMON_GC_SETTINGS} ${HADOOP_NAMENODE_OPTS:-}"

# Fim do arquivo hadoop-env.sh
# -----------------------------------------------------------------------------
# Nota Final:
#   Este arquivo é um ponto de partida. Ajuste as configurações conforme necessário
#   para o seu ambiente e as cargas de trabalho específicas do Hadoop.
#   Sempre teste as alterações em um ambiente de desenvolvimento antes de aplicá-las
#   em produção.
#   Consulte a documentação oficial do Hadoop para mais detalhes sobre cada opção.
#   https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/HadoopUserGuide.html
# -----------------------------------------------------------------------------