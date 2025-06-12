#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script de Gerenciamento de Serviços Hadoop/Spark
#
# Descrição:
#   Gerencia o ciclo de vida (iniciar, parar, status) dos serviços do cluster.
#   É invocado pelo 'bootstrap.sh' e orquestra os daemons principais.
#   Gera relatórios de status e logs para HDFS e YARN.
#
# Requisitos:
#   - Variáveis de ambiente definidas corretamente (HOME, HADOOP_HOME, SPARK_HOME, etc.).
#   - Permissões de execução para o usuário configurado.
#   - Dependências de software instaladas (Hadoop, Spark, Jupyter Lab).
#   - Configuração de cores para logs (opcional, mas recomendado).
#   - Configuração de segurança do shell para evitar erros silenciosos.
#   - Uso de 'set -euo pipefail' para garantir que erros sejam tratados corretamente.
#   - Uso de 'trap' para capturar sinais de interrupção e terminação.
#   - Uso de funções de logging padronizadas para consistência.
#   - Uso de funções genéricas para iniciar/gerenciar daemons, evitando repetição de código.
#   - Uso de funções específicas para cada serviço, mantendo a modularidade.
#   - Uso de funções de status e relatórios para monitoramento do cluster.
#   - Uso de variáveis de ambiente para configuração dinâmica (ex: JUPYTER_PORT, JUPYTER_ROOT_DIR).
#
# Autor: Marcus V D Sampaio/Organização: IFRN] - Baseado no script original de Carlos M D Viegas
# Versão: 1.1
# Data: 2024-06-12
#
#==========================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
# -e: exit on error, -u: unset vars are errors, -o pipefail: pipelines fail on first error
set -euo pipefail
trap 'log_error "Script de serviços interrompido inesperadamente."; exit 1' INT TERM

# --- Funções de Logging (Autossuficientes) ---
# CORREÇÃO: Funções de log definidas localmente para evitar dependências externas.
readonly COLOR_GREEN='\033[0;32m'; readonly COLOR_RED='\033[0;31m'; readonly COLOR_YELLOW='\033[0;33m'; readonly RESET_COLORS='\033[0m'
log_info() { printf "%b[INFO]%b %s\n" "${COLOR_YELLOW}" "${RESET_COLORS}" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "${COLOR_YELLOW}" "${RESET_COLORS}" "$1"; }
log_error() { printf "%b[ERROR]%b %s\n" "${COLOR_RED}" "${RESET_COLORS}" "$1"; return 1; }
log_success() { printf "%b[SUCCESS]%b %s\n" "${COLOR_GREEN}" "${RESET_COLORS}" "$1"; }

# --- Validação e Definição de Constantes e Variáveis ---
# CORREÇÃO: Valida todas as variáveis essenciais no início.
: "${HOME:?Variável HOME não definida.}"
: "${HADOOP_HOME:?Variável HADOOP_HOME não definida.}"
: "${SPARK_HOME:?Variável SPARK_HOME não definida.}"
: "${HADOOP_CONF_DIR:?Variável HADOOP_CONF_DIR não definida.}"
: "${JAVA_HOME:?Variável JAVA_HOME não definida.}"
: "${HDFS_NAMENODE_USER:?Variável HDFS_NAMENODE_USER não definida.}"
: "${JUPYTER_ROOT_DIR:=${HOME}/myfiles}" # Define padrão se não existir
# CORREÇÃO: Variáveis de porta declaradas para configuração centralizada.
: "${HDFS_UI_PORT:=9870}"
: "${YARN_UI_PORT:=8088}"
: "${SPARK_HISTORY_UI_PORT:=18080}"
: "${JUPYTER_PORT:=8888}"

