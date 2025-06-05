#!/usr/bin/env bash
set -euo pipefail

# Carrega .env
source .env

HADOOP_TAR="hadoop-${HADOOP_VERSION}.tar.gz"
TARGET_DIR="docker/hadoop"

mkdir -p "${TARGET_DIR}"
echo "[download_hadoop] Baixando Hadoop ${HADOOP_VERSION}..."
curl -fsSL "${HADOOP_URL}" -o "/tmp/${HADOOP_TAR}"

# Exemplo de verificação de checksum
EXPECTED_SHA=$(grep "${HADOOP_TAR}" checksums-sha512.txt | awk '{ print $1 }')
ACTUAL_SHA=$(sha512sum "/tmp/${HADOOP_TAR}" | awk '{ print $1 }')
if [[ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]]; then
  echo "[download_hadoop] ERRO: checksum não confere!"
  exit 1
fi

tar -xzf "/tmp/${HADOOP_TAR}" -C "${TARGET_DIR}"
mv "${TARGET_DIR}/hadoop-${HADOOP_VERSION}" "${TARGET_DIR}/hadoop"
rm "/tmp/${HADOOP_TAR}"
echo "[download_hadoop] Hadoop extraído em ${TARGET_DIR}/hadoop."
