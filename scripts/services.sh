#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script de Gerenciamento de Serviços Hadoop/Spark
#
# Descrição:
#   Este script gerencia o ciclo de vida (iniciar, parar, status, relatório)
#   dos serviços individuais do cluster Hadoop, Spark e JupyterLab.
#   É invocado pelo 'bootstrap.sh' no nó master.
#
# Autor: Marcus V D Sampaio/Organização: IFRN] - Baseado no script original de Carlos M D Viegas
# Versão: 1.1
# Data: 2024-06-05
#
# Inspiração Original:
#   (C) 2022-2025 CARLOS M D VIEGAS
#   https://github.com/cmdviegas
#   DEPARTAMENTO DE ENGENHARIA DE COMPUTACAO E AUTOMACAO
#   UNIVERSIDADE FEDERAL DO RIO GRANDE DO NORTE, NATAL/RN
#
# Uso:
#   services.sh [ACAO] [SERVICO]
#
# Ações:
#   start         - Inicia um serviço ou todos os serviços.
#   stop          - Para um serviço ou todos os serviços.
#   status        - Mostra o status de todos os serviços.
#   report        - Gera relatórios para HDFS e YARN.
#
# Serviços:
#   hdfs          - Serviço HDFS (NameNode, DataNodes).
#   yarn          - Serviço YARN (ResourceManager, NodeManagers).
#   mapred-history- Serviço MapReduce Job History Server.
#   spark-history - Serviço Spark History Server.
#   jupyterlab    - Serviço Jupyter Lab.
#   spark-connect - Serviço Spark Connect Server (se habilitado).
#   all           - Refere-se a todos os serviços acima para as ações start/stop.
#
# Variáveis de Ambiente Esperadas:
#   HOME: Diretório home do usuário (ex: /home/myuser).
#   HADOOP_HOME: Diretório raiz da instalação do Hadoop.
#   SPARK_HOME: Diretório raiz da instalação do Spark.
#   HADOOP_CONF_DIR: Diretório de configuração do Hadoop.
#   JAVA_HOME: Diretório raiz da instalação do Java.
#   HDFS_NAMENODE_USER: Nome do usuário para diretórios HDFS (ex: myuser).
#   SPARK_CONNECT_SERVER: "enable" ou "disable" para o Spark Connect.
#   SPARK_VERSION: Versão do Spark (usada pelo Spark Connect).
#   Cores (INFO, ERROR, YELLOW_COLOR, etc.) são esperadas do ambiente ou definidas aqui.
# -----------------------------------------------------------------------------

# --- Configuração de Segurança e Comportamento do Shell ---
set -euo pipefail # -e: exit on error, -u: unset vars are errors, -o pipefail: pipelines fail on first error

# --- Definição de Cores e Funções de Logging (se não herdadas do bootstrap.sh) ---
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
YELLOW_COLOR='\033[0;33m'
LIGHTBLUE_COLOR='\033[0;36m'
RESET_COLORS='\033[0m'

INFO_PREFIX="[${GREEN_COLOR}INFO${RESET_COLORS}]"
ERROR_PREFIX="[${RED_COLOR}ERROR${RESET_COLORS}]"
WARN_PREFIX="[${YELLOW_COLOR}WARN${RESET_COLORS}]"

log_info() { printf "%b %s\n" "${INFO_PREFIX}" "$1"; }
log_warn() { printf "%b %s\n" "${WARN_PREFIX}" "$1"; }
log_error() { printf "%b %s\n" "${ERROR_PREFIX}" "$1"; return 1; } # Retorna 1 para indicar falha
# Para erros fatais que devem parar o script, `exit 1` pode ser usado diretamente ou
# confiar no `set -e`. O `return 1` é útil para funções que podem falhar sem parar tudo.

# --- Carregamento de Variáveis de Ambiente ---
# Tenta carregar o .env do diretório HOME do usuário que executa este script.
# Este script é executado como 'myuser', não root.
ENV_FILE="${HOME}/.env"
if [ -f "${ENV_FILE}" ]; then
    log_info "Carregando variáveis de ambiente de ${ENV_FILE}..."
    # shellcheck source=/dev/null
    . "${ENV_FILE}"
else
    log_warn "Arquivo ${ENV_FILE} não encontrado. Usando variáveis de ambiente existentes."
fi

# --- Validação de Variáveis de Ambiente Essenciais ---
: "${HOME:?Variável HOME não definida.}"
: "${HADOOP_HOME:?Variável HADOOP_HOME não definida.}"
: "${SPARK_HOME:?Variável SPARK_HOME não definida.}"
: "${HADOOP_CONF_DIR:?Variável HADOOP_CONF_DIR não definida.}"
: "${JAVA_HOME:?Variável JAVA_HOME não definida.}"
: "${HDFS_NAMENODE_USER:?Variável HDFS_NAMENODE_USER não definida.}"
# SPARK_CONNECT_SERVER pode ser opcional ou ter um default
SPARK_CONNECT_SERVER="${SPARK_CONNECT_SERVER:-disable}" # Default para 'disable' se não definida

# --- Estado Global de Boot ---
# Usado para rastrear se a sequência de 'start all' foi bem-sucedida.
# true se todos os serviços críticos iniciaram, false caso contrário.
OVERALL_BOOT_STATUS="true" # Assume sucesso inicialmente, funções definem para false em erro

