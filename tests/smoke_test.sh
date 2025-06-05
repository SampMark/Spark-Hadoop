#!/usr/bin/env bash
set -euo pipefail

source .env
timeout=${HEALTHCHECK_TIMEOUT:-60}
host="localhost"
port="${HOST_HDFS_UI_PORT:-9870}"

echo "[smoke_test] Checando HDFS UI em ${host}:${port}..."

for i in $(seq 1 $timeout); do
  if curl --silent "http://${host}:${port}" >/dev/null; then
    echo "[smoke_test] Sucesso: HDFS UI responde."
    exit 0
  fi
  sleep 1
done

echo "[smoke_test] ERRO: HDFS UI não respondeu em ${timeout}s."
exit 1
# Fim do script smoke_test.sh
