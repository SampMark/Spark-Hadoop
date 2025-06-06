#!/usr/bin/env bash
# =============================================================================
# Smoke Test Script para Cluster Hadoop/Spark
#
# Descrição:
#   Este script executa uma série de testes de verificação ("smoke tests")
#   para garantir que os principais componentes do cluster (HDFS, YARN,
#   MapReduce, Spark) estão funcionando corretamente após a implantação.
#
#   Testes Realizados:
#   1. Verifica se a UI Web do HDFS NameNode está acessível.
#   2. Verifica se o número esperado de NodeManagers está ativo e reportando
#      ao YARN ResourceManager.
#   3. Executa um job MapReduce WordCount para testar HDFS I/O e a
#      execução de jobs MapReduce.
#   4. Executa um notebook PySpark simples via `jupyter nbconvert` para
#      testar a integração do Spark com YARN e Jupyter.
#
# Como Usar:
#   Este script é projetado para ser executado dentro do contêiner 'spark-master'
#   ou em um ambiente onde os comandos 'hdfs', 'yarn', 'hadoop', 'jupyter'
#   estejam configurados e o cluster esteja acessível.
#
#   Exemplo de execução via Docker Compose:
#   docker compose exec spark-master bash /path/to/smoke_test.sh
#
# Documentação Adicional: Seu Assistente AI
# =============================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
# -e: Sai imediatamente se um comando falhar.
# -u: Trata variáveis não definidas como um erro.
# -o pipefail: Garante que o status de saída de um pipeline seja o do último comando que falhou.
set -euo pipefail

# --- Funções de Logging e Cores ---
# Adiciona cores aos logs para melhor legibilidade.
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_RESET='\033[0m'

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

# --- Variáveis de Configuração ---
# Carrega variáveis do .env se existir, mas define padrões para robustez.
if [[ -f ".env" ]]; then
    # set -a exporta todas as variáveis do .env
    set -a
    source .env
    set +a
fi

# Variáveis com valores padrão, que podem ser sobrescritos pelo .env ou pelo ambiente
readonly HEALTHCHECK_TIMEOUT="${HEALTHCHECK_TIMEOUT:-60}"
readonly HOST_HDFS_UI_PORT="${HOST_HDFS_UI_PORT:-9870}"
readonly NUM_WORKER_NODES="${NUM_WORKER_NODES:-2}"
# Define um caminho padrão para o notebook de teste, que pode ser montado via volume Docker.
readonly PYSPARK_TEST_NOTEBOOK="${PYSPARK_TEST_NOTEBOOK:-/opt/tests/hello-pyspark.ipynb}"

# --- Funções de Teste Modulares ---

# Teste 1: Verifica a disponibilidade da UI Web do HDFS NameNode.
test_hdfs_ui_availability() {
    log_info "Iniciando Teste 1: Verificação da UI do HDFS NameNode..."
    local host="localhost"
    local port="${HOST_HDFS_UI_PORT}"
    local url="http://${host}:${port}"

    log_info "Aguardando HDFS UI em ${url} por até ${HEALTHCHECK_TIMEOUT} segundos..."

    for ((i=1; i<=HEALTHCHECK_TIMEOUT; i++)); do
        # Usa curl com --fail para retornar um código de erro em falhas HTTP (ex: 404)
        if curl --silent --fail "${url}" >/dev/null 2>&1; then
            log_success "HDFS UI está ativa e respondendo em ${url}."
            return 0
        fi
        printf "."
        sleep 1
    done

    # Se o loop terminar sem sucesso
    echo # Nova linha
    log_error "HDFS UI não ficou disponível em ${url} após ${HEALTHCHECK_TIMEOUT} segundos."
}

# Teste 2: Verifica se todos os NodeManagers esperados estão ativos no YARN.
test_yarn_nodemanager_count() {
    log_info "Iniciando Teste 2: Verificação do número de NodeManagers no YARN..."
    local expected_nodes="${NUM_WORKER_NODES}"
    local active_nodes=0

    log_info "Esperando que ${expected_nodes} NodeManager(s) fiquem no estado 'RUNNING'..."

    for ((i=1; i<=HEALTHCHECK_TIMEOUT; i++)); do
        # O comando `yarn node -list` pode falhar se o RM não estiver pronto, por isso o `|| true`
        active_nodes=$(yarn node -list 2>/dev/null | grep -c "RUNNING" || true)
        if [ "${active_nodes}" -eq "${expected_nodes}" ]; then
            log_success "${active_nodes} de ${expected_nodes} NodeManagers estão ativos."
            return 0
        fi
        log_info "Atualmente ${active_nodes}/${expected_nodes} NodeManagers ativos. Tentando novamente em 5s..."
        sleep 5
    done

    # Se o loop terminar sem sucesso
    log_error "Número incorreto de NodeManagers. Ativos: ${active_nodes}, Esperado: ${expected_nodes}."
}

