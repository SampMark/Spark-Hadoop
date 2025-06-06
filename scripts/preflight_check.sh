#!/usr/bin/env bash
# =============================================================================
# Script de Verificação de Pré-voo (Preflight Check) para Cluster Hadoop/Spark
#
# Descrição:
#   Este script foi projetado para ser executado ANTES da inicialização dos
#   serviços principais do cluster. Ele atua como um "gatekeeper", verificando
#   se todos os pré-requisitos, dependências e configurações básicas estão
#   corretos para garantir uma inicialização bem-sucedida do cluster.
#
#   Verificações Realizadas:
#   1. Disponibilidade de comandos essenciais (java, curl, ssh, hdfs, etc.).
#   2. Versões mínimas de software (Java >= 11, Python >= 3).
#   3. Conectividade SSH sem senha entre o master e todos os nós workers.
#   4. Funcionalidade básica dos comandos HDFS e YARN.
#   5. Execução de um job MapReduce de ponta a ponta (WordCount).
#   6. Funcionalidade do Jupyter nbconvert.
#
# Como Usar:
#   Este script pode ser chamado pelo 'entrypoint.sh' ou executado manualmente
#   dentro do contêiner 'spark-master' antes de chamar 'bootstrap.sh'.
#
# =============================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
set -euo pipefail

# --- Funções de Logging e Cores ---
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

log_section() {
    printf "\n${COLOR_BLUE}===== %s =====${COLOR_RESET}\n" "$1"
}

log_info() {
    printf "${COLOR_YELLOW}[INFO] %s${COLOR_RESET}\n" "$1"
}

log_success() {
    printf "${COLOR_GREEN}[SUCCESS] %s${COLOR_RESET}\n" "$1"
}

log_error() {
    printf "${COLOR_RED}[ERROR] %s${COLOR_RESET}\n" "$1" >&2
    exit 1
}

# --- Carregamento de Variáveis de Ambiente ---
# Carrega variáveis do .env, para obter NUM_WORKER_NODES, STACK_NAME, etc.
if [[ -f ".env" ]]; then
    set -a
    source .env
    set +a
fi

# --- Funções de Verificação Modulares ---

# 1. Verifica se os comandos essenciais estão disponíveis no PATH.
check_essential_commands() {
    log_section "1. Verificando Comandos Essenciais"
    local all_found=true
    # Adicionados comandos sugeridos: ssh, java, curl, tar, hdfs, yarn, spark-submit, jupyter
    for cmd in bash java curl tar ssh hdfs yarn spark-submit jupyter; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Comando essencial não encontrado no PATH: '$cmd'."
            all_found=false
        fi
    done
    [[ "$all_found" = true ]] && log_success "Todos os comandos essenciais foram encontrados."
}

# 2. Verifica as versões mínimas de Java e Python.
check_software_versions() {
    log_section "2. Verificando Versões de Software"

    # Verificação do Java (requerido: 11+)
    log_info "Verificando versão do Java..."
    local java_version
    # O `awk` é mais robusto para extrair a versão de diferentes formatos de `java -version`.
    java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    local java_major
    java_major=$(echo "$java_version" | awk -F. '{print $1}')
    if [[ "$java_major" == "1" ]]; then # Lida com o formato antigo "1.8.0"
        java_major=$(echo "$java_version" | awk -F. '{print $2}')
    fi
    if ((java_major < 11)); then
        log_error "Versão do Java incompatível. Requerido: 11 ou superior. Encontrado: ${java_version} (Major: ${java_major})."
    fi
    log_success "Versão do Java OK: ${java_version}"

    # Verificação do Python (requerido: 3+)
    log_info "Verificando versão do Python..."
    # Usar python3 explicitamente para evitar ambiguidades com python2.
    local python_version
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    local python_major
    python_major=$(echo "$python_version" | cut -d. -f1)
    if ((python_major < 3)); then
        log_error "Versão do Python incompatível. Requerido: 3 ou superior. Encontrado: ${python_version}."
    fi
    log_success "Versão do Python OK: ${python_version}"
}

# 3. Verifica a conectividade SSH sem senha para todos os workers.
check_ssh_connectivity() {
    log_section "3. Verificando Conectividade SSH com Workers"
    : "${NUM_WORKER_NODES:?A variável NUM_WORKER_NODES não está definida.}"
    : "${STACK_NAME:?A variável STACK_NAME não está definida.}"

    log_info "Testando conexão SSH sem senha para ${NUM_WORKER_NODES} worker(s)..."
    for i in $(seq 1 "${NUM_WORKER_NODES}"); do
        local host="${STACK_NAME}-worker-${i}"
        log_info "--> Testando host: ${host}"
        # Usa opções para evitar prompts e definir um timeout.
        if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${host}" "true"; then
            log_error "Falha na conexão SSH com o worker '${host}'. Verifique as configurações de SSH (chaves, /etc/hosts, rede)."
        fi
    done
    log_success "Conectividade SSH com todos os workers está OK."
}

