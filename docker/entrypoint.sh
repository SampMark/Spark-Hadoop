#!/usr/bin/env bash
# =============================================================================
# Script de Ponto de Entrada (Entrypoint) para Contêiner Hadoop/Spark
#
# Descrição:
#   Este script é o ponto de entrada principal para os contêineres Docker do
#   cluster. Ele é executado como root e tem as seguintes responsabilidades:
#   1. Carregar variáveis de ambiente de um arquivo .env, se existir.
#   2. Validar a presença de variáveis de ambiente essenciais.
#   3. Gerar dinamicamente arquivos de configuração (Hadoop XMLs, Spark .sh)
#      a partir de templates, substituindo placeholders por variáveis de ambiente.
#   4. Definir as permissões corretas para os arquivos e diretórios de
#      configuração e dados.
#   5. Executar o script principal da aplicação (bootstrap.sh), potencialmente
#      mudando do usuário root para um usuário não privilegiado.
#
# =============================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
#     -e: Sai imediatamente se um comando falhar.
#     -u: Trata variáveis não definidas como um erro.
#     -o pipefail: Garante que o status de saída de um pipeline seja o do último comando que falhou.
set -euo pipefail

# --- Variáveis e Constantes ---
# Usuário não-privilegiado que executará os processos Hadoop/Spark.
# É esperado que esta variável seja passada para o contêiner Docker (ex: via docker-compose).
# O default para 'hadoop' é uma convenção comum.
readonly APP_USER="${MY_USERNAME:-hadoop}"
# Grupo do usuário da aplicação. Padrão para o mesmo nome do usuário.
readonly APP_GROUP="${MY_GROUP:-${APP_USER}}"

# Diretórios de configuração
readonly HADOOP_CONF_DIR_TEMPLATE="/config_files/hadoop" # Local dos templates
readonly HADOOP_CONF_DIR="/etc/hadoop"                   # Destino final das configurações
readonly SPARK_CONF_DIR_TEMPLATE="/config_files/spark"   # Local dos templates Spark
# SPARK_HOME deve ser definido como uma variável de ambiente no Dockerfile ou docker-compose
readonly SPARK_CONF_DIR="${SPARK_HOME}/conf"

# Diretórios de dados (devem corresponder aos volumes montados e às configs nos XMLs)
readonly HADOOP_DATA_DIRS="/opt/hadoop_data /var/log/hadoop /var/run/hadoop"

# --- Funções de Logging ---
# (Opcional, mas útil para logs mais claros)
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo >&2 "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

# --- Carregamento de Variáveis de Ambiente do .env ---
# Embora a prática recomendada seja injetar variáveis através do Docker,
# carregar um .env pode ser útil para desenvolvimento local ou configurações complexas.
ENV_FILE="/home/${APP_USER}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    log_info "Arquivo .env encontrado em ${ENV_FILE}. Carregando e exportando variáveis..."
    # 'set -a' exporta todas as variáveis definidas no arquivo .env
    # 'set +a' desativa este comportamento após o source
    set -a
    source "${ENV_FILE}"
    set +a
    log_info "Variáveis do .env carregadas."
fi

# --- Validação de Variáveis de Ambiente ---
log_info "Validando variáveis de ambiente essenciais..."
: "${HADOOP_HOME:?A variável de ambiente HADOOP_HOME não está definida.}"
: "${SPARK_HOME:?A variável de ambiente SPARK_HOME não está definida.}"
: "${JAVA_HOME:?A variável de ambiente JAVA_HOME não está definida.}"
: "${SPARK_MASTER_HOSTNAME:?A variável SPARK_MASTER_HOSTNAME não está definida. (Ex: spark-master)}"
# Adicionar outras validações de variáveis críticas aqui.

# --- Geração Dinâmica de Arquivos de Configuração ---
log_info "Gerando arquivos de configuração a partir de templates..."

# Função genérica para processar templates com envsubst
process_templates() {
    local template_dir="$1"
    local output_dir="$2"
    local file_extension="$3"

    if [ ! -d "${template_dir}" ]; then
        log_info "Diretório de templates ${template_dir} não encontrado, pulando."
        return
    fi

    # Exporta variáveis que precisam ser substituídas nos templates
    export SPARK_MASTER_HOSTNAME HADOOP_HOME SPARK_HOME JAVA_HOME APP_USER
    # Adicione aqui outras variáveis que você usa em seus templates

    for template in "${template_dir}"/*."${file_extension}".template; do
        if [ -f "$template" ]; then
            filename=$(basename "${template}" .template)
            destination="${output_dir}/${filename}"
            log_info "Processando template '${template}' para gerar '${destination}'..."
            envsubst < "${template}" > "${destination}"
        fi
    done
}

# Gera arquivos de configuração do Hadoop (*.xml)
process_templates "${HADOOP_CONF_DIR_TEMPLATE}" "${HADOOP_CONF_DIR}" "xml"

# Gera arquivos de configuração do Spark (*.sh)
process_templates "${SPARK_CONF_DIR_TEMPLATE}" "${SPARK_HOME}/conf" "sh"

# Verifica se o diretório de templates existe
# if [ ! -d "${HADOOP_CONF_DIR_TEMPLATE}" ]; then
#     log_error "Diretório de templates não encontrado em ${HADOOP_CONF_DIR_TEMPLATE}."
# fi

# Itera sobre todos os arquivos .xml.template e gera os arquivos .xml finais
# `envsubst` substitui variáveis como ${SPARK_MASTER_HOSTNAME} pelos seus valores no ambiente.
# for template in "${HADOOP_CONF_DIR_TEMPLATE}"/*.xml.template; do
#     if [ -f "$template" ]; then
#         # Extrai o nome do arquivo final (ex: core-site.xml)
#         filename=$(basename "${template}" .template)
#         destination="${HADOOP_CONF_DIR}/${filename}"
#         log_info "Processando template '${template}' para gerar '${destination}'..."
#         # Exportar as variáveis que o envsubst deve usar
#         export SPARK_MASTER_HOSTNAME
#         # Adicione outros exports aqui se necessário
#         envsubst < "${template}" > "${destination}"
#     fi
# done

log_info "Geração de arquivos de configuração concluída."

# Listar os arquivos gerados para depuração
ls -la "${HADOOP_CONF_DIR}"

# --- Configuração de Permissões ---
log_info "Configurando permissões para o usuário '${APP_USER}'..."

# Define permissões para os diretórios de configuração
# Isso garante que o usuário não-privilegiado possa ler as configurações.
chown -R "${APP_USER}:${APP_GROUP}" "${HADOOP_CONF_DIR}"
chown -R "${APP_USER}:${APP_GROUP}" "${SPARK_HOME}/conf"

# Define permissões para os diretórios de dados/logs/pids
# (assumindo que foram criados e montados).
# `mkdir -p` cria os diretórios caso não existam.
mkdir -p ${HADOOP_DATA_DIRS}
chown -R "${APP_USER}:${APP_GROUP}" ${HADOOP_DATA_DIRS}

log_info "Permissões configuradas com sucesso."

# --- Execução do Script Principal da Aplicação ---

# O script de bootstrap é o responsável por iniciar os daemons (HDFS, YARN, etc.).
# Em vez de executar o bootstrap como root e usar 'sudo' internamente, é uma
# prática mais segura e limpa usar 'gosu' ou 'su-exec' para mudar para o usuário
# não-privilegiado antes de executar o script principal.
# 'gosu' precisa ser instalado no contêiner.

# O `exec` no final é crucial: ele substitui o processo do entrypoint pelo
# processo do bootstrap. Isso garante que o bootstrap se torne o processo principal
# (PID 1) do contêiner, recebendo sinais do Docker (ex: SIGTERM em 'docker stop')
# para um desligamento gracioso.

BOOTSTRAP_SCRIPT="/home/${APP_USER}/scripts/bootstrap.sh"
if [ ! -f "${BOOTSTRAP_SCRIPT}" ]; then
    log_error "Script de bootstrap não encontrado em ${BOOTSTRAP_SCRIPT}."
fi

log_info "Entregando a execução para o script de bootstrap: ${BOOTSTRAP_SCRIPT} como usuário '${APP_USER}'..."
# Se 'gosu' estiver disponível (recomendado):
# exec gosu "${APP_USER}" bash "${BOOTSTRAP_SCRIPT}" "$@"
# O "$@" passa todos os argumentos recebidos pelo entrypoint para o bootstrap.

# Se 'gosu' não estiver disponível, usar `su -c` é uma alternativa, embora menos ideal:
exec su - "${APP_USER}" -c "bash ${BOOTSTRAP_SCRIPT} \"\$@\"" -- "$@"
# Esta sintaxe é um pouco complexa para garantir que os argumentos sejam passados corretamente.

# O usuário DEVE executar o bootstrap como root (porque ele precisa fazer tarefas de root
# que não foram feitas aqui), então a linha original é usada, mas com `exec`:
# log_info "Executando o script de bootstrap como root..."
# exec bash "${BOOTSTRAP_SCRIPT}" "$@"

# finaliza o entrypoint com sucesso
log_info "Entrypoint concluído com sucesso. O contêiner está pronto para uso."
# Fim do script de entrypoint
# =============================================================================