# CORREÇÃO: Definição explícita do diretório de logs do Spark no HDFS.
readonly SPARK_EVENT_LOG_DIR_HDFS="/spark-logs"
# CORREÇÃO: Define o diretório de log local do Spark.
readonly SPARK_DAEMON_LOG_DIR="${SPARK_HOME}/logs"
# CORREÇÃO: Unifica os padrões de processo para fácil manutenção.
readonly NN_PATTERN='org.apache.hadoop.hdfs.server.namenode.NameNode'
readonly RM_PATTERN='org.apache.hadoop.yarn.server.resourcemanager.ResourceManager'
readonly MR_HISTORY_PATTERN='org.apache.hadoop.mapreduce.v2.hs.JobHistoryServer'
readonly SPARK_HISTORY_PATTERN='org.apache.spark.deploy.history.HistoryServer'
readonly JUPYTER_PATTERN='jupyter-lab'
readonly SPARK_CONNECT_PATTERN='org.apache.spark.sql.connect.service.SparkConnectServer'

# --- Função de Orquestração Principal ---
main() {
    if [ $# -eq 0 ]; then
        show_usage; exit 1;
    fi
    local action="${1,,}"; local service="${2:-all}"
    case "${action}" in
        start) start_service "${service}";;
        stop) stop_service "${service}";;
        status) status_all_services;;
        report) generate_full_report;;
        *) log_error "Ação desconhecida: '${action}'"; show_usage;;
    esac
}

# --- Funções de Controle de Serviços (start/stop) ---

start_service() {
    local service="${1,,}"
    log_info "Tentando iniciar o serviço: ${service}"
    case "${service}" in
        hdfs) start_hdfs;;
        yarn) start_yarn;;
        mapred-history) start_mapred_history;;
        spark-history) start_spark_history;;
        jupyterlab) start_jupyterlab;;
        spark-connect) start_spark_connect;;
        all) start_all_services;;
        *) log_error "Serviço desconhecido para start: '${service}'";;
    esac
}

stop_service() {
    local service="${1,,}"
    log_info "Tentando parar o serviço: ${service}"
    case "${service}" in
        hdfs) stop_hdfs;;
        yarn) stop_yarn;;
        mapred-history) stop_mapred_history;;
        spark-history) stop_spark_history;;
        jupyterlab) stop_jupyterlab;;
        spark-connect) stop_spark_connect;;
        all) stop_all_services;;
        *) log_error "Serviço desconhecido para stop: '${service}'";;
    esac
}

start_all_services() {
    log_info "Inicializando todos os serviços do cluster em sequência..."
    start_hdfs || log_error "Falha crítica ao iniciar HDFS. Abortando."
    start_yarn || log_warn "Falha ao iniciar YARN."
    start_mapred_history || log_warn "Falha ao iniciar MapReduce History Server."
    start_spark_history || log_warn "Falha ao iniciar Spark History Server."
    start_jupyterlab || log_warn "Falha ao iniciar JupyterLab."
    start_spark_connect || log_warn "Falha ao iniciar Spark Connect Server."
    log_info "Verificação final de status..."
    sleep 2; status_all_services; generate_full_report
    log_success "Sequência de inicialização concluída."
}

stop_all_services() {
    log_info "Parando todos os serviços do cluster..."
    # Ordem inversa de dependência
    stop_spark_connect; stop_jupyterlab; stop_spark_history; stop_mapred_history; stop_yarn; stop_hdfs
    log_info "Todos os serviços foram instruídos a parar."
    sleep 1; status_all_services
}

# --- Funções Específicas de Cada Serviço ---

# CORREÇÃO: Função genérica para iniciar daemons, eliminando repetição de código.
run_daemon() {
    local name="$1"; local start_cmd="$2"; local stop_cmd="$3"; local pattern="$4"
    log_info "Gerenciando daemon: ${name}"
    # Para se o serviço já estiver rodando
    if pgrep -f "${pattern}" > /dev/null; then
        log_info "${name} já está em execução. Parando para um reinício limpo..."
        eval "${stop_cmd}" >/dev/null 2>&1 || true
        sleep 2
    fi
    # Inicia o serviço
    log_info "Iniciando ${name}..."
    if ! eval "${start_cmd}"; then
        log_error "Comando para iniciar ${name} falhou."
        return 1
    fi
    sleep 3
    # Verifica se iniciou
    if pgrep -f "${pattern}" > /dev/null; then
        log_success "${name} iniciado com sucesso."
    else
        log_error "Falha ao iniciar ${name} (processo não encontrado)."
        return 1
    fi
}

start_hdfs() {
    log_info "Verificando se o HDFS NameNode precisa ser formatado..."
    if [ ! -d "${HADOOP_DATA_DIR:-/tmp/hadoop-data}/namenode/current" ]; then
        log_info "Formatando HDFS NameNode..."
        "${HADOOP_HOME}/bin/hdfs" namenode -format -nonInteractive || log_error "Falha ao formatar o HDFS NameNode."
        log_success "HDFS NameNode formatado com sucesso."
    else
        log_info "HDFS já formatado. Pulando formatação."
    fi
    run_daemon "HDFS" "\"${HADOOP_HOME}/sbin/start-dfs.sh\"" "\"${HADOOP_HOME}/sbin/stop-dfs.sh\"" "${NN_PATTERN}" || return 1
    log_info "Verificando e configurando diretório de logs do Spark no HDFS..."
    if ! "${HADOOP_HOME}/bin/hdfs" dfs -test -d "${SPARK_EVENT_LOG_DIR_HDFS}"; then
        log_info "Criando diretório ${SPARK_EVENT_LOG_DIR_HDFS} no HDFS..."
        "${HADOOP_HOME}/bin/hdfs" dfs -mkdir -p "${SPARK_EVENT_LOG_DIR_HDFS}"
        "${HADOOP_HOME}/bin/hdfs" dfs -chmod 1777 "${SPARK_EVENT_LOG_DIR_HDFS}"
        log_success "Diretório de logs do Spark criado e configurado no HDFS."
    else
        log_info "Diretório de logs do Spark já existe no HDFS."
    fi
}

stop_hdfs() { log_info "Parando HDFS..."; "${HADOOP_HOME}/sbin/stop-dfs.sh" >/dev/null 2>&1 || true; }

start_yarn() {
    run_daemon "YARN" \
        "\"${HADOOP_HOME}/sbin/start-yarn.sh\"" \
        "\"${HADOOP_HOME}/sbin/stop-yarn.sh\"" \
        "${RM_PATTERN}"
}
stop_yarn() { log_info "Parando YARN..."; "${HADOOP_HOME}/sbin/stop-yarn.sh" >/dev/null 2>&1 || true; }

start_mapred_history() {
    run_daemon "MapReduce History Server" \
        "\"${HADOOP_HOME}/bin/mapred\" --daemon start historyserver" \
        "\"${HADOOP_HOME}/bin/mapred\" --daemon stop historyserver" \
        "${MR_HISTORY_PATTERN}"
}
stop_mapred_history() { log_info "Parando MapReduce History..."; "${HADOOP_HOME}/bin/mapred" --daemon stop historyserver >/dev/null 2>&1 || true; }

start_spark_history() {
    # CORREÇÃO: Garante que o diretório de log LOCAL exista antes de iniciar o daemon.
    log_info "Preparando diretório de log local para o Spark History Server..."
    mkdir -p "${SPARK_DAEMON_LOG_DIR}"
    # A permissão do diretório pai (SPARK_HOME) já deve estar correta, mas isso garante.
    chown -R "${HDFS_NAMENODE_USER}:${HDFS_NAMENODE_USER}" "${SPARK_DAEMON_LOG_DIR}" || log_warn "Não foi possível ajustar permissões em ${SPARK_DAEMON_LOG_DIR}."
    
    run_daemon "Spark History Server" \
        "\"${SPARK_HOME}/sbin/start-history-server.sh\"" \
        "\"${SPARK_HOME}/sbin/stop-history-server.sh\"" \
        "${SPARK_HISTORY_PATTERN}"
}
stop_spark_history() { log_info "Parando Spark History..."; "${SPARK_HOME}/sbin/stop-history-server.sh" >/dev/null 2>&1 || true; }

