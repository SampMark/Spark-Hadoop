#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Arquivo de Configuração de Ambiente do Spark (spark-env.sh)
#
# Descrição:
#   Este arquivo é lido (sourced) ao executar vários programas Spark.
#   Copie este arquivo de spark-env.sh.template para spark-env.sh e edite-o
#   para configurar o Spark para o seu ambiente.
#   Define variáveis de ambiente para configurar o Spark, como JAVA_HOME (geralmente
#   herdado), HADOOP_CONF_DIR (para integração com YARN e HDFS), configurações de
#   memória para Driver e Executores, e opções para daemons do modo Standalone.
#
# Autor: Marcus V D Sampaio /Organização: IFRN - Baseado no template Apache Spark
# Versão: 1.1 (Baseada no Spark 3.x)
# Data: 2024-06-05
#
# Inspiração Original:
#   Apache Software Foundation
#   https://spark.apache.org/docs/latest/spark-standalone.html#configuring-spark
#
# Licença:
#   Apache License, Version 2.0 (conforme o original do Spark)
#
# Boas Práticas e Recomendações:
#   - JAVA_HOME: Geralmente não precisa ser definido aqui se já estiver no ambiente
#     do sistema ou em hadoop-env.sh (e Spark estiver usando o mesmo Java que Hadoop).
#     Se precisar de um Java específico para Spark, defina-o aqui.
#   - HADOOP_CONF_DIR: Essencial se o Spark for executado sobre YARN ou acessar HDFS.
#     Deve apontar para o diretório de configuração do Hadoop (onde core-site.xml, etc. residem).
#   - SPARK_MASTER_HOST (Standalone): IP/Hostname para o Spark Master.
#   - SPARK_WORKER_MEMORY, SPARK_WORKER_CORES (Standalone): Recursos para os Workers.
#   - SPARK_DRIVER_MEMORY, SPARK_EXECUTOR_MEMORY, SPARK_EXECUTOR_CORES: Cruciais para
#     o desempenho das aplicações. Estes podem ser definidos aqui como padrões, mas
#     frequentemente são sobrescritos no `spark-submit`.
#   - SPARK_DAEMON_MEMORY: Memória para os daemons do Spark (Master, Worker, History Server).
#   - SPARK_LOG_DIR, SPARK_PID_DIR: Similar ao Hadoop, defina para locais persistentes.
# -----------------------------------------------------------------------------

# === Configurações Gerais do Spark ===

# 1. JAVA_HOME: Localização da instalação do Java.
#    Se não definido, o Spark tentará usar o JAVA_HOME do sistema ou o Java no PATH.
#    Geralmente, se o Spark roda com Hadoop, ele usará o mesmo JAVA_HOME.
# export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64" # Exemplo, se diferente do Hadoop

# 2. HADOOP_CONF_DIR: Diretório de configuração do Hadoop.
#    Necessário para que o Spark possa interagir com HDFS e YARN.
#    A linha `export HADOOP_CONF_DIR="${HADOOP_HOME}/etc/hadoop"` estava no final do arquivo
#    original fornecido. É uma configuração crucial e deve estar corretamente definida.
#    Certifique-se que HADOOP_HOME está definido no ambiente.
export HADOOP_CONF_DIR="${HADOOP_HOME}/etc/hadoop"
# Alternativamente, se HADOOP_HOME não estiver disponível mas o diretório de config for conhecido:
# export HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop" # Exemplo de caminho absoluto

# 3. SPARK_CONF_DIR: Diretório de configuração alternativo para o Spark.
#    Padrão: ${SPARK_HOME}/conf. Geralmente não precisa ser alterado.
# export SPARK_CONF_DIR="${SPARK_HOME}/conf"

# 4. SPARK_LOG_DIR: Diretório onde os arquivos de log dos daemons Spark são armazenados.
#    Padrão: ${SPARK_HOME}/logs.
#    Recomendado definir para um local persistente.
export SPARK_LOG_DIR="${SPARK_HOME}/logs"
# Exemplo para Docker:
# export SPARK_LOG_DIR="/var/log/spark/${USER}"

