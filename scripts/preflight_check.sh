#!/usr/bin/env bash
# =============================================================================
# Script de Verificação de Pré-voo (Preflight Check) para Cluster Hadoop/Spark
#
# Descrição:
#   Atua como um "gatekeeper", verificando pré-requisitos e configurações
#   básicas para garantir uma inicialização bem-sucedida do cluster.
#
# Verificações:
#   - Essenciais (sempre executadas):
#     1. Disponibilidade de comandos essenciais (java, ssh, hdfs, etc.).
#     2. Versões mínimas de software (Java >= 11, Python >= 3).
#     3. Conectividade SSH sem senha para todos os workers.
#     4. Resposta básica dos comandos HDFS e YARN (verificam a configuração).
#   - Integração (opcionais, podem ser pulados com --skip-integration):
#     5. Execução de um job MapReduce de ponta a ponta.
#     6. Funcionalidade do Jupyter nbconvert.
#
# Como Usar:
#   ./preflight_check.sh [--skip-integration]
# =============================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
set -euo pipefail
trap 'log_error "Script interrompido pelo usuário."; exit 1' INT TERM

# --- Funções de Logging e Cores ---
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

log_section() { printf "\n${COLOR_BLUE}===== %s =====${COLOR_RESET}\n" "$1"; }
log_info() { printf "${COLOR_YELLOW}[INFO] %s${COLOR_RESET}\n" "$1"; }
log_success() { printf "${COLOR_GREEN}[SUCCESS] %s${COLOR_RESET}\n" "$1"; }
log_error() { printf "${COLOR_RED}[ERROR] %s${COLOR_RESET}\n" "$1" >&2; exit 1; }

# --- Carregamento de Variáveis de Ambiente ---
# Assume que o .env já foi carregado pelo processo pai (init ou entrypoint).
# Validação explícita de variáveis essenciais.
: "${NUM_WORKER_NODES:?A variável NUM_WORKER_NODES não está definida.}"
: "${STACK_NAME:?A variável STACK_NAME não está definida.}"
: "${HADOOP_HOME:?A variável HADOOP_HOME não está definida.}"

# --- Funções de Verificação Modulares ---

# 1. Verifica se os comandos essenciais estão disponíveis no PATH.
check_essential_commands() {
    log_section "1. Verificando Comandos Essenciais"
    for cmd in bash java curl tar ssh hdfs yarn spark-submit jupyter; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Comando essencial não encontrado no PATH: '$cmd'."
        fi
    done
    log_success "Todos os comandos essenciais foram encontrados."
}

# 2. Verifica as versões mínimas de Java e Python.
check_software_versions() {
    log_section "2. Verificando Versões de Software"
    # Verificação do Java
    log_info "Verificando versão do Java..."
    local java_version; java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    local java_major; java_major=$(echo "$java_version" | awk -F. '{print ($1=="1"?$2:$1)}')
    if ((java_major < 11)); then
        log_error "Versão do Java incompatível. Requerido: >= 11. Encontrado: ${java_version}."
    fi
    log_success "Versão do Java OK: ${java_version}"

    # Verificação do Python
    log_info "Verificando versão do Python..."
    local python_version; python_version=$(python3 --version 2>&1 | awk '{print $2}')
    local python_major; python_major=$(echo "$python_version" | cut -d. -f1)
    if ((python_major < 3)); then
        log_error "Versão do Python incompatível. Requerido: >= 3. Encontrado: ${python_version}."
    fi
    log_success "Versão do Python OK: ${python_version}"
}

# 3. Verifica a conectividade SSH sem senha para todos os workers.
check_ssh_connectivity() {
    log_section "3. Verificando Conectividade SSH com Workers"
    log_info "Testando conexão SSH sem senha para ${NUM_WORKER_NODES} worker(s)..."
    for i in $(seq 1 "${NUM_WORKER_NODES}"); do
        local host="${STACK_NAME}-worker-${i}"
        log_info "--> Testando host: ${host}"
        # CORREÇÃO: Opções robustas para automação.
        if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${host}" "true"; then
            log_error "Falha na conexão SSH com o worker '${host}'. Verifique as chaves SSH e a rede."
        fi
    done
    log_success "Conectividade SSH com todos os workers está OK."
}

# 4. Valida a funcionalidade básica do HDFS e YARN.
check_hadoop_basics() {
    log_section "4. Verificando Configuração de HDFS e YARN"
    # CORREÇÃO: Usa 'timeout' para evitar que o script fique preso se os daemons não estiverem configurados.
    log_info "Testando resposta do comando HDFS (hdfs dfs -ls /)..."
    if ! timeout 15s hdfs dfs -ls / >/dev/null 2>&1; then
        log_error "Comando HDFS 'hdfs dfs -ls /' falhou ou demorou demais. Verifique a configuração (core-site.xml)."
    fi
    log_success "Comando HDFS respondeu (configuração OK)."

    log_info "Testando resposta do comando YARN (yarn node -list)..."
    if ! timeout 15s yarn node -list >/dev/null 2>&1; then
        log_error "Comando YARN 'yarn node -list' falhou. Verifique a configuração (yarn-site.xml)."
    fi
    log_success "Comando YARN respondeu (configuração OK)."
}