# Teste 3: Executa um job MapReduce WordCount para validar a pipeline de dados.
test_mapreduce_wordcount() {
    log_info "Iniciando Teste 3: Execução de job MapReduce WordCount..."
    local hdfs_input_dir="/tmp/smoke_test_input"
    local hdfs_output_dir="/tmp/smoke_test_output"
    # Usa mktemp para criar um arquivo temporário seguro para a entrada
    local local_input_file
    local_input_file=$(mktemp)

    # Função de limpeza para remover artefatos do teste
    cleanup() {
        log_info "Limpando artefatos do teste WordCount..."
        hdfs dfs -rm -r -f "${hdfs_input_dir}" "${hdfs_output_dir}" >/dev/null 2>&1 || true
        rm -f "${local_input_file}"
    }
    # Registra a função de limpeza para ser executada na saída do script (em caso de erro ou sucesso)
    trap cleanup EXIT

    log_info "Preparando dados de entrada no HDFS..."
    echo "hadoop spark hadoop" > "${local_input_file}"
    hdfs dfs -mkdir -p "${hdfs_input_dir}"
    hdfs dfs -put -f "${local_input_file}" "${hdfs_input_dir}/"

    log_info "Executando o job WordCount..."
    # O comando hadoop jar pode ser verboso, redirecionar stderr para /dev/null para um log mais limpo
    if ! hadoop jar "${HADOOP_HOME}/share/hadoop/mapreduce/hadoop-mapreduce-examples"*.jar wordcount \
      "${hdfs_input_dir}" "${hdfs_output_dir}" >/dev/null 2>&1; then
        log_error "Execução do job MapReduce WordCount falhou."
    fi

    log_info "Verificando o resultado do WordCount..."
    local result
    result=$(hdfs dfs -cat "${hdfs_output_dir}/part-r-00000")
    local expected_output_hadoop="hadoop\t2"
    local expected_output_spark="spark\t1"

    if [[ "${result}" == *"${expected_output_hadoop}"* && "${result}" == *"${expected_output_spark}"* ]]; then
        log_success "Resultado do WordCount está correto."
        printf "       Resultado obtido:\n%s\n" "${result}"
    else
        log_error "Resultado do WordCount inesperado. Obtido: '${result}'"
    fi
}

# Teste 4: Executa um notebook PySpark para validar a integração do Spark com Jupyter.
test_pyspark_notebook() {
    log_info "Iniciando Teste 4: Execução de notebook PySpark..."

    if [ ! -f "${PYSPARK_TEST_NOTEBOOK}" ]; then
        log_error "Notebook de teste não encontrado em '${PYSPARK_TEST_NOTEBOOK}'. Verifique o caminho ou o volume montado."
    fi

    log_info "Executando notebook '${PYSPARK_TEST_NOTEBOOK}' com nbconvert..."
    # --ExecutePreprocessor.timeout define um timeout para a execução do notebook
    # --stdout redireciona a saída do notebook para stdout em vez de criar um arquivo .nbconvert.ipynb
    if ! jupyter nbconvert --to notebook --execute "${PYSPARK_TEST_NOTEBOOK}" \
      --ExecutePreprocessor.timeout=180 --stdout >/dev/null; then
        log_error "Execução do notebook PySpark falhou. Verifique os logs do Jupyter e da aplicação Spark."
    fi

    log_success "Notebook PySpark executado com sucesso."
}


# --- Função Principal de Execução ---
main() {
    log_info "================================================="
    log_info "   INICIANDO SMOKE TESTS DO CLUSTER HADOOP/SPARK   "
    log_info "================================================="
    
    # Executa cada teste em sequência. O script sairá no primeiro erro devido ao 'set -e'.
    test_hdfs_ui_availability
    test_yarn_nodemanager_count
    test_mapreduce_wordcount
    test_pyspark_notebook

    log_info "-------------------------------------------------"
    log_success "TODOS OS SMOKE TESTS FORAM CONCLUÍDOS COM SUCESSO!"
    log_info "-------------------------------------------------"
    exit 0
}

# --- Ponto de Entrada do Script ---
# Chama a função main com todos os argumentos passados para o script.
main "$@"

# --- Fim do Script ---
# =============================================================================