# 5. SPARK_PID_DIR: Diretório onde os arquivos PID dos daemons Spark são armazenados.
#    Padrão: /tmp.
#    Recomendado definir para um local mais estável.
export SPARK_PID_DIR="/var/run/spark"
# Exemplo para Docker:
# export SPARK_PID_DIR="/var/run/spark/${USER}"

# 6. SPARK_IDENT_STRING: String para identificar esta instância do Spark.
#    Padrão: $USER. Usado em nomes de arquivos de log e PID.
# export SPARK_IDENT_STRING=$USER

# 7. SPARK_NICENESS: Prioridade de agendamento para os daemons Spark.
#    Padrão: 0.
# export SPARK_NICENESS=0

# === Opções para Execução em Cluster YARN ===
# Estas são importantes se você estiver executando Spark no YARN.

# 1. YARN_CONF_DIR: Diretório de configuração do YARN.
#    O Spark geralmente o encontra através de HADOOP_CONF_DIR, mas pode ser definido
#    explicitamente se estiver em um local diferente.
# export YARN_CONF_DIR="${HADOOP_CONF_DIR}" # ou /caminho/para/conf/yarn

# 2. Memória e Cores Padrão para Aplicações Spark no YARN
#    Estes valores são padrões e podem ser sobrescritos via `spark-submit`.
#    Defini-los aqui pode ser útil para consistência.

# export SPARK_EXECUTOR_INSTANCES="2"  # Número padrão de executores por aplicação
export SPARK_EXECUTOR_CORES="1"      # Número de cores por executor
export SPARK_EXECUTOR_MEMORY="1g"    # Memória por executor (ex: 1g, 2048m)
export SPARK_DRIVER_MEMORY="1g"      # Memória para o Driver Program
# export SPARK_DRIVER_CORES="1"        # Cores para o Driver Program (em modo cluster YARN)

# === Opções para Daemons no Modo Standalone ===
# Configure estas se você estiver usando o modo de deploy Standalone do Spark.

# 1. SPARK_MASTER_HOST: IP ou hostname ao qual o Spark Master deve se vincular.
#    Padrão: hostname da máquina.
#    Em contêineres, pode ser útil definir como '0.0.0.0' para vincular a todas as interfaces,
#    e usar um hostname público/resolvível para os workers se conectarem.
# export SPARK_MASTER_HOST="spark-master" # Ex: nome do serviço/container Docker
# export SPARK_MASTER_IP="0.0.0.0" # Para o Master escutar em todas as interfaces

# 2. SPARK_MASTER_PORT: Porta para o Spark Master.
#    Padrão: 7077.
# export SPARK_MASTER_PORT=7077

# 3. SPARK_MASTER_WEBUI_PORT: Porta para a Web UI do Spark Master.
#    Padrão: 8080. (Cuidado com conflitos se o YARN RM UI também usar 8080 no mesmo host)
# export SPARK_MASTER_WEBUI_PORT=8081 # Exemplo de porta alternativa

# 4. SPARK_MASTER_OPTS: Opções JVM adicionais para o Spark Master.
#    Ex: -Dspark.deploy.defaultCores=4
# export SPARK_MASTER_OPTS="-Dspark.deploy.recoveryMode=FILESYSTEM -Dspark.deploy.recoveryDirectory=/opt/spark_recovery"

# 5. SPARK_WORKER_CORES: Número total de cores que um Worker pode alocar para executores.
#    Padrão: todos os cores disponíveis na máquina.
# export SPARK_WORKER_CORES="4" # Exemplo

# 6. SPARK_WORKER_MEMORY: Memória total que um Worker pode alocar para executores.
#    Ex: 1000m, 2g. Padrão: (RAM total - 1GB).
# export SPARK_WORKER_MEMORY="4g" # Exemplo

# 7. SPARK_WORKER_PORT: Porta para o Spark Worker.
#    Padrão: gerada aleatoriamente.
# export SPARK_WORKER_PORT=7078 # Exemplo

# 8. SPARK_WORKER_WEBUI_PORT: Porta para a Web UI do Spark Worker.
#    Padrão: 8081.
# export SPARK_WORKER_WEBUI_PORT=8082 # Exemplo