# --- Configuração Dinâmica do JAVA_HOME no hadoop-env.sh ---
# Garante que o hadoop-env.sh use o JAVA_HOME correto definido no ambiente.
setup_java_home() {
    local hadoop_env_file="${HADOOP_CONF_DIR}/hadoop-env.sh"
    local temp_hadoop_env_file="${hadoop_env_file}.tmp_$$" # Arquivo temporário com PID
    local current_java_home_in_file

    log_info "Verificando configuração do JAVA_HOME em ${hadoop_env_file}..."

    if [ ! -f "${hadoop_env_file}" ]; then
        log_error "Arquivo ${hadoop_env_file} não encontrado."
        OVERALL_BOOT_STATUS="false"
        return 1 # Indica falha na função
    fi

    # Extrai o JAVA_HOME atual do arquivo, lidando com aspas e espaços.
    # Usar awk para uma extração mais robusta.
    current_java_home_in_file=$(awk -F'=' '/^export JAVA_HOME=/ {print $2}' "${hadoop_env_file}" | tr -d '"' | xargs)

    if [ "${current_java_home_in_file}" = "${JAVA_HOME}" ]; then
        log_info "JAVA_HOME já está corretamente configurado em ${hadoop_env_file}: ${JAVA_HOME}"
        return 0
    fi

    log_info "Atualizando JAVA_HOME em ${hadoop_env_file} para: ${JAVA_HOME}"
    # Usar sed para substituir a linha. A flag -i (in-place) pode não ser portável; usar arquivo temporário.
    # Escapar barras no JAVA_HOME se ele puder conter (improvável para caminhos padrão).
    local escaped_java_home
    escaped_java_home=$(echo "${JAVA_HOME}" | sed 's/\//\\\//g') # Escapa barras para o sed

    if sed "s|^export JAVA_HOME=.*|export JAVA_HOME=\"${escaped_java_home}\"|" "${hadoop_env_file}" > "${temp_hadoop_env_file}"; then
        if mv "${temp_hadoop_env_file}" "${hadoop_env_file}"; then
            log_info "JAVA_HOME atualizado com sucesso em ${hadoop_env_file}."
            return 0
        else
            log_error "Falha ao mover ${temp_hadoop_env_file} para ${hadoop_env_file}. Permissões?"
            rm -f "${temp_hadoop_env_file}" 2>/dev/null
            OVERALL_BOOT_STATUS="false"
            return 1
        fi
    else
        log_error "Falha ao processar (sed) ${hadoop_env_file}."
        rm -f "${temp_hadoop_env_file}" 2>/dev/null
        OVERALL_BOOT_STATUS="false"
        return 1
    fi
}

# --- Verificação da Conectividade dos Workers ---
# Tenta conectar via SSH a cada worker listado em HADOOP_CONF_DIR/workers.
check_workers_ssh_connectivity() {
    local worker_count=0
    local reachable_workers=0
    local total_workers_expected
    local worker_hostname

    log_info "Verificando conectividade SSH com os nós workers..."
    if [ ! -f "${HADOOP_CONF_DIR}/workers" ]; then
        log_error "Arquivo de workers '${HADOOP_CONF_DIR}/workers' não encontrado."
        OVERALL_BOOT_STATUS="false"
        return 1
    fi

    # Conta o número total de workers esperados
    total_workers_expected=$(grep -cvE '^\s*(#|$)' "${HADOOP_CONF_DIR}/workers")
    if [ "${total_workers_expected}" -eq 0 ]; then
        log_warn "Nenhum worker configurado em '${HADOOP_CONF_DIR}/workers'. Alguns serviços podem não funcionar corretamente."
        # Pode não ser um "erro fatal", dependendo do serviço a ser iniciado.
        return 0 # Permite continuar, mas com aviso.
    fi

    log_info "Esperando ${total_workers_expected} worker(s) conforme listado em ${HADOOP_CONF_DIR}/workers."

    # Loop para ler cada worker do arquivo
    while IFS= read -r worker_hostname || [[ -n "${worker_hostname}" ]]; do
        # Ignora linhas vazias ou comentadas
        if [[ "${worker_hostname}" =~ ^\s*(#|$) ]]; then
            continue
        fi
        worker_count=$((worker_count + 1))
        printf "       Testando conexão com ${YELLOW_COLOR}%s${RESET_COLORS}..." "${worker_hostname}"
        # Tenta SSH com timeout curto. 'StrictHostKeyChecking=no' e 'UserKnownHostsFile=/dev/null'
        # são úteis em ambientes dinâmicos de contêineres para evitar prompts de host key.
        # CUIDADO: Desabilita uma medida de segurança. Use com entendimento do ambiente.
        if ssh -o "ConnectTimeout=2" \
               -o "StrictHostKeyChecking=no" \
               -o "UserKnownHostsFile=/dev/null" \
               "${worker_hostname}" "exit" >/dev/null 2>&1 </dev/null; then
            printf " ${GREEN_COLOR}sucesso${RESET_COLORS}!\n"
            reachable_workers=$((reachable_workers + 1))
        else
            printf " ${RED_COLOR}falha${RESET_COLORS}!\n"
        fi
    done < "${HADOOP_CONF_DIR}/workers"

    if [ "${reachable_workers}" -ge 1 ]; then
        log_info "${GREEN_COLOR}${reachable_workers}${RESET_COLORS} de ${total_workers_expected} worker(s) estão ativos e acessíveis via SSH."
        if [ "${reachable_workers}" -lt "${total_workers_expected}" ]; then
            log_warn "Nem todos os workers configurados estão acessíveis. Verifique os workers que falharam."
        fi
        return 0 # Sucesso parcial ou total
    else
        log_error "Nenhum nó worker está ativo/acessível via SSH. São necessários workers para HDFS e YARN."
        OVERALL_BOOT_STATUS="false"
        return 1 # Falha
    fi
}

# --- Gerenciamento do Serviço HDFS ---
start_hdfs() {
    local namenode_format_status
    local namenode_dir

    log_info "Iniciando serviço HDFS..."

    # 1. Parar HDFS se estiver rodando (para garantir um início limpo)
    # Verificar se o NameNode está rodando antes de tentar parar.
    if pgrep -f 'org.apache.hadoop.hdfs.server.namenode.NameNode' > /dev/null; then
        log_info "NameNode existente encontrado. Tentando parar HDFS antes de iniciar..."
        stop_hdfs # A função stop_hdfs já silencia a saída.
        sleep 3 # Dá tempo para os processos pararem.
    fi

    # 2. Formatar o NameNode (apenas se necessário)
    # O NameNode deve ser formatado na primeira vez ou se os dados estiverem corrompidos/ausentes.
    # Verificar a existência do diretório de dados do NameNode.
    # O caminho é obtido de dfs.namenode.name.dir em hdfs-site.xml.
    # Assumindo que HADOOP_CONF_DIR está no classpath ou hdfs getconf funciona.
    namenode_dir=$(hdfs getconf -confKey dfs.namenode.name.dir 2>/dev/null | awk -F'file://' '{print $2}' | cut -d ',' -f1 | xargs) # Pega o primeiro dir se houver múltiplos

    if [ -z "${namenode_dir}" ]; then
        log_warn "Não foi possível determinar o diretório do NameNode (dfs.namenode.name.dir). Pulando verificação de formatação existente."
        # Continuar com a formatação condicional abaixo que usa a saída do comando.
    fi

    log_info "Verificando se o HDFS NameNode precisa ser formatado..."
    printf "       Diretório do NameNode (dfs.namenode.name.dir): ${YELLOW_COLOR}%s${RESET_COLORS}\n" "${namenode_dir:-N/A}"

    # A formatação interativa pode ser um problema. Usar -nonInteractive.
    # Capturar saída para verificar se já foi formatado.
    # HADOOP_ROOT_LOGGER=ERROR,console suprime logs INFO do Hadoop.
    if [ -d "${namenode_dir}/current" ]; then # Heurística: se 'current' existe, provavelmente já foi formatado
        log_info "Diretório '${namenode_dir}/current' existe. Assumindo que o HDFS já foi formatado. Pulando formatação."
    else
        log_info "Diretório '${namenode_dir}/current' não encontrado. Formatando HDFS NameNode..."
        if HADOOP_ROOT_LOGGER=ERROR,console "${HADOOP_HOME}/bin/hdfs" namenode -format -nonInteractive; then
            log_info "${GREEN_COLOR}HDFS NameNode formatado com sucesso.${RESET_COLORS}"
        else
            log_error "Falha ao formatar o HDFS NameNode. Verifique os logs do Hadoop."
            OVERALL_BOOT_STATUS="false"
            return 1
        fi
    fi

    # 3. Verificar conectividade dos workers ANTES de tentar iniciar o HDFS
    if ! check_workers_ssh_connectivity; then
        log_error "Não é possível iniciar HDFS sem workers acessíveis via SSH."
        OVERALL_BOOT_STATUS="false"
        return 1
    fi

    # 4. Iniciar os daemons do HDFS (NameNode no master, DataNodes nos workers)
    log_info "Iniciando daemons do HDFS (usando start-dfs.sh)..."
    if ! "${HADOOP_HOME}/sbin/start-dfs.sh"; then
        log_error "Falha ao executar start-dfs.sh. Verifique os logs do Hadoop."
        OVERALL_BOOT_STATUS="false"
        return 1
    fi
    sleep 5 # Dar tempo para os daemons iniciarem

    # 5. Verificar se DataNodes estão vivos e criar diretórios HDFS
    # Usar `hdfs dfsadmin -report` para verificar DataNodes.
    if ! hdfs dfsadmin -report | grep -q "Live datanodes ([1-9][0-9]*)"; then
        log_error "HDFS iniciado, mas nenhum DataNode está vivo ou reportando. Verifique os logs dos DataNodes nos workers e a configuração de rede/firewall."
        log_info "Conteúdo do relatório HDFS:"
        hdfs dfsadmin -report || true # Mostrar relatório mesmo que grep falhe
        OVERALL_BOOT_STATUS="false"
        return 1
    fi

    log_info "${GREEN_COLOR}HDFS iniciado com sucesso e DataNodes estão vivos.${RESET_COLORS}"
    log_info "Criando diretórios HDFS padrão (se não existirem)..."
    # Criar diretórios com -p para não falhar se já existirem.
    # As permissões podem precisar ser ajustadas dependendo do usuário.
    # Assumindo que este script (e hdfs dfs) roda como um superusuário HDFS ou o usuário HDFS_NAMENODE_USER.
    hdfs dfs -mkdir -p "/user/${HDFS_NAMENODE_USER}" \
                       "/user/${HDFS_NAMENODE_USER}/hadoopLogs" \
                       "/user/${HDFS_NAMENODE_USER}/sparkLogs" \
                       "/user/${HDFS_NAMENODE_USER}/sparkWarehouse" \
                       "/sparkLibs" \
                       "/tmp" # /tmp é frequentemente necessário
    # Definir permissões para /tmp para ser acessível por todos (comum)
    hdfs dfs -chmod 1777 /tmp || log_warn "Falha ao definir permissões para /tmp no HDFS."

    # Opcional: Copiar JARs do Spark para /sparkLibs no HDFS
    # Isso é útil se o Spark for configurado para usar esses JARs do HDFS.
    log_info "Copiando JARs do Spark para /sparkLibs no HDFS (pode demorar)..."
    if hdfs dfs -put -f "${SPARK_HOME}/jars/"*.jar /sparkLibs/; then # -f para sobrescrever
        log_info "JARs do Spark copiados para /sparkLibs no HDFS."
    else
        log_warn "Falha ao copiar JARs do Spark para /sparkLibs no HDFS. Alguns jobs Spark podem falhar se dependerem disso."
    fi

    printf "       URL da UI do NameNode: http://localhost:${LIGHTBLUE_COLOR}9870${RESET_COLORS}\n"
    printf "       Diretório HDFS do usuário: ${YELLOW_COLOR}$(hdfs getconf -confKey fs.defaultFS)/user/${HDFS_NAMENODE_USER}${RESET_COLORS}\n"
    log_info "Configuração do HDFS finalizada."
    return 0 # Sucesso
}

stop_hdfs() {
    log_info "Parando serviço HDFS (usando stop-dfs.sh)..."
    # Silenciar saída, pois pode ser verboso ou mostrar erros se já parado.
    "${HADOOP_HOME}/sbin/stop-dfs.sh" > /dev/null 2>&1 || log_warn "stop-dfs.sh encontrou problemas (pode ser normal se já parado)."
    log_info "Serviço HDFS parado."
}

# --- Gerenciamento do Serviço YARN ---
start_yarn() {
    log_info "Iniciando serviço YARN..."

    # 1. Parar YARN se estiver rodando
    if pgrep -f 'org.apache.hadoop.yarn.server.resourcemanager.ResourceManager' > /dev/null; then
        log_info "ResourceManager existente encontrado. Tentando parar YARN antes de iniciar..."
        stop_yarn
        sleep 3
    fi

    # 2. Verificar conectividade dos workers
    if ! check_workers_ssh_connectivity; then
        log_error "Não é possível iniciar YARN sem workers acessíveis via SSH."
        OVERALL_BOOT_STATUS="false"
        return 1
    fi

    # 3. Iniciar daemons do YARN (ResourceManager no master, NodeManagers nos workers)
    log_info "Iniciando daemons do YARN (usando start-yarn.sh)..."
    if ! "${HADOOP_HOME}/sbin/start-yarn.sh"; then
        log_error "Falha ao executar start-yarn.sh. Verifique os logs do Hadoop."
        OVERALL_BOOT_STATUS="false"
        return 1
    fi
    sleep 5 # Dar tempo para os daemons iniciarem

    # 4. Verificar se NodeManagers estão ativos
    # yarn node -list pode ser usado, mas precisa que o RM esteja totalmente funcional.
    # Uma verificação simples é ver se o ResourceManager está rodando.
    if ! pgrep -f 'org.apache.hadoop.yarn.server.resourcemanager.ResourceManager' > /dev/null; then
        log_error "Falha ao iniciar o YARN ResourceManager. Verifique os logs."
        OVERALL_BOOT_STATUS="false"
        return 1
    fi

    # Idealmente, verificar 'yarn node -list' após um tempo.
    log_info "Aguardando para verificar status dos NodeManagers..."
    sleep 10
    if yarn node -list 2>/dev/null | grep -q RUNNING; then
        log_info "${GREEN_COLOR}YARN iniciado com sucesso e NodeManagers estão reportando.${RESET_COLORS}"
    else
        log_warn "YARN ResourceManager iniciado, mas pode não haver NodeManagers ativos ou reportando. Verifique 'yarn node -list' e logs dos NodeManagers."
        # Não definir OVERALL_BOOT_STATUS como false aqui, pois o RM pode estar ok.
    fi
    printf "       URL da UI do ResourceManager: http://localhost:${LIGHTBLUE_COLOR}8088${RESET_COLORS}\n"
    return 0
}

stop_yarn() {
    log_info "Parando serviço YARN (usando stop-yarn.sh)..."
    "${HADOOP_HOME}/sbin/stop-yarn.sh" > /dev/null 2>&1 || log_warn "stop-yarn.sh encontrou problemas."
    log_info "Serviço YARN parado."
}

# --- Gerenciamento do MapReduce Job History Server ---
start_mapred_history() {
    log_info "Iniciando MapReduce Job History Server..."

    # 1. Verificar se HDFS está rodando (necessário para logs do MR)
    if ! pgrep -f 'org.apache.hadoop.hdfs.server.namenode.NameNode' > /dev/null; then
        log_error "HDFS NameNode não está rodando. Inicie o HDFS antes do MapReduce History Server."
        OVERALL_BOOT_STATUS="false" # Pode ser considerado um erro se 'start all'
        return 1
    fi

    # 2. Parar se estiver rodando
    if pgrep -f 'org.apache.hadoop.mapreduce.v2.hs.JobHistoryServer' > /dev/null; then
        log_info "MapReduce JobHistoryServer existente encontrado. Parando..."
        stop_mapred_history
        sleep 1
    fi

    # 3. Iniciar o servidor
    # O comando é `mapred --daemon start historyserver`
    log_info "Iniciando daemon do MapReduce Job History Server..."
    if ! "${HADOOP_HOME}/bin/mapred" --daemon start historyserver; then
        log_error "Falha ao iniciar MapReduce Job History Server."
        # OVERALL_BOOT_STATUS pode ser afetado dependendo da criticidade
        return 1
    fi
    sleep 3

    if ! pgrep -f 'org.apache.hadoop.mapreduce.v2.hs.JobHistoryServer' > /dev/null; then
        log_error "MapReduce Job History Server falhou ao iniciar (processo não encontrado)."
        return 1
    fi
    log_info "${GREEN_COLOR}MapReduce Job History Server iniciado com sucesso.${RESET_COLORS}"
    printf "       URL da UI do MR History: http://localhost:${LIGHTBLUE_COLOR}19888${RESET_COLORS}\n"
    return 0
}

stop_mapred_history() {
    log_info "Parando MapReduce Job History Server..."
    "${HADOOP_HOME}/bin/mapred" --daemon stop historyserver > /dev/null 2>&1 || log_warn "mapred --daemon stop historyserver encontrou problemas."
    log_info "MapReduce Job History Server parado."
}

# --- Gerenciamento do Spark History Server ---
start_spark_history() {
    log_info "Iniciando Spark History Server..."

    # 1. Verificar se HDFS está rodando (se os logs do Spark estiverem no HDFS)
    # Assumindo que spark.eventLog.dir aponta para HDFS.
    if ! pgrep -f 'org.apache.hadoop.hdfs.server.namenode.NameNode' > /dev/null; then
        log_warn "HDFS NameNode não está rodando. Spark History Server pode não funcionar corretamente se os logs estiverem no HDFS."
        # Não é um erro fatal aqui, pois os logs podem estar no sistema de arquivos local.
    fi
    # É importante que o diretório configurado em spark.eventLog.dir (e spark.history.fs.logDirectory) exista.
    # Ex: hdfs dfs -mkdir -p /user/${HDFS_NAMENODE_USER}/sparkLogs (feito em start_hdfs)

    # 2. Parar se estiver rodando
    if pgrep -f 'org.apache.spark.deploy.history.HistoryServer' > /dev/null; then
        log_info "Spark History Server existente encontrado. Parando..."
        stop_spark_history
        sleep 1
    fi

    # 3. Iniciar o servidor
    log_info "Iniciando daemon do Spark History Server (usando start-history-server.sh)..."
    if ! "${SPARK_HOME}/sbin/start-history-server.sh"; then
        log_error "Falha ao iniciar Spark History Server."
        return 1
    fi
    sleep 3

    if ! pgrep -f 'org.apache.spark.deploy.history.HistoryServer' > /dev/null; then
        log_error "Spark History Server falhou ao iniciar (processo não encontrado)."
        return 1
    fi
    log_info "${GREEN_COLOR}Spark History Server iniciado com sucesso.${RESET_COLORS}"
    printf "       URL da UI do Spark History: http://localhost:${LIGHTBLUE_COLOR}18080${RESET_COLORS}\n"
    return 0
}

stop_spark_history() {
    log_info "Parando Spark History Server (usando stop-history-server.sh)..."
    "${SPARK_HOME}/sbin/stop-history-server.sh" > /dev/null 2>&1 || log_warn "stop-history-server.sh encontrou problemas."
    log_info "Spark History Server parado."
}

# --- Gerenciamento do Jupyter Lab ---
start_jupyterlab() {
    local server_ip="0.0.0.0" # Escuta em todas as interfaces
    local port="${JUPYTER_PORT:-8888}" # Porta padrão 8888, configurável via .env
    local root_dir="${JUPYTER_ROOT_DIR:-${HOME}/myfiles}" # Diretório raiz, configurável
    local jupyter_log_file="${HOME}/.jupyter/jupyterlab.log"
    local jupyter_config_dir="${HOME}/.jupyter"

    log_info "Iniciando Jupyter Lab..."

    if pgrep -f "jupyter-lab --ServerApp.ip=${server_ip}" > /dev/null; then
        log_info "Jupyter Lab já parece estar rodando. Para reiniciar, pare-o primeiro."
        return 0
    fi

    # Criar diretórios necessários
    mkdir -p "${jupyter_config_dir}"
    mkdir -p "${root_dir}" # Garante que o diretório raiz do Jupyter exista

    # Configurações: sem token e sem senha para simplificar em ambiente de desenvolvimento.
    # CUIDADO: Em produção, configure autenticação!
    log_info "Iniciando Jupyter Lab em background. IP: ${server_ip}, Porta: ${port}, Root Dir: ${root_dir}"
    log_info "Logs do Jupyter Lab estarão em: ${jupyter_log_file}"

    # `nohup ... &` para rodar em background e desanexar do terminal.
    # Redirecionar stdout e stderr para o arquivo de log.
    nohup jupyter lab \
        --ServerApp.ip="${server_ip}" \
        --ServerApp.port="${port}" \
        --ServerApp.open_browser=False \
        --ServerApp.root_dir="${root_dir}" \
        --ServerApp.token='' \
        --ServerApp.password='' \
        --ServerApp.allow_root=True \
        --ServerApp.notebook_dir="${root_dir}" > "${jupyter_log_file}" 2>&1 &

    sleep 3 # Aguardar tempo para o processo iniciar

    if ! pgrep -f "jupyter-lab --ServerApp.ip=${server_ip}" > /dev/null; then
        log_error "Falha ao iniciar Jupyter Lab. Verifique ${jupyter_log_file} para detalhes."
        cat "${jupyter_log_file}" # Mostra o log se falhar
        return 1
    fi

    log_info "${GREEN_COLOR}Jupyter Lab iniciado com sucesso.${RESET_COLORS}"
    printf "       URL do Jupyter Lab: http://localhost:${LIGHTBLUE_COLOR}${port}${RESET_COLORS} (ou IP da máquina)\n"
    return 0
}

stop_jupyterlab() {
    log_info "Parando Jupyter Lab..."
    # `pkill -f` é mais robusto para matar processos com base no nome/argumentos.
    if pkill -f "jupyter-lab"; then
        log_info "Jupyter Lab parado com sucesso."
    else
        log_warn "Nenhum processo Jupyter Lab encontrado para parar, ou falha ao parar."
    fi
}

# --- Gerenciamento do Spark Connect Server ---
start_spark_connect() {
    if [[ "${SPARK_CONNECT_SERVER}" != "enable" ]]; then
        log_info "Spark Connect Server está desabilitado na configuração (SPARK_CONNECT_SERVER=${SPARK_CONNECT_SERVER}). Pulando."
        return 0 # Não é um erro, apenas não inicia.
    fi

    : "${SPARK_VERSION:?SPARK_VERSION não definida, necessária para Spark Connect Server.}"
    log_info "Iniciando Spark Connect Server..."

    # 1. Parar se estiver rodando
    if pgrep -f "org.apache.spark.sql.connect.service.SparkConnectServer" > /dev/null; then
        log_info "Spark Connect Server existente encontrado. Parando..."
        stop_spark_connect
        sleep 1
    fi

    # 2. Iniciar o servidor
    # O pacote spark-connect é necessário. Pode ser especificado via --packages ou estar no classpath.
    log_info "Iniciando daemon do Spark Connect Server (usando start-connect-server.sh)..."
    # Exemplo de como iniciar, ajuste os pacotes/configurações conforme necessário.
    # `start-connect-server.sh` pode precisar de `spark.remote.bindAddress` e `spark.driver.bindAddress`
    # configurados em spark-defaults.conf para escutar em 0.0.0.0 se acessado de fora do contêiner.
    if ! "${SPARK_HOME}/sbin/start-connect-server.sh" --packages "org.apache.spark:spark-connect_2.12:${SPARK_VERSION}"; then
        log_error "Falha ao iniciar Spark Connect Server."
        return 1
    fi
    sleep 3

    if ! pgrep -f "org.apache.spark.sql.connect.service.SparkConnectServer" > /dev/null; then
        log_error "Spark Connect Server falhou ao iniciar (processo não encontrado)."
        return 1
    fi

    log_info "${GREEN_COLOR}Spark Connect Server iniciado com sucesso.${RESET_COLORS}"
    printf "       Porta do Spark Connect: ${LIGHTBLUE_COLOR}15002${RESET_COLORS} (padrão)\n"
    return 0
}

stop_spark_connect() {
    if [[ "${SPARK_CONNECT_SERVER}" != "enable" ]]; then
        return 0 # Não faz nada se estiver desabilitado.
    fi
    log_info "Parando Spark Connect Server (usando stop-connect-server.sh)..."
    "${SPARK_HOME}/sbin/stop-connect-server.sh" > /dev/null 2>&1 || log_warn "stop-connect-server.sh encontrou problemas."
    log_info "Spark Connect Server parado."
}

# --- Funções de Status e Relatório ---
_check_service_status_internal() {
    local service_display_name="$1"
    local process_grep_pattern="$2"
    local service_url_template="$3" # Ex: http://localhost:{PORT}
    local default_port="$4" # Porta para a URL

    local pid
    # Usar pgrep com -f para buscar na linha de comando completa, e -x para correspondência exata do nome do comando (se aplicável)
    # `pgrep -f "${process_grep_pattern}"` é geralmente bom.
    pid=$(pgrep -f "${process_grep_pattern}" | head -n 1) # Pega o primeiro PID se houver múltiplos (raro para servidores principais)

    printf "    %-25s : " "${service_display_name}" # Alinha os nomes dos serviços
    if [ -n "${pid}" ]; then
        local service_url="${service_url_template//\{PORT\}/${default_port}}" # Substitui {PORT}
        printf "${GREEN_COLOR}%-10s${RESET_COLORS} (PID: %s)" "EM EXECUÇÃO" "${pid}"
        if [ -n "${service_url_template}" ]; then
            printf " → UI: %s" "${service_url}"
        fi
        printf "\n"
    else
        printf "${RED_COLOR}%-10s${RESET_COLORS}\n" "PARADO"
    fi
}

status_all_services() {
    log_info "Verificando status de todos os serviços:"
    _check_service_status_internal "HDFS NameNode" "org.apache.hadoop.hdfs.server.namenode.NameNode" "http://localhost:{PORT}" "9870"
    _check_service_status_internal "YARN ResourceManager" "org.apache.hadoop.yarn.server.resourcemanager.ResourceManager" "http://localhost:{PORT}" "8088"
    _check_service_status_internal "MapReduce History Srv" "org.apache.hadoop.mapreduce.v2.hs.JobHistoryServer" "http://localhost:{PORT}" "19888"
    _check_service_status_internal "Spark History Server" "org.apache.spark.deploy.history.HistoryServer" "http://localhost:{PORT}" "18080"
    _check_service_status_internal "Jupyter Lab" "jupyter-lab --ServerApp.ip=0.0.0.0" "http://localhost:{PORT}" "${JUPYTER_PORT:-8888}"

    if [[ "${SPARK_CONNECT_SERVER}" == "enable" ]]; then
        _check_service_status_internal "Spark Connect Server" "org.apache.spark.sql.connect.service.SparkConnectServer" "" "15002"
    else
        printf "    %-25s : %s\n" "Spark Connect Server" "DESABILITADO"
    fi
    # Adicionar DataNode e NodeManager se este script rodasse nos workers ou tivesse como verificar remotamente.
}

report_hdfs() {
    log_info "Gerando relatório HDFS (hdfs dfsadmin -report):"
    if ! pgrep -f 'org.apache.hadoop.hdfs.server.namenode.NameNode' > /dev/null; then
        log_warn "HDFS NameNode não está em execução. Relatório pode estar incompleto ou falhar."
    fi
    # O comando pode ser longo, então apenas executar.
    "${HADOOP_HOME}/bin/hdfs" dfsadmin -report || log_warn "Falha ao gerar relatório HDFS."
}

report_yarn() {
    log_info "Gerando relatório YARN (yarn node -list):"
    if ! pgrep -f 'org.apache.hadoop.yarn.server.resourcemanager.ResourceManager' > /dev/null; then
        log_warn "YARN ResourceManager não está em execução. Relatório pode estar incompleto ou falhar."
    fi
    "${HADOOP_HOME}/bin/yarn" node -list || log_warn "Falha ao gerar relatório YARN."
}

generate_full_report() {
    log_info "--- INÍCIO DO RELATÓRIO COMPLETO DO CLUSTER ---"
    report_hdfs
    printf "\n" # Espaçamento
    report_yarn
    log_info "--- FIM DO RELATÓRIO COMPLETO DO CLUSTER ---"
}

# --- Funções Agregadas para 'all' ---
start_all_services() {
    log_info "Inicializando todos os serviços do cluster na sequência recomendada..."
    OVERALL_BOOT_STATUS="true" # Reseta o status para esta tentativa

    # A ordem é importante: HDFS primeiro, depois YARN, depois serviços dependentes.
    if ! start_hdfs; then OVERALL_BOOT_STATUS="false"; log_error "Falha crítica ao iniciar HDFS. Abortando início dos demais serviços."; return 1; fi
    if ! start_yarn; then OVERALL_BOOT_STATUS="false"; log_warn "Falha ao iniciar YARN. Alguns serviços podem não funcionar."; fi # Não aborta, outros podem funcionar
    if ! start_mapred_history; then log_warn "Falha ao iniciar MapReduce History Server."; fi
    if ! start_spark_history; then log_warn "Falha ao iniciar Spark History Server."; fi
    if ! start_jupyterlab; then log_warn "Falha ao iniciar JupyterLab."; fi
    if [[ "${SPARK_CONNECT_SERVER}" == "enable" ]]; then
        if ! start_spark_connect; then log_warn "Falha ao iniciar Spark Connect Server."; fi
    fi

    log_info "Verificação final de status e relatórios..."
    sleep 2 # Pequena pausa para estabilização
    status_all_services
    generate_full_report

    if [[ "${OVERALL_BOOT_STATUS}" == "true" ]]; then
        printf "\n${GREEN_COLOR}==============================================================${RESET_COLORS}\n"
        log_info "$(tput bold)TODOS OS SERVIÇOS PRINCIPAIS FORAM INICIADOS COM SUCESSO!$(tput sgr0)"
        printf "${GREEN_COLOR}==============================================================${RESET_COLORS}\n"
        printf "\n       DICA: Para acessar o terminal do ${YELLOW_COLOR}master${RESET_COLORS}, use:\n"
        printf "       ${YELLOW_COLOR}docker exec -it ${STACK_NAME:-seucluster}-master bash${RESET_COLORS}\n\n" # Usar STACK_NAME se disponível
    else
        printf "\n${RED_COLOR}**************************************************************${RESET_COLORS}\n"
        log_error "$(tput bold)ATENÇÃO: UM OU MAIS SERVIÇOS FALHARAM AO INICIAR.$(tput sgr0)"
        log_error "Por favor, revise os logs acima para detalhes e tente corrigir os problemas."
        printf "${RED_COLOR}**************************************************************${RESET_COLORS}\n"
        return 1 # Indica que 'start all' teve problemas
    fi
    return 0
}

# Função de animação simples (opcional, para dar feedback visual)
_animate_stopping() {
    local message="$1"
    local spin='-\|/'
    local i=0
    # Subshell para não interferir com traps ou outras manipulações de sinal
    (
        echo -n "${message} "
        while true; do
            i=$(( (i+1) %4 ))
            printf "\b%s" "${spin:$i:1}"
            sleep 0.1
        done
    ) &
    echo "$!" # Retorna o PID do subshell de animação
}

stop_all_services() {
    log_info "Parando todos os serviços do cluster na ordem inversa de dependência..."
    local animation_pid

    # animation_pid=$(_animate_stopping "${INFO_PREFIX} Parando Spark Connect")
    if [[ "${SPARK_CONNECT_SERVER}" == "enable" ]]; then
        stop_spark_connect
    fi
    # kill "$animation_pid" 2>/dev/null; printf "\r%80s\r" ""; # Limpa a linha da animação

    # animation_pid=$(_animate_stopping "${INFO_PREFIX} Parando JupyterLab")
    stop_jupyterlab
    # kill "$animation_pid" 2>/dev/null; printf "\r%80s\r" "";

    # animation_pid=$(_animate_stopping "${INFO_PREFIX} Parando Spark History")
    stop_spark_history
    # kill "$animation_pid" 2>/dev/null; printf "\r%80s\r" "";

    # animation_pid=$(_animate_stopping "${INFO_PREFIX} Parando MapReduce History")
    stop_mapred_history
    # kill "$animation_pid" 2>/dev/null; printf "\r%80s\r" "";

    # animation_pid=$(_animate_stopping "${INFO_PREFIX} Parando YARN")
    stop_yarn
    # kill "$animation_pid" 2>/dev/null; printf "\r%80s\r" "";

    # animation_pid=$(_animate_stopping "${INFO_PREFIX} Parando HDFS")
    stop_hdfs
    # kill "$animation_pid" 2>/dev/null; printf "\r%80s\r" "";

    log_info "Todos os serviços foram instruídos a parar."
    sleep 1
    status_all_services # Verifica o status final
}

# --- Mensagem de Boas-Vindas (MOTD) ---
show_motd() {
    # Usar SPARK_VERSION se disponível, senão um placeholder
    local motd_spark_version="${SPARK_VERSION:-DESCONHECIDA}"
    printf "${GREEN_COLOR}"
    cat << "EOF"
   ██████  ██▓███   ▄▄▄       ██▀███   ██ ▄█▀
 ▒██    ▒ ▓██░  ██▒▒████▄    ▓██ ▒ ██▒ ██▄█▒ 
 ░ ▓██▄   ▓██░ ██▓▒▒██  ▀█▄  ▓██ ░▄█ ▒▓███▄░ 
   ▒   ██▒▒██▄█▓▒ ▒░██▄▄▄▄██ ▒██▀▀█▄  ▓██ █▄ 
 ▒██████▒▒▒██▒ ░  ░ ▓█   ▓██▒░██▓ ▒██▒▒██▒ █▄
 ▒ ▒▓▒ ▒ ░▒▓▒░ ░  ░ ▒▒   ▓▒█░░ ▒▓ ░▒▓░▒ ▒▒ ▓▒
 ░ ░▒  ░ ░░▒ ░       ▒   ▒▒ ░  ░▒ ░ ▒░░ ░▒ ▒░
 ░  ░  ░  ░░         ░   ▒     ░░   ░ ░ ░░ ░ 
       ░                 ░  ░   ░     ░ 
EOF
    printf "       ░                 ░  ░   ░     ░ ${LIGHTBLUE_COLOR}%s${RESET_COLORS}\n" "${motd_spark_version}"
    printf "\n                         © Marcus Sampaio 2025\n"
    printf "                 ${YELLOW_COLOR}https://github.com/SampMark${RESET_COLORS}\n\n"
    printf "${RESET_COLORS}"
}

# --- Função de Uso ---
show_usage() {
    printf "Uso: $(basename "$0") [AÇÃO] [SERVIÇO]\n\n"
    printf "Este script gerencia os serviços do cluster Hadoop/Spark.\n\n"
    printf "AÇÕES:\n"
    printf "  start         Inicia o [SERVIÇO] especificado ou 'all' para todos.\n"
    printf "  stop          Para o [SERVIÇO] especificado ou 'all' para todos.\n"
    printf "  status        Mostra o status de todos os serviços (nenhum [SERVIÇO] necessário).\n"
    printf "  report        Gera relatórios para HDFS e YARN (nenhum [SERVIÇO] necessário).\n\n"
    printf "SERVIÇOS (para start/stop):\n"
    printf "  hdfs          Serviço HDFS (NameNode, DataNodes).\n"
    printf "  yarn          Serviço YARN (ResourceManager, NodeManagers).\n"
    printf "  mapred-history Serviço MapReduce Job History Server.\n"
    printf "  spark-history Serviço Spark History Server.\n"
    printf "  jupyterlab    Serviço Jupyter Lab.\n"
    printf "  spark-connect Serviço Spark Connect Server (se habilitado via .env).\n"
    printf "  all           Todos os serviços acima.\n\n"
    printf "Exemplos:\n"
    printf "  $(basename "$0") start all\n"
    printf "  $(basename "$0") stop hdfs\n"
    printf "  $(basename "$0") status\n"
    printf "  $(basename "$0") report\n"
}

# --- Lógica Principal do Script ---
main() {
    # Primeiro, executar setup_java_home independentemente da ação, pois é uma configuração base.
    if ! setup_java_home; then
        # Se setup_java_home falhar e log_error sair com exit 1, o script pararia aqui.
        # Se log_error apenas retornar 1, podemos decidir o que fazer.
        log_error "Configuração crítica do JAVA_HOME falhou. Abortando..." # Força a saída se `set -e` não pegar.
        exit 1 # Garante a saída
    fi

    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi

    ACTION="${1,,}" # Converte para minúsculas
    SERVICE="${2:-}" # Default para string vazia se não fornecido
    if [ -n "${SERVICE}" ]; then
      SERVICE="${SERVICE,,}" # Converte para minúsculas se existir
    fi


    # Lógica para ações que não requerem um segundo argumento (SERVIÇO)
    case "${ACTION}" in
        status)
            status_all_services
            exit 0
            ;;
        report)
            generate_full_report
            exit 0
            ;;
    esac

    # Ações que requerem um SERVIÇO (ou 'all')
    if [ -z "${SERVICE}" ]; then
        log_error "A ação '${ACTION}' requer um [SERVIÇO] (ou 'all')."
        show_usage
        exit 1
    fi

    case "${ACTION}" in
        start)
            show_motd # Mostra MOTD ao iniciar qualquer serviço ou todos
            case "${SERVICE}" in
                hdfs) start_hdfs ;;
                yarn) start_yarn ;;
                mapred-history) start_mapred_history ;;
                spark-history) start_spark_history ;;
                jupyterlab) start_jupyterlab ;;
                spark-connect) start_spark_connect ;;
                all) start_all_services ;;
                *) log_error "Serviço desconhecido para start: '${SERVICE}'"; show_usage; exit 1 ;;
            esac
            ;;
        stop)
            case "${SERVICE}" in
                hdfs) stop_hdfs ;;
                yarn) stop_yarn ;;
                mapred-history) stop_mapred_history ;;
                spark-history) stop_spark_history ;;
                jupyterlab) stop_jupyterlab ;;
                spark-connect) stop_spark_connect ;;
                all) stop_all_services ;;
                *) log_error "Serviço desconhecido para stop: '${SERVICE}'"; show_usage; exit 1 ;;
            esac
            ;;
        *)
            log_error "Ação desconhecida: '${ACTION}'"
            show_usage
            exit 1
            ;;
    esac

    # Verifica se a última ação principal (start/stop de serviço individual) foi bem-sucedida
    # A variável $? contém o status de saída do último comando executado.
    # As funções start_* e stop_* devem retornar 0 em sucesso e não-zero em falha.
    if [ $? -ne 0 ] && [[ "${ACTION}" == "start" || "${ACTION}" == "stop" ]]; then
        log_error "A ação '${ACTION} ${SERVICE}' parece ter falhado."
        # Não sair aqui necessariamente, a função já pode ter lidado com o erro.
    elif [[ "${ACTION}" == "start" || "${ACTION}" == "stop" ]]; then
        log_info "Ação '${ACTION} ${SERVICE}' concluída."
        status_all_services # Mostra status após start/stop de serviço individual
    fi

    exit 0
}

# --- Ponto de Entrada do Script ---
# Chama a função main com todos os argumentos passados para o script.
main "$@"

# --- Fim do Script ---
# Certifique-se de que o script termina corretamente.
# Se você estiver usando `set -e`, o script sairá automaticamente em caso de erro.
# Se não, você pode querer adicionar um `exit 0` aqui para garantir que o script termine com sucesso.
# Fim do script
# --- Fim do Script ---