# 5. Executa um job MapReduce de ponta a ponta para testar a integração.
test_mapreduce_integration() {
    log_section "5. Teste de Integração MapReduce (WordCount)"
    local hdfs_input_dir="/tmp/preflight_mr_input"
    local hdfs_output_dir="/tmp/preflight_mr_output"
    # Garante a limpeza dos artefatos no HDFS ao sair da função.
    trap 'hdfs dfs -rm -r -f "${hdfs_input_dir}" "${hdfs_output_dir}" >/dev/null 2>&1 || true' RETURN

    log_info "Preparando dados de teste no HDFS..."
    hdfs dfs -mkdir -p "${hdfs_input_dir}"
    echo "preflight test preflight" | hdfs dfs -put -f - "${hdfs_input_dir}/test.txt"

    log_info "Executando job WordCount via YARN..."
    if ! hadoop jar "${HADOOP_HOME}/share/hadoop/mapreduce/hadoop-mapreduce-examples"*.jar wordcount \
      "${hdfs_input_dir}" "${hdfs_output_dir}" >/dev/null 2>&1; then
        log_error "Falha na execução do job MapReduce. Verifique se HDFS e YARN estão totalmente operacionais."
    fi

    log_info "Verificando resultado do job..."
    local result; result=$(hdfs dfs -cat "${hdfs_output_dir}/part-r-00000")
    if ! echo "${result}" | grep -q "preflight\s*2"; then
        log_error "Resultado do MapReduce inesperado. Obtido: '${result}'"
    fi
    log_success "Teste de integração MapReduce concluído com sucesso."
}

# 6. Verifica a funcionalidade do Jupyter e nbconvert.
test_jupyter_nbconvert() {
    log_section "6. Teste de Funcionalidade do Jupyter/nbconvert"
    local test_notebook; test_notebook=$(mktemp --suffix=.ipynb)
    # Garante a limpeza do arquivo local ao sair da função.
    trap 'rm -f "${test_notebook}"' RETURN

    log_info "Criando notebook de teste temporário..."
    # Notebook JSON mínimo
    printf '{"cells":[{"cell_type":"code","source":"print(1+1)"}],"metadata":{},"nbformat":4,"nbformat_minor":2}' > "${test_notebook}"

    log_info "Executando 'jupyter nbconvert' para validar a instalação e execução..."
    if ! jupyter nbconvert --to notebook --execute "${test_notebook}" --ExecutePreprocessor.timeout=30 --output "out.ipynb" >/dev/null 2>&1; then
        log_error "Execução do 'jupyter nbconvert' falhou. Verifique a instalação do Jupyter e seus kernels."
    fi
    rm -f out.ipynb
    log_success "Jupyter e nbconvert estão funcionando corretamente."
}

# --- Função Principal de Execução ---
main() {
    log_info "====================================================="
    log_info "   INICIANDO VERIFICAÇÕES DE PRÉ-VOO DO CLUSTER   "
    log_info "====================================================="

    # CORREÇÃO: Adiciona uma flag para pular testes de integração.
    local skip_integration=false
    if [[ "${1:-}" == "--skip-integration" ]]; then
        skip_integration=true
        log_warn "Flag --skip-integration detectada. Pulando testes de integração."
    fi

    # Executa cada verificação em sequência.
    check_essential_commands
    check_software_versions
    check_ssh_connectivity
    check_hadoop_basics

    if [[ "${skip_integration}" == false ]]; then
        log_info "Executando testes de integração (requerem serviços ativos)..."
        test_mapreduce_integration
        test_jupyter_nbconvert
    else
        log_info "Testes de integração pulados."
    fi

    log_info "-----------------------------------------------------"
    log_success "TODAS AS VERIFICAÇÕES DE PRÉ-VOO FORAM CONCLUÍDAS!"
    log_info "O ambiente parece estar pronto para a inicialização dos serviços."
    log_info "-----------------------------------------------------"
}

# --- Ponto de Entrada do Script ---
main "$@"
# =============================================================================
# Fim do script
# =============================================================================
# Nota: Este script deve ser executado antes de iniciar os serviços do cluster  .
# Ele não deve ser executado enquanto os serviços estão ativos, pois pode causar
# inconsistências ou falhas nas verificações.
# =============================================================================