# 9. SPARK_WORKER_DIR: Diretório onde os workers armazenam dados de aplicação e logs de executores.
#    Padrão: SPARK_HOME/work.
#    Recomendado definir para um local com espaço suficiente e, se possível, persistente.
# export SPARK_WORKER_DIR="/opt/spark_work_data"

# 10. SPARK_WORKER_OPTS: Opções JVM adicionais para os Spark Workers.
# export SPARK_WORKER_OPTS="-Dspark.worker.cleanup.enabled=true -Dspark.worker.cleanup.interval=1800"

# 11. SPARK_DAEMON_MEMORY: Memória alocada para os próprios daemons Spark (Master, Worker, History Server).
#     Padrão: 1g.
export SPARK_DAEMON_MEMORY="1g"

# 12. SPARK_DAEMON_JAVA_OPTS: Opções JVM para todos os daemons Spark.
#      Ex: configurações de GC, JMX.
# export SPARK_DAEMON_JAVA_OPTS="-Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -XX:+UseG1GC"
# Exemplo específico para JMX no Master (se não usar SPARK_MASTER_OPTS para isso):
# export SPARK_DAEMON_JAVA_OPTS="${SPARK_DAEMON_JAVA_OPTS} -Dspark.master.jmx.port=7090"
# Exemplo específico para JMX no Worker:
# export SPARK_DAEMON_JAVA_OPTS="${SPARK_DAEMON_JAVA_OPTS} -Dspark.worker.jmx.port=7091"

# 13. SPARK_DAEMON_CLASSPATH: Classpath adicional para todos os daemons Spark.
# export SPARK_DAEMON_CLASSPATH="/path/to/custom/daemon_jars/*"

# === Opções para o History Server ===

# 1. SPARK_HISTORY_OPTS: Opções JVM específicas para o Spark History Server.
#    Importante para configurar o provedor de logs, JMX, etc.
#    Exemplo para configurar o diretório de logs no HDFS:
# export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=hdfs:///user/spark/sparkLogs"
# Exemplo para configurar JMX:
# export SPARK_HISTORY_OPTS="${SPARK_HISTORY_OPTS} -Dspark.history.ui.port=18080 -Dcom.sun.management.jmxremote.port=7092"
# A porta da UI (spark.history.ui.port) é geralmente definida em spark-defaults.conf, mas pode ser forçada aqui.

# === Opções para o External Shuffle Service (se usado com YARN) ===
# O External Shuffle Service é configurado no lado do YARN (NodeManager)
# e no Spark (para que as aplicações o utilizem).
# As configurações aqui são para o próprio daemon do Shuffle Service, se iniciado separadamente
# (o que é menos comum quando integrado ao YARN NodeManager como um aux-service).

# 1. SPARK_SHUFFLE_OPTS: Opções JVM para o External Shuffle Service.
# export SPARK_SHUFFLE_OPTS=

# === Opções de Rede ===

# 1. SPARK_LOCAL_IP: IP ao qual o Spark deve se vincular neste nó.
#    Pode ser útil em máquinas com múltiplos IPs.
#    Padrão: Spark tenta detectar automaticamente.
# export SPARK_LOCAL_IP="192.168.1.10" # Exemplo
# Em contêineres, `0.0.0.0` pode ser útil para vincular a todas as interfaces internas do contêiner.
# export SPARK_LOCAL_IP="0.0.0.0"

# 2. SPARK_PUBLIC_DNS: Nome DNS público do driver ou dos daemons.
#    Útil se os nós estiverem atrás de NAT ou em nuvens públicas.
# export SPARK_PUBLIC_DNS="meu-spark-master.exemplo.com"

# === Outras Opções ===

# SPARK_NO_DAEMONIZE: Se 'true', executa os daemons em foreground (útil para depuração/Docker).
# export SPARK_NO_DAEMONIZE="true"

# Para bibliotecas de Álgebra Linear Nativa (BLAS) como MKL, OpenBLAS.
# Descomente se estiver usando essas bibliotecas e quiser otimizar/controlar o threading.
# export MKL_NUM_THREADS=1
# export OPENBLAS_NUM_THREADS=1

# Fim do arquivo spark-env.sh
# -----------------------------------------------------------------------------