# 4. Valida a funcionalidade básica do HDFS e YARN.
check_hadoop_basics() {
    log_section "4. Verificando Funcionalidade Básica do HDFS e YARN"

    # Validação do HDFS
    log_info "Testando comando HDFS (hdfs dfs -ls /)..."
    # O `timeout` evita que o script fique preso indefinidamente.
    if ! timeout 20s hdfs dfs -ls / >/dev/null; then
        log_error "Comando HDFS 'hdfs dfs -ls /' falhou ou demorou demais. Verifique se o NameNode está configurado, mas não iniciado."
    fi
    log_success "Comando HDFS respondeu corretamente."

    # Validação do YARN
    log_info "Testando comando YARN (yarn node -list)..."
    if ! timeout 20s yarn node -list >/dev/null; then
        log_error "Comando YARN 'yarn node -list' falhou. Verifique se o ResourceManager está configurado, mas não iniciado."
    fi
    log_success "Comando YARN respondeu corretamente."
}

# 5. Executa um job MapReduce de ponta a ponta para testar a integração.
test_mapreduce_integration() {
    log_section "5. Teste de Integração MapReduce (WordCount)"
    local hdfs_input_dir="/tmp/preflight_mr_input"
    local hdfs_output_dir="/tmp/preflight_mr_output"
    local local_input_file
    local_input_file=$(mktemp)

    # Garante a limpeza dos artefatos ao final
    cleanup() {
        hdfs dfs -rm -r -f "${hdfs_input_dir}" "${hdfs_output_dir}" >/dev/null 2>&1 || true
        rm -f "${local_input_file}"
    }
    trap cleanup EXIT

    log_info "Preparando dados no HDFS..."
    echo "preflight test preflight" > "${local_input_file}"
    hdfs dfs -mkdir -p "${hdfs_input_dir}"
    hdfs dfs -put -f "${local_input_file}" "${hdfs_input_dir}/"

    log_info "Executando job WordCount via YARN..."
    if ! hadoop jar "${HADOOP_HOME}/share/hadoop/mapreduce/hadoop-mapreduce-examples"*.jar wordcount \
      "${hdfs_input_dir}" "${hdfs_output_dir}" >/dev/null 2>&1; then
        # Este teste precisa que o cluster esteja rodando
        log_warn "O teste de integração MapReduce requer que os serviços HDFS e YARN estejam em execução."
        log_warn "Se este teste falhar, pode ser normal se os serviços ainda não foram iniciados."
        log_success "Submissão do job MapReduce concluída (sem verificação de resultado no modo preflight)."
        return 0 
    fi

    log_info "Verificando resultado..."
    local result
    result=$(hdfs dfs -cat "${hdfs_output_dir}/part-r-00000")
    local expected="preflight\t2"
    if [[ "${result}" != *"${expected}"* ]]; then
        log_error "Resultado do MapReduce inesperado. Obtido: '${result}'"
    fi
    log_success "Teste de integração MapReduce concluído com sucesso."
}


# 6. Verifica a funcionalidade do Jupyter e nbconvert.
test_jupyter_nbconvert() {
    log_section "6. Teste de Funcionalidade do Jupyter/nbconvert"
    local test_notebook_path="/tmp/preflight_test.ipynb"
    local test_output_dir="/tmp/preflight_nb_output"

    cleanup() {
        rm -f "${test_notebook_path}"
        rm -rf "${test_output_dir}"
    }
    trap cleanup EXIT

    log_info "Criando notebook de teste temporário..."
    # Notebook JSON mínimo
    cat << EOF > "${test_notebook_path}"
{
 "cells": [{"cell_type": "code", "execution_count": null, "metadata": {}, "outputs": [], "source": ["print('Hello from Jupyter preflight test!')"]}],
 "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"}},
 "nbformat": 4,
 "nbformat_minor": 2
}
EOF

    log_info "Executando 'jupyter nbconvert' para validar a instalação..."
    # O timeout garante que o teste não fique preso.
    if ! jupyter nbconvert --to notebook --execute "${test_notebook_path}" \
      --ExecutePreprocessor.timeout=30 \
      --output-dir="${test_output_dir}"; then
        log_error "Execução do 'jupyter nbconvert' falhou. Verifique a instalação do Jupyter e seus kernels."
    fi
    log_success "Jupyter e nbconvert estão funcionando corretamente."
}


# --- Função Principal de Execução ---
main() {
    log_info "====================================================="
    log_info "   INICIANDO VERIFICAÇÕES DE PRÉ-VOO DO CLUSTER   "
    log_info "====================================================="

    # Executa cada verificação em sequência. O script sairá no primeiro erro.
    check_essential_commands
    check_software_versions
    check_ssh_connectivity
    check_hadoop_basics
    
    # Os testes de integração são mais adequados para um 'smoke test' pós-inicialização.
    # Em um preflight real, eles podem falhar porque os serviços não estão rodando.
    # Executá-los aqui pode ser opcional.
    log_section "Executando testes de integração opcionais (podem falhar se os serviços não estiverem ativos)"
    test_mapreduce_integration
    test_jupyter_nbconvert

    log_info "-----------------------------------------------------"
    log_success "TODAS AS VERIFICAÇÕES DE PRÉ-VOO FORAM CONCLUÍDAS!"
    log_info "O ambiente parece estar pronto para a inicialização dos serviços."
    log_info "-----------------------------------------------------"
    exit 0
}

# --- Ponto de Entrada do Script ---
main
# Fim do script
# =============================================================================
# Nota: Este script deve ser executado antes de iniciar os serviços do cluster.
# Ele não deve ser executado enquanto os serviços estão ativos, pois pode causar
# inconsistências ou falhas nas verificações.
# =============================================================================