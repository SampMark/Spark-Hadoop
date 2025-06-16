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

# --- Verificação de Dependências ---
# CORREÇÃO: Verifica se 'envsubst' e 'awk' estão disponíveis no ambiente.
check_dependencies() {
    command -v envsubst >/dev/null 2>&1 || { log_error "envsubst não encontrado. Instale o pacote 'gettext'."; }
    command -v awk >/dev/null 2>&1 || { log_error "awk não encontrado. Instale o pacote 'gawk' ou 'mawk'."; }
}
# CORREÇÃO: A função check_dependencies agora é chamada no início do script para garantir que as dependências estejam disponíveis.
check_dependencies

# --- Funções de Logging ---
log_info() { printf "%b[INFO]%b %s\n" "${GREEN_COLOR}" "${RESET_COLORS}" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "${YELLOW_COLOR}" "${RESET_COLORS}" "$1"; }
log_error() { printf "%b[ERROR]%b %s\n" "${RED_COLOR}" "${RESET_COLORS}" "$1"; exit 1; }

# --- Tratamento de Interrupção ---
# CORREÇÃO: Garante que arquivos temporários sejam limpos se o script for interrompido.
trap 'rm -f compose.tmp.yml; log_warn "Script interrompido pelo usuário."; exit 1' INT TERM

# --- Constantes e Caminhos de Arquivos ---
# CORREÇÃO: Centraliza a definição de caminhos para fácil manutenção.
readonly SCRIPT_DIR="scripts"
readonly TEMPLATE_FILE="docker-compose.template.yml"
readonly OUTPUT_COMPOSE="docker-compose.yml"
readonly DOWNLOAD_SCRIPT_PATH="${SCRIPT_DIR}/download_all.sh"

# --- Validação das Variáveis de Ambiente Essenciais ---
main() {
    # 1. Valida o ambiente
    validate_variables
    # CORREÇÃO: A função validate_variables agora verifica se as variáveis essenciais estão definidas.
    log_info "Iniciando processo de configuração do ambiente..."

    : "${STACK_NAME:?A variável STACK_NAME não foi definida no arquivo .env}"
    : "${IMAGE_NAME:?A variável IMAGE_NAME não foi definida no arquivo .env}"
    : "${SPARK_WORKER_INSTANCES:?A variável SPARK_WORKER_INSTANCES não foi definida no arquivo .env}"
    : "${HADOOP_VERSION:?A variável HADOOP_VERSION não foi definida no arquivo .env}"
    : "${SPARK_VERSION:?A variável SPARK_VERSION não foi definida no arquivo .env}"

    # CORREÇÃO: Validação robusta para garantir que SPARK_WORKER_INSTANCES é um inteiro positivo.
    if ! printf "%s" "${SPARK_WORKER_INSTANCES}" | grep -Eq '^[1-9][0-9]*$'; then
        log_error "A variável SPARK_WORKER_INSTANCES deve ser um inteiro positivo (1 ou mais). Valor recebido: '${SPARK_WORKER_INSTANCES}'"
    fi

    # 2. Gera o arquivo de configuração principal
    generate_compose_file "${SPARK_WORKER_INSTANCES}"
    
    # 3. Decide se o download é necessário e delega a tarefa
    download_if_needed

    log_info "-----------------------------------------------------"
    log_info "Script de inicialização concluído com sucesso!"
    log_info "Você pode agora construir e iniciar o cluster com:"
    log_info "${YELLOW_COLOR}docker compose up --build -d${RESET_COLORS}"
    log_info "-----------------------------------------------------"
}

# --- Função para Gerar o Arquivo docker-compose.yml ---
# CORREÇÃO: Implementação completa usando 'envsubst' e 'awk' para uma geração robusta.
# Esta abordagem é muito superior ao 'cat << EOF' por ser flexível e menos propensa a erros.
generate_compose_file() {
    local num_workers="$1"

    if [ ! -f "${TEMPLATE_FILE}" ]; then
        log_error "Arquivo de template '${TEMPLATE_FILE}' não encontrado. Não é possível gerar o docker-compose.yml."
    fi

    log_info "Gerando '${OUTPUT_COMPOSE}' para ${YELLOW_COLOR}${num_workers}${RESET_COLORS} nó(s) worker(s)..."

    # 1. Substitui as variáveis de ambiente (ex: ${STACK_NAME}) no template.
    # As variáveis são exportadas para que envsubst possa encontrá-las.
    export STACK_NAME IMAGE_NAME SPARK_WORKER_INSTANCES HADOOP_VERSION SPARK_VERSION
    envsubst < "${TEMPLATE_FILE}" > compose.tmp.yml

    # 2. Gera o bloco de configuração para os serviços de workers.
    # Este bloco será injetado no arquivo temporário.
    worker_block=""
    i=1
    while [ "${i}" -le "${num_workers}" ]; do
        # O 'x-common-properties' deve estar definido no seu docker-compose.template.yml
        worker_block="${worker_block}  worker-${i}:
    <<: *common-properties
    container_name: \${STACK_NAME}-worker-${i}
    hostname: \${STACK_NAME}-worker-${i}
    command: [\"WORKER\", \"${i}\"]
" # A quebra de linha aqui é intencional
        i=$((i + 1))
    done

    # 3. Injeta o bloco de workers no local do marcador '## WORKER_SERVICES ##'.
    # `awk` é perfeito para esta tarefa de substituição de texto.
    awk -v block="${worker_block}" '/## WORKER_SERVICES ##/ { print block; next } 1' compose.tmp.yml > "${OUTPUT_COMPOSE}"

    # 4. Limpa o arquivo temporário.
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