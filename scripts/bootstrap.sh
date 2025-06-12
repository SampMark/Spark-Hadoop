#!/usr/bin/env bash
# =============================================================================
# Script de Bootstrap para Contêineres Hadoop/Spark v2.1
#
# Descrição:
#   Executado pelo entrypoint, este script é o "maestro" de cada contêiner.
#   Ele realiza a configuração final específica do nó (MASTER ou WORKER) e
#   entrega a execução para o processo principal do serviço, garantindo
#   um gerenciamento de processos e sinais adequado.
#
# Fluxo de Execução:
#   1. Define configurações seguras de shell e tratamento de interrupções.
#   2. Valida os argumentos recebidos (MASTER/WORKER).
#   3. Executa as verificações de pré-voo (preflight_check.sh).
#   4. Realiza configurações específicas do nó (senha, arquivo 'workers').
#   5. Inicia o serviço SSH.
#   6. Transfere a execução (via 'exec') para o processo de longa duração
#      apropriado para o tipo de nó, garantindo o desligamento gracioso.
#
# =============================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
set -euo pipefail
trap 'log_error "Script de bootstrap interrompido inesperadamente."; exit 1' INT TERM

# --- Funções de Logging (Padronizadas) ---
readonly COLOR_GREEN='\033[0;32m'; readonly COLOR_RED='\033[0;31m'; readonly COLOR_YELLOW='\033[0;33m'; readonly COLOR_RESET='\033[0m'
log_info() { printf "%b[INFO]%b %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$1"; }
log_error() { printf "%b[ERROR]%b %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$1"; exit 1; }
# CORREÇÃO: Adicionada a função log_success para melhor feedback visual.
log_success() { printf "%b[SUCCESS]%b %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$1"; }


# --- Função Principal ---
main() {
    log_info "Iniciando bootstrap do contêiner..."

    # Validação de Argumentos
    if [ -z "${1:-}" ]; then
        log_error "Argumento do tipo de nó (MASTER/WORKER) não fornecido."
    fi
    local node_type; node_type=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    log_info "Tipo de nó configurado: ${YELLOW_COLOR}${node_type}${COLOR_RESET}"

    # Validação de Variáveis de Ambiente Essenciais
    : "${MY_USERNAME:?A variável MY_USERNAME não está definida.}"
    : "${HADOOP_CONF_DIR:?A variável HADOOP_CONF_DIR não está definida.}"
    : "${NUM_WORKER_NODES:?A variável NUM_WORKER_NODES não está definida.}"
    : "${STACK_NAME:?A variável STACK_NAME não está definida.}"

    # Executa as verificações de pré-voo antes de qualquer outra ação.
    log_info "Executando verificações de pré-voo (preflight_check.sh)..."
    if ! /home/"${MY_USERNAME}"/scripts/preflight_check.sh --skip-integration; then
        log_error "As verificações de pré-voo falharam. Abortando o bootstrap."
    fi
    log_success "Verificações de pré-voo concluídas com sucesso."

    # Execução das tarefas de configuração
    configure_password
    update_workers_file
    start_ssh_service

    # Lógica de inicialização baseada no tipo de nó
    case "${node_type}" in
        MASTER)
            start_master_services
            ;;
        WORKER)
            start_worker_services
            ;;
        *)
            log_error "Tipo de nó inválido: '${node_type}'. Deve ser 'MASTER' ou 'WORKER'."
            ;;
    esac
}

# --- Funções de Configuração ---

configure_password() {
    if [ ! -f "${MY_SECRETS_FILE:-}" ]; then
        log_warn "Arquivo de segredo não definido ou não encontrado. A senha do usuário não será alterada."
        return
    fi
    log_info "Configurando senha para o usuário '${MY_USERNAME}'..."
    if echo "${MY_USERNAME}:$(cat "${MY_SECRETS_FILE}")" | chpasswd; then
        log_success "Senha para o usuário '${MY_USERNAME}' configurada."
    else
        # Não usamos log_error aqui para não parar o script, mas avisamos o usuário.
        log_warn "Falha ao definir a senha para '${MY_USERNAME}'. Verifique as permissões."
    fi
}

update_workers_file() {
    local workers_file="${HADOOP_CONF_DIR}/workers"
    log_info "Atualizando arquivo de workers em '${workers_file}'..."
    # Limpa o arquivo e o recria com os hostnames dos workers.
    >"${workers_file}"
    for i in $(seq 1 "${NUM_WORKER_NODES}"); do
        echo "${STACK_NAME}-worker-${i}" >> "${workers_file}"
    done
    log_info "Conteúdo do arquivo de workers:"
    cat "${workers_file}"
    log_success "Arquivo de workers atualizado com sucesso."
}

start_ssh_service() {
    log_info "Iniciando o serviço SSH..."
    if ! service ssh start; then
        log_error "Falha ao iniciar o serviço SSH. Verifique os logs do sistema."
    fi
    log_success "Serviço SSH iniciado com sucesso."
}

# --- Funções de Inicialização de Serviços ---

start_master_services() {
    log_info "Nó MASTER detectado. Entregando controle ao script de serviços..."
    local services_script="/home/${MY_USERNAME}/scripts/services.sh"
    if [ ! -x "${services_script}" ]; then
        log_error "Script de serviços '${services_script}' não encontrado ou não executável."
    fi
    # 'exec' substitui o processo do bootstrap, tornando o 'services.sh' o PID 1.
    exec gosu "${MY_USERNAME}" bash "${services_script}" start
}

start_worker_services() {
    log_info "Nó WORKER detectado. Iniciando SSH em modo foreground para aguardar conexões..."
    # O daemon SSH se torna o processo principal do contêiner, aguardando conexões do master.
    exec /usr/sbin/sshd -D -e
}

# --- Ponto de Entrada do Script ---
# CORREÇÃO: Esta construção garante que a função 'main' seja chamada apenas
# quando o script é executado diretamente, e não quando ele é "sourced" (importado) por outro script.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# =============================================================================
# Fim do script de bootstrap.
# =============================================================================