start_jupyterlab() {
    log_info "Iniciando Jupyter Lab em background..."
    # Usa nohup para desanexar o processo.
    nohup jupyter lab \
        --ServerApp.ip="0.0.0.0" \
        --ServerApp.port="${JUPYTER_PORT}" \
        --ServerApp.open_browser=False \
        --ServerApp.root_dir="${JUPYTER_ROOT_DIR}" \
        --ServerApp.token='' --ServerApp.password='' \
        --ServerApp.allow_root=True > "${SPARK_HOME}/logs/jupyterlab.log" 2>&1 &
    sleep 3
    if pgrep -f "${JUPYTER_PATTERN}" >/dev/null; then log_success "Jupyter Lab iniciado."; else log_error "Falha ao iniciar Jupyter Lab."; fi
}
stop_jupyterlab() { log_info "Parando Jupyter Lab..."; pkill -f "${JUPYTER_PATTERN}" || true; }

start_spark_connect() {
    if [[ "${SPARK_CONNECT_SERVER:-disable}" != "enable" ]]; then
        log_info "Spark Connect Server está desabilitado. Pulando."
        return
    fi
    run_daemon "Spark Connect Server" \
        "\"${SPARK_HOME}/sbin/start-connect-server.sh\" --packages org.apache.spark:spark-connect_2.12:${SPARK_VERSION}" \
        "\"${SPARK_HOME}/sbin/stop-connect-server.sh\"" \
        "${SPARK_CONNECT_PATTERN}"
}
stop_spark_connect() { if [[ "${SPARK_CONNECT_SERVER:-disable}" == "enable" ]]; then log_info "Parando Spark Connect..."; "${SPARK_HOME}/sbin/stop-connect-server.sh" >/dev/null 2>&1 || true; fi; }


# --- Funções de Status e Relatório ---

_check_service_status_internal() {
    local name="$1"; local pattern="$2"
    printf "    %-25s : " "${name}"
    if pgrep -f "${pattern}" > /dev/null; then
        printf "%bEM EXECUÇÃO%b\n" "${COLOR_GREEN}" "${RESET_COLORS}"
    else
        printf "%bPARADO%b\n" "${COLOR_RED}" "${RESET_COLORS}"
    fi
}

status_all_services() {
    log_info "Verificando status de todos os serviços:"
    _check_service_status_internal "HDFS NameNode" "${NN_PATTERN}"
    _check_service_status_internal "YARN ResourceManager" "${RM_PATTERN}"
    _check_service_status_internal "MR History Server" "${MR_HISTORY_PATTERN}"
    _check_service_status_internal "Spark History Server" "${SPARK_HISTORY_PATTERN}"
    _check_service_status_internal "Jupyter Lab" "${JUPYTER_PATTERN}"
    _check_service_status_internal "Spark Connect Server" "${SPARK_CONNECT_PATTERN}"
}

generate_full_report() {
    log_info "--- INÍCIO DO RELATÓRIO COMPLETO DO CLUSTER ---"
    "${HADOOP_HOME}/bin/hdfs" dfsadmin -report || log_warn "Falha ao gerar relatório HDFS."
    printf "\n"
    "${HADOOP_HOME}/bin/yarn" node -list || log_warn "Falha ao gerar relatório YARN."
    log_info "--- FIM DO RELATÓRIO COMPLETO DO CLUSTER ---"
}

show_usage() {
    printf "Uso: $(basename "$0") [ação] [serviço]\n"
    printf "Ações: start, stop, status, report\n"
    printf "Serviços: hdfs, yarn, mapred-history, spark-history, jupyterlab, spark-connect, all\n"
}

# --- Ponto de Entrada do Script ---
main "$@"
# -----------------------------------------------------------------------------
# Fim do script de gerenciamento de serviços.
# -----------------------------------------------------------------------------