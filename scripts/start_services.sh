#!/usr/bin/env bash
set -euo pipefail

source "/home/${MY_USERNAME}/.bash_common" || true

# Formata NameNode apenas se não estiver formatado
if [[ ! -d "${HADOOP_HOME}/hdfs/namenode/current" ]]; then
  echo "[start_services] Formatando NameNode..."
  "${HADOOP_HOME}/bin/hdfs" namenode -format -force -nonInteractive
fi

echo "[start_services] Iniciando HDFS..."
"${HADOOP_HOME}/sbin/start-dfs.sh"

echo "[start_services] Iniciando YARN..."
"${HADOOP_HOME}/sbin/start-yarn.sh"

echo "[start_services] Cluster Hadoop iniciado."
# Mantém o container rodando (por exemplo, tail -f nos logs)
tail -f /dev/null
# Fim do script start_services.sh