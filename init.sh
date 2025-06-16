#!/bin/bash
# =============================================================================
# Script de Inicialização e Geração do Docker Compose v2.0
#
# Descrição:
#   Este script automatiza a configuração do ambiente, incluindo:
#   1. Validação de variáveis de ambiente essenciais.
#   2. Geração dinâmica do 'docker-compose.yml' a partir de um template,
#      injetando dinamicamente os serviços dos workers.
#   3. Download condicional dos binários do Hadoop e Spark.
#
# Autor: [Marcus V D Sampaio/Organização: IFRN]
# Versão: 2.0
# =============================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
set -o errexit  # Sai imediatamente se um comando falhar (equivalente a set -e)
set -o nounset  # Trata variáveis não definidas como um erro (equivalente a set -u)
set -o pipefail # Faz com que o status de saída de um pipeline seja o do último comando que falhou

# --- Definição de Cores para Logs (POSIX-compatível) ---
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
YELLOW_COLOR='\033[0;33m'
LIGHTBLUE_COLOR='\033[0;36m'
RESET_COLORS='\033[0m'
# Cores definidas de forma compatível com POSIX para garantir portabilidade.

# --- Funções de Logging ---
log_info() { printf "%b[INFO]%b %s\n" "${GREEN_COLOR}" "${RESET_COLORS}" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "${YELLOW_COLOR}" "${RESET_COLORS}" "$1"; }
log_error() { printf "%b[ERROR]%b %s\n" "${RED_COLOR}" "${RESET_COLORS}" "$1"; exit 1; }

# --- Verificação de Dependências ---
# Verifica se 'envsubst' e 'awk' estão disponíveis no ambiente.
check_dependencies() {
    command -v envsubst >/dev/null 2>&1 || { log_error "envsubst não encontrado. Instale o pacote 'gettext'."; }
    command -v awk >/dev/null 2>&1 || { log_error "awk não encontrado. Instale o pacote 'gawk' ou 'mawk'."; }
}

# --- Tratamento de Interrupção ---
# CORREÇÃO: Garante que arquivos temporários sejam limpos se o script for interrompido.
trap 'rm -f compose.tmp.yml; log_warn "Script interrompido pelo usuário."; exit 1' INT TERM

# --- Constantes e Caminhos de Arquivos ---
readonly SCRIPT_DIR="scripts"
readonly TEMPLATE_FILE="docker-compose.template.yml"
readonly OUTPUT_COMPOSE="docker-compose.yml"
readonly DOWNLOAD_SCRIPT_PATH="${SCRIPT_DIR}/download_all.sh"

# --- Validação das Variáveis de Ambiente ---
validate_variables() {
    log_info "Validando variáveis de ambiente essenciais..."

    # Verifica se as variáveis existem, falhando se estiverem ausentes.
    : "${STACK_NAME:?A variável STACK_NAME não foi definida no arquivo .env}"
    : "${IMAGE_NAME:?A variável IMAGE_NAME não foi definida no arquivo .env}"
    : "${SPARK_WORKER_INSTANCES:?A variável SPARK_WORKER_INSTANCES não foi definida no arquivo .env}"
    : "${HADOOP_VERSION:?A variável HADOOP_VERSION não foi definida no arquivo .env}"
    : "${SPARK_VERSION:?A variável SPARK_VERSION não foi definida no arquivo .env}"

    # Validação para garantir que SPARK_WORKER_INSTANCES é um inteiro positivo.
    if ! [[ "${SPARK_WORKER_INSTANCES}" =~ ^[1-9][0-9]*$ ]]; then
        log_error "A variável SPARK_WORKER_INSTANCES deve ser um inteiro positivo (1 ou mais). Valor recebido: '${SPARK_WORKER_INSTANCES}'"
    fi
    log_info "Variáveis de ambiente validadas com sucesso."
}

# --- Função Principal ---
main() {
    # 1. Garante que as dependências (awk, envsubst) estão disponíveis
    check_dependencies
    
    # 2. Valida as variáveis de ambiente do arquivo .env
    validate_variables

    log_info "Iniciando processo de configuração do ambiente..."

    # 3. Gera o arquivo de configuração principal
    generate_compose_file "${SPARK_WORKER_INSTANCES}"
    
    # 4. Decide se o download é necessário e o executa
    download_if_needed

    log_info "-----------------------------------------------------"
    log_info "Script de inicialização concluído com sucesso!"
    log_info "Você pode agora construir e iniciar o cluster com:"
    log_info "${YELLOW_COLOR}docker compose up --build -d${RESET_COLORS}"
    log_info "-----------------------------------------------------"
}

# --- Função para Gerar o Arquivo docker-compose.yml ---
# Implementação completa usando 'envsubst' e 'awk' para uma geração robusta.
# Abordagem superior ao 'cat << EOF' por ser flexível e menos propensa a erros.
generate_compose_file() {
    local num_workers="$1"

    if [ ! -f "${TEMPLATE_FILE}" ]; then
        log_error "Arquivo de template '${TEMPLATE_FILE}' não encontrado."
    fi

    log_info "Gerando '${OUTPUT_COMPOSE}' para ${YELLOW_COLOR}${num_workers}${RESET_COLORS} nó(s) worker(s)..."

    # Exporta as variáveis para que 'envsubst' possa usá-las
    export STACK_NAME IMAGE_NAME SPARK_WORKER_INSTANCES HADOOP_VERSION SPARK_VERSION
    envsubst < "${TEMPLATE_FILE}" > compose.tmp.yml

    # Gera o bloco de configuração para os serviços dos workers
    worker_block=""
    i=1
    while [ "${i}" -le "${num_workers}" ]; do
        worker_block="${worker_block}  worker-${i}:
    <<: *common-properties
    container_name: \${STACK_NAME}-worker-${i}
    hostname: \${STACK_NAME}-worker-${i}
    command: [\"WORKER\", \"${i}\"]
"
        i=$((i + 1))
    done

    # Injeta o bloco de workers no local do marcador '## WORKER_SERVICES ##'
    awk -v block="${worker_block}" '/## WORKER_SERVICES ##/ { print block; next } 1' compose.tmp.yml > "${OUTPUT_COMPOSE}"

    # Limpa o arquivo temporário
    rm compose.tmp.yml

    log_info "'${OUTPUT_COMPOSE}' gerado com sucesso."
}

# --- Função para Execução Condicional do Script de Download ---
# CORREÇÃO: Lógica de download mais clara e com melhor tratamento de erros.
download_if_needed() {
    # A variável vem do .env, com 'false' como padrão seguro se não estiver definida.
    if [ "${DOWNLOAD_HADOOP_SPARK:-false}" = "true" ]; then
        log_info "DOWNLOAD_HADOOP_SPARK=true. Iniciando download de Hadoop e Spark..."

        if [ ! -x "${DOWNLOAD_SCRIPT_PATH}" ]; then
            log_error "Script de download '${DOWNLOAD_SCRIPT_PATH}' não encontrado ou não possui permissão de execução."
        fi

        # Executa o script de download. `set -o errexit` garante que o script pare se houver falha.
        "${DOWNLOAD_SCRIPT_PATH}"

        log_info "Download de Hadoop/Spark concluído com sucesso."
    else
        log_info "DOWNLOAD_HADOOP_SPARK não está definido como 'true'. Pulando download."
    fi
}

# --- Ponto de Entrada do Script ---
main "$@"
# --- Fim do Script ---
# =============================================================================