#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script de Bootstrap para Contêineres Hadoop/Spark
#
# Descrição:
#   Este script é executado na inicialização de cada contêiner (master e workers).
#   Configura o ambiente, define senhas, atualiza a lista de workers do
#   Hadoop, inicia o servidor SSH e, no caso do nó master, invoca o script
#   'services.sh' para iniciar os daemons do Hadoop e Spark.
#
# Autor: Marcus V D Sampaio/Organização: IFRN] - Baseado no script original de Carlos M D Viegas
# Versão: 1.1
# Data: 2024-05-07
#
# Inspiração Original:
#   (C) 2022-2025 CARLOS M D VIEGAS
#   https://github.com/cmdviegas
#   DEPARTAMENTO DE ENGENHARIA DE COMPUTACAO E AUTOMACAO
#   UNIVERSIDADE FEDERAL DO RIO GRANDE DO NORTE, NATAL/RN
#
# Como funciona (fluxo esperado):
#   1. Define configurações seguras de shell.
#   2. Define variáveis de ambiente e cores para logging.
#   3. Valida a presença de variáveis de ambiente essenciais.
#   4. Tenta carregar configurações do .bashrc.
#   5. Define a senha do usuário 'myuser' com base no arquivo de segredo.
#   6. Atualiza dinamicamente o arquivo 'workers' do Hadoop com os hostnames
#      dos nós workers, conforme a variável NUM_WORKER_NODES.
#   7. Inicia o serviço SSH.
#   8. Se for o nó MASTER:
#      a. Aguarda um tempo para permitir que os workers iniciem o SSH (opcional).
#      b. Executa o script '${HOME}/services.sh start' para iniciar os serviços
#         principais do cluster (HDFS, YARN, Spark Master).
#   9. Se for um nó WORKER:
#      a. Exibe uma mensagem indicando que está aguardando conexão do master.
#      b. Os daemons do worker (DataNode, NodeManager, Spark Worker) são
#         geralmente iniciados pelo master via SSH ou por um script local
#         invocado pelo entrypoint/CMD específico do worker.
#         (Este script não inicia daemons do worker explicitamente, o que é comum
#          se o `services.sh` no master cuida disso ou se o Spark é standalone
#          e os workers se registram no master).
#  10. Mantém o contêiner em execução com 'tail -f /dev/null' ou um processo
#      supervisor, em vez de 'exec /bin/bash' que é mais para depuração.
#
# Argumentos Esperados:
#   $1: Tipo de nó - "MASTER" ou "WORKER".
#   $2: (Opcional para WORKER) ID do Worker, se necessário para alguma lógica específica.
#
# Variáveis de Ambiente Esperadas:
#   HOME: Diretório home do usuário (ex: /home/myuser).
#   MY_SECRETS_FILE: Caminho para o arquivo contendo a senha do usuário.
#   HADOOP_CONF_DIR: Diretório de configuração do Hadoop (ex: $HADOOP_HOME/etc/hadoop).
#   NUM_WORKER_NODES: Número total de nós workers no cluster.
#   STACK_NAME: Prefixo para os hostnames (ex: meucluster).
#   HOSTNAME: Hostname do contêiner atual.
#   Outras variáveis de ambiente do Hadoop/Spark (HADOOP_HOME, SPARK_HOME, etc.)
#   devem estar definidas (geralmente no .bashrc ou Dockerfile).
# -----------------------------------------------------------------------------

# --- Configuração de Segurança e Comportamento do Shell ---
#     -e: Sai imediatamente se um comando falhar.
#     -u: Trata variáveis não definidas como um erro.
#     -o pipefail: Faz com que o status de saída de um pipeline seja o do último comando que falhou.
set -euo pipefail

# --- Definição de Cores para Logs ---
# Cores definidas para não dependerem do .bashrc estar carregado.
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
YELLOW_COLOR='\033[0;33m'
RESET_COLORS='\033[0m'

# --- Prefixo para Mensagens de Log ---
# Definindo explicitamente INFO, WARN, ERROR para uso no script.
INFO_PREFIX="[${GREEN_COLOR}INFO${RESET_COLORS}]"
WARN_PREFIX="[${YELLOW_COLOR}WARN${RESET_COLORS}]"
ERROR_PREFIX="[${RED_COLOR}ERROR${RESET_COLORS}]"

# --- Funções de Logging ---
log_info() { printf "%b %s\n" "${INFO_PREFIX}" "$1"; }
log_warn() { printf "%b %s\n" "${WARN_PREFIX}" "$1"; }
log_error() { printf "%b %s\n" "${ERROR_PREFIX}" "$1"; exit 1; } # Erros fatais saem do script

