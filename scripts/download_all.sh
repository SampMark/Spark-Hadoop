#!/bin/sh
# =============================================================================
# Script de Download para Hadoop e Spark v2.0
#
# Descrição:
#   Realiza o download seguro dos binários do Apache Hadoop e Spark.
#   - Valida variáveis de ambiente.
#   - Verifica a integridade (SHA512) de arquivos já existentes.
#   - Baixa os arquivos apenas se necessário, verificando o checksum após o
#     download.
#
# Autor: [Marcus V D Sampaio/Organização: IFRN]
# Versão: 2.0
# =============================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
# CORREÇÃO: Habilita a falha imediata em caso de erro. Essencial para automação.
set -o errexit  # Sai imediatamente se um comando falhar (equivalente a set -e)
set -o nounset  # Trata variáveis não definidas como um erro (equivalente a set -u)
set -o pipefail # Faz com que o status de saída de um pipeline seja o do último comando que falhou

# --- Definição de Cores para Logs ---
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
YELLOW_COLOR='\033[0;33m'
LIGHTBLUE_COLOR='\033[0;36m'
RESET_COLORS='\033[0m'

log_info() { printf "%b[INFO]%b %s\n" "${GREEN_COLOR}" "${RESET_COLORS}" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "${YELLOW_COLOR}" "${RESET_COLORS}" "$1"; }
log_error() { printf "%b[ERROR]%b %s\n" "${RED_COLOR}" "${RESET_COLORS}" "$1"; exit 1; }

# --- Tratamento de Interrupção ---
# CORREÇÃO: Limpa arquivos temporários caso o script seja interrompido.
trap 'rm -f checksum_temp.sha512; log_warn "Download interrompido pelo usuário."; exit 1' INT TERM

# --- Rotina Principal ---
main() {
    log_info "Executando tarefa de download..."

    # 1. Valida variáveis de ambiente que devem ser injetadas pelo Docker Compose.
    # Remove a leitura direta do .env, tornando o script mais seguro e desacoplado.
    : "${HADOOP_VERSION:?A variável HADOOP_VERSION não foi definida no ambiente.}"
    : "${SPARK_VERSION:?A variável SPARK_VERSION não foi definida no ambiente.}"

    log_info "Hadoop Version: ${HADOOP_VERSION}"
    log_info "Spark Version: ${SPARK_VERSION}"

    # 2. Instala dependências de download
    install_dependencies
    log_info "Dependências instaladas com sucesso."
    
    # 3. Executa a lógica de download e verificação
    process_downloads
    adjust_permissions

    log_info "-----------------------------------------------------"
    log_info "Script de download concluído com sucesso!"
    log_info "Arquivos binários prontos para o build da imagem."
    log_info "-----------------------------------------------------"
}

# --- Instalação de Dependências ---
install_dependencies() {
    log_info "Verificando dependências (wget, aria2c, ca-certificates)..."
    if ! command -v wget >/dev/null || ! command -v aria2c >/dev/null || ! command -v update-ca-certificates >/dev/null; then
        log_info "Instalando pacotes necessários..."
        # CORREÇÃO: Inclui 'ca-certificates' para downloads HTTPS seguros.
        if command -v apk >/dev/null; then
            apk add --no-cache wget aria2 ca-certificates
            update-ca-certificates
        else
            log_error "Gerenciador de pacotes 'apk' não encontrado. Não é possível instalar dependências."
        fi
    else
        log_info "Dependências já satisfeitas."
    fi
}

# --- Processamento de Downloads ---
process_downloads() {
    # --- Definição de Nomes de Arquivos e URLs ---
    local APACHE_DOWNLOAD_BASE_URL="https://dlcdn.apache.org"
    local HADOOP_FILE="hadoop-${HADOOP_VERSION}.tar.gz"
    local HADOOP_URL="${APACHE_DOWNLOAD_BASE_URL}/hadoop/core/hadoop-${HADOOP_VERSION}/${HADOOP_FILE}"
    local HADOOP_SHA_URL="${APACHE_DOWNLOAD_BASE_URL}/hadoop/core/hadoop-${HADOOP_VERSION}/${HADOOP_FILE}.sha512"

    local SPARK_FILE="spark-${SPARK_VERSION}-bin-hadoop3.tgz"
    local SPARK_URL="${APACHE_DOWNLOAD_BASE_URL}/spark/spark-${SPARK_VERSION}/${SPARK_FILE}"
    local SPARK_SHA_URL="${APACHE_DOWNLOAD_BASE_URL}/spark/spark-${SPARK_VERSION}/${SPARK_FILE}.sha512"

    # --- Execução dos Downloads ---
    log_info "--- Processando Apache Hadoop ---"
    download_and_verify "${HADOOP_FILE}" "${HADOOP_URL}" "${HADOOP_SHA_URL}"

    log_info "--- Processando Apache Spark ---"
    download_and_verify "${SPARK_FILE}" "${SPARK_URL}" "${SPARK_SHA_URL}"
}

# --- Função de Download e Verificação ---
download_and_verify() {
    local filename="$1"
    local url="$2"
    local sha_url="$3"

    log_info "Obtendo checksum esperado para ${filename}..."
    local expected_checksum
    expected_checksum=$(wget -qO- "${sha_url}" | awk '{print $1}')

    if [ -z "${expected_checksum}" ] || [ ${#expected_checksum} -ne 128 ]; then
        log_error "Não foi possível obter um checksum SHA512 válido de ${sha_url}"
    fi
    log_info "Checksum esperado: ${expected_checksum}"

    # CORREÇÃO: Valida o checksum do arquivo local ANTES de pular o download.
    if [ -f "${filename}" ]; then
        log_info "Arquivo '${filename}' já existe. Verificando integridade..."
        local local_checksum
        local_checksum=$(sha512sum "${filename}" | awk '{print $1}')
        if [ "${local_checksum}" = "${expected_checksum}" ]; then
            log_info "Checksum do arquivo local é válido. Pulando download."
            return 0
        else
            log_warn "Checksum do arquivo local '${filename}' é INVÁLIDO. Baixando novamente."
            rm -f "${filename}"
        fi
    fi

    # CORREÇÃO: Habilita a verificação de certificado SSL no aria2c.
    log_info "Baixando '${filename}'..."
    aria2c \
        -x 6 -s 6 \
        --disable-ipv6 \
        --file-allocation=none \
        --allow-overwrite=true \
        --check-certificate=true \
        --checksum=sha-512="${expected_checksum}" \
        --out="${filename}" \
        "${url}"

    # O 'set -o errexit' garante que o script falhará aqui se o aria2c retornar um erro.
    log_info "Download de '${filename}' concluído e verificado com sucesso."
}

# --- Ajuste de Permissões ---
adjust_permissions() {
    log_info "Ajustando permissões dos arquivos baixados..."
    # A variável MY_USER_ID deve ser passada pelo docker-compose ou definida no .env se necessário.
    # Usar 1000 como padrão é uma convenção comum.
    local uid="${MY_USER_ID:-1000}"
    local gid="${MY_GROUP_ID:-1000}"

    if [ -f "hadoop-${HADOOP_VERSION}.tar.gz" ]; then
        chown "${uid}:${gid}" "hadoop-${HADOOP_VERSION}.tar.gz" || log_warn "Não foi possível alterar o proprietário do arquivo Hadoop."
    fi
    if [ -f "spark-${SPARK_VERSION}-bin-hadoop3.tgz" ]; then
        chown "${uid}:${gid}" "spark-${SPARK_VERSION}-bin-hadoop3.tgz" || log_warn "Não foi possível alterar o proprietário do arquivo Spark."
    fi
}

# --- Ponto de Entrada do Script ---
main
# --- Fim do Script ---
# =============================================================================
# Nota: Este script deve ser executado com as variáveis de ambiente
# HADOOP_VERSION e SPARK_VERSION estejam definidas, como em um Dockerfile ou docker-compose.yml.
# Exemplo de uso:
#   docker run --rm -e HADOOP_VERSION=3.3.1 -e SPARK_VERSION=3.1.2 my-hadoop-spark-image
# =============================================================================