# --- Validação de Argumentos do Script ---
if [ -z "${1:-}" ]; then
    log_error "Argumento do tipo de nó (MASTER/WORKER) não fornecido."
fi
NODE_TYPE=$(echo "$1" | tr '[:lower:]' '[:upper:]') # Converte para maiúsculas

if [ "${NODE_TYPE}" != "MASTER" ] && [ "${NODE_TYPE}" != "WORKER" ]; then
    log_error "Tipo de nó inválido: '${1}'. Deve ser 'MASTER' ou 'WORKER'."
fi
log_info "Tipo de nó configurado: ${YELLOW_COLOR}${NODE_TYPE}${RESET_COLORS}"

# --- Validação de Variáveis de Ambiente Essenciais ---
: "${HOME:?Variável HOME não definida. Verifique a configuração do contêiner.}"
: "${MY_SECRETS_FILE:?Variável MY_SECRETS_FILE (caminho para o arquivo de senha) não definida.}"
: "${HADOOP_CONF_DIR:?Variável HADOOP_CONF_DIR (diretório de configuração do Hadoop) não definida.}"
: "${NUM_WORKER_NODES:?Variável NUM_WORKER_NODES (número de workers) não definida.}"
: "${STACK_NAME:?Variável STACK_NAME (prefixo do nome do cluster) não definida.}"
# HOSTNAME é geralmente definido pelo Docker.

# --- Carregamento do .bashrc ---
# O .bashrc configura HADOOP_HOME, SPARK_HOME, PATH, etc.
# O método original `eval "$(tail -n +10 ...)"` é um hack para evitar problemas
# com o .bashrc, padrão do Debian/Ubuntu, que sai se não for um shell interativo.
# Uma abordagem mais limpa seria ter um .bashrc específico para o ambiente não interativo
# ou garantir que o .bashrc padrão não saia.
log_info "Tentando carregar configurações do ${HOME}/.bashrc..."
if [ -f "${HOME}/.bashrc" ]; then
    # shellcheck source=/dev/null
    # Tentar `source` primeiro. Se o .bashrc tiver a guarda para shells não interativos, isso pode não funcionar.
    # source "${HOME}/.bashrc" || true # O '|| true' evita que o script pare com 'set -e' se source falhar.

    # O método original é mais robusto para .bashrcs problemáticos:
    # pois remove as primeiras linhas que geralmente contêm a verificação de interatividade.
    # CUIDADO: Isso assume que as primeiras 9 linhas são seguras para remover.
    # Ajuste o `+10` conforme necessário para o seu .bashrc específico.
    # Usar `bash -c` para executar o conteúdo em um subshell bash limpo.
    # Isso é mais seguro que `eval` direto.
    bash_rc_content=$(tail -n +10 "${HOME}/.bashrc")
    if [ -n "$bash_rc_content" ]; then
      # shellcheck disable=SC1090 # Desabilita o aviso sobre source de string variável
      # Usar `.` (sinônimo de source em POSIX sh, mas estamos em bash) para carregar no contexto atual.
      . <(echo "$bash_rc_content")
      log_info "${HOME}/.bashrc carregado (método tail)."
    else
      log_warn "Conteúdo do ${HOME}/.bashrc (após tail) está vazio ou não foi lido."
    fi

    # Após carregar, verificar se variáveis importantes como HADOOP_HOME estão definidas.
    : "${HADOOP_HOME:?HADOOP_HOME não definido após carregar .bashrc. Verifique seu .bashrc.}"
    : "${SPARK_HOME:?SPARK_HOME não definido após carregar .bashrc. Verifique seu .bashrc.}"
    log_info "HADOOP_HOME: ${HADOOP_HOME}"
    log_info "SPARK_HOME: ${SPARK_HOME}"
else
    log_warn "${HOME}/.bashrc não encontrado. Variáveis de ambiente importantes podem não estar definidas."
fi

# --- Configuração da Senha do Usuário ---
# Define a senha para o usuário 'myuser' (ou o usuário que executa os processos Hadoop/Spark).
# Assume que o script está rodando como root ou tem permissões sudo.
USER_TO_CONFIG="myuser" # Ou use uma variável de ambiente como ${TARGET_USER:-myuser}
log_info "Configurando senha para o usuário '${USER_TO_CONFIG}'..."
if [ ! -f "${MY_SECRETS_FILE}" ]; then
    log_warn "Arquivo de segredo '${MY_SECRETS_FILE}' não encontrado. A senha do usuário não será alterada."
else
    # Valida se o usuário existe
    if ! id -u "${USER_TO_CONFIG}" > /dev/null 2>&1; then
        log_warn "Usuário '${USER_TO_CONFIG}' não encontrado. Não é possível definir a senha."
    else
        MY_PASSWORD=$(cat "${MY_SECRETS_FILE}")
        if [ -z "${MY_PASSWORD}" ]; then
            log_warn "O arquivo de segredo '${MY_SECRETS_FILE}' está vazio. Senha não alterada."
        else
            # O formato para chpasswd -e é "username:encrypted_password"
            # Se a senha no arquivo não estiver encriptada, não use -e.
            # Assumindo que MY_PASSWORD é a senha em texto plano:
            echo "${USER_TO_CONFIG}:${MY_PASSWORD}" | sudo chpasswd # Sem -e se a senha for texto plano
            # Se a senha no arquivo já estiver encriptada (ex: via mkpasswd):
            # echo "${USER_TO_CONFIG}:${MY_PASSWORD}" | sudo chpasswd -e
            log_info "Senha para o usuário '${USER_TO_CONFIG}' configurada com sucesso."
        fi
    fi
fi

# --- Atualização do Arquivo 'workers' do Hadoop ---
# O arquivo HADOOP_CONF_DIR/workers (anteriormente 'slaves') lista os nós DataNode/NodeManager.
WORKERS_FILE="${HADOOP_CONF_DIR}/workers"
log_info "Atualizando arquivo de workers do Hadoop em '${WORKERS_FILE}'..."
if [ ! -d "${HADOOP_CONF_DIR}" ]; then
    log_error "Diretório de configuração do Hadoop '${HADOOP_CONF_DIR}' não encontrado."
fi

# Limpa o arquivo de workers antes de adicionar os novos.
# Usar '>' para truncar e criar se não existir.
: > "${WORKERS_FILE}" # Mais portável que truncate -s 0 para sh/bash simples

# Adiciona os hostnames dos workers. O formato é um hostname por linha.
# Ex: meucluster-worker-1, meucluster-worker-2
current_worker_idx=1
while [ "${current_worker_idx}" -le "${NUM_WORKER_NODES}" ]; do
    worker_hostname="${STACK_NAME}-worker-${current_worker_idx}"
    echo "${worker_hostname}" >> "${WORKERS_FILE}"
    log_info "Adicionado worker '${worker_hostname}' ao arquivo '${WORKERS_FILE}'."
    current_worker_idx=$((current_worker_idx + 1))
done
log_info "Conteúdo do arquivo '${WORKERS_FILE}':"
cat "${WORKERS_FILE}" # Mostra o conteúdo para verificação

# --- Início do Serviço SSH ---
# O SSH é necessário para que o master Hadoop/Spark possa gerenciar os workers.
log_info "Iniciando o serviço SSH..."
# O comando para iniciar o SSH pode variar (service ssh start, /etc/init.d/ssh start, /usr/sbin/sshd)
# 'service ssh start' é comum em sistemas baseados em Debian/Ubuntu.
# Redirecionar saída para /dev/null pode ocultar erros importantes.
# É melhor capturar a saída ou verificar o status do serviço.
if sudo service ssh start; then
    log_info "Serviço SSH iniciado com sucesso."
else
    log_warn "Falha ao iniciar o serviço SSH com 'service ssh start'. Tente verificar os logs do SSH."
    # Tentar uma alternativa ou logar um erro mais forte se o SSH for crítico.
fi
# Verificar se o sshd está rodando:
# ps aux | grep sshd

# --- Lógica Específica para Master e Worker ---
if [ "${NODE_TYPE}" = "MASTER" ]; then
    log_info "Nó MASTER detectado. Iniciando serviços do cluster..."
    # Um pequeno 'sleep' é útil para dar tempo aos workers iniciarem seus serviços SSH,
    # se o master for iniciar processos neles imediatamente.
    # No entanto, uma melhor abordagem seria os workers se registrarem ou o master
    # ter um loop de espera/verificação.
    MASTER_START_DELAY="${MASTER_START_DELAY:-5}" # Delay em segundos, configurável via .env
    log_info "Aguardando ${MASTER_START_DELAY}s para possível estabilização dos workers (configurável via MASTER_START_DELAY)..."
    sleep "${MASTER_START_DELAY}"

    SERVICES_SCRIPT_PATH="${HOME}/services.sh" # Ou um caminho fixo como /opt/cluster_scripts/services.sh
    if [ ! -f "${SERVICES_SCRIPT_PATH}" ]; then
        log_error "Script de serviços '${SERVICES_SCRIPT_PATH}' não encontrado no nó MASTER."
    fi

    log_info "Executando '${SERVICES_SCRIPT_PATH} start' como usuário '${USER_TO_CONFIG}'..."
    # É crucial que 'services.sh' inicie os daemons do Hadoop e Spark.
    # Se o script atual roda como root, e os daemons Hadoop/Spark devem rodar
    # como 'myuser', use 'sudo -u myuser' ou 'su - myuser -c'.
    # Se este script já roda como 'myuser', o sudo não é necessário aqui.
    # Assumindo que este script (bootstrap.sh) pode ter sido iniciado como root pelo Docker.
    if sudo -u "${USER_TO_CONFIG}" bash "${SERVICES_SCRIPT_PATH}" start; then
        log_info "Script de serviços '${SERVICES_SCRIPT_PATH} start' executado com sucesso."
    else
        log_error "Falha ao executar '${SERVICES_SCRIPT_PATH} start'. Verifique os logs."
    fi
    log_info "Serviços do MASTER (HDFS, YARN, Spark Master) devem estar iniciando."
    log_info "Verifique os logs dos respectivos serviços para confirmação."

elif [ "${NODE_TYPE}" = "WORKER" ]; then
    # Para workers, este script geralmente apenas inicia o SSH e espera.
    # Os daemons do worker (DataNode, NodeManager, Spark Worker) são normalmente
    # iniciados pelo nó master (via start-dfs.sh, start-yarn.sh, start-slaves.sh do Spark)
    # ou, em um setup Spark Standalone, o Spark Worker pode ser iniciado aqui para se registrar no master.
    # Exemplo para Spark Standalone Worker (DESCOMENTE E ADAPTE SE NECESSÁRIO):
    # log_info "Nó WORKER detectado. Tentando iniciar Spark Worker..."
    # SPARK_MASTER_URL="spark://${STACK_NAME}-master:7077" # Ou lido de uma variável de ambiente
    # if [ -f "${SPARK_HOME}/sbin/start-worker.sh" ]; then
    #     log_info "Iniciando Spark Worker, conectando ao master em ${SPARK_MASTER_URL}..."
    #     # Executar como o usuário correto
    #     sudo -u "${USER_TO_CONFIG}" "${SPARK_HOME}/sbin/start-worker.sh" "${SPARK_MASTER_URL}"
    # else
    #     log_warn "${SPARK_HOME}/sbin/start-worker.sh não encontrado."
    # fi
    log_info "Nó WORKER (${HOSTNAME}) iniciado. Aguardando instruções do MASTER ou mantendo o SSH ativo."
fi

# --- Manter o Contêiner em Execução ---
# O `exec /bin/bash` original é bom para depuração, pois dá um shell interativo.
# Para um serviço em produção/operação, é melhor manter o contêiner rodando
# com um processo que não termine, ou o processo principal do serviço.
# Se os daemons Hadoop/Spark são iniciados em background pelo services.sh,
# precisamos de algo para manter o contêiner vivo.
log_info "Bootstrap concluído. Mantendo o contêiner em execução..."
log_info "Para acessar este contêiner: docker exec -it ${HOSTNAME} /bin/bash"

# Opção 1: Se os serviços (HDFS, YARN, Spark daemons) rodam em foreground e
# o 'services.sh' os gerencia, então o 'services.sh' pode ser o processo final.
# Nesse caso, este 'tail' não seria necessário se 'services.sh' for o último comando.

# Opção 2: Se os serviços rodam em background, use 'tail -f /dev/null' (ou um log específico)
# para manter o contêiner rodando indefinidamente.
# É uma prática comum quando não há um processo principal em foreground óbvio.
# Alternativamente, use um supervisor de processos como 'tini' ou 'supervisord'.
# 'tini' é bom para ser o PID 1 e lidar com sinais e processos zumbis.
# Exemplo com tini (se instalado e configurado como entrypoint):
# exec tini -- supervisord -n (se usando supervisord)
# ou
# exec tini -- seu-script-que-inicia-servicos-em-foreground-ou-espera.sh

# Usando tail -f /dev/null como um placeholder para manter o container vivo.
# Considere uma solução mais robusta para produção.
tail -f /dev/null

# Se o objetivo é apenas prover um shell após o setup (para desenvolvimento/teste):
# exec /bin/bash
# Mas isso não é recomendado para serviços que devem rodar continuamente.

# Fim do script bootstrap.sh
# -----------------------------------------------------------------------------
# Este script é executado como parte do processo de inicialização do contêiner.
# Ele deve ser chamado pelo entrypoint do Dockerfile ou diretamente no CMD do Docker.
# Certifique-se de que o entrypoint do Docker esteja configurado para chamar este script
# com os argumentos corretos (MASTER/WORKER).