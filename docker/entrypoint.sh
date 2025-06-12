#!/usr/bin/env bash
# =============================================================================
# Script de Ponto de Entrada (Entrypoint) para Contêiner Hadoop/Spark
#
# Descrição:
#   Este script, executado como root, prepara o ambiente do contêiner antes
#   de entregar a execução ao processo principal.
#   1. Valida variáveis de ambiente críticas.
#   2. Gera arquivos de configuração a partir de templates.
#   3. Cria e define permissões para diretórios de dados.
#   4. Usa 'gosu' para mudar para um usuário não privilegiado e executar o
#      script de bootstrap, garantindo a execução segura e o correto
#      manuseio de sinais do sistema.
# =============================================================================

# --- Configuração de Segurança e Comportamento do Shell ---
# -e: Sai imediatamente se um comando falhar.
# -u: Trata variáveis não definidas como um erro.
# -o pipefail: O status de saída de um pipeline é o do último comando que falhou.
set -euo pipefail

# --- Funções de Logging ---
log_info() {
    echo >&2 "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo >&2 "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

# --- Validação de Variáveis de Ambiente Essenciais ---
log_info "Validando variáveis de ambiente essenciais..."
: "${MY_USERNAME:?A variável MY_USERNAME deve ser definida (ex: no .env).}"
: "${HADOOP_HOME:?A variável HADOOP_HOME não está definida.}"
: "${SPARK_HOME:?A variável SPARK_HOME não está definida.}"
: "${JAVA_HOME:?A variável JAVA_HOME não está definida.}"
: "${SPARK_MASTER_HOSTNAME:?A variável SPARK_MASTER_HOSTNAME não está definida.}"
# Adicione outras validações críticas aqui se necessário (ex: STACK_NAME).

# --- Definição de Variáveis e Constantes ---
readonly APP_USER="${MY_USERNAME}"
readonly APP_GROUP="${MY_GROUP:-${APP_USER}}"

# CORREÇÃO: Caminhos de templates e de destino são agora baseados no diretório do usuário.
# Isso está alinhado com o Dockerfile que copia os arquivos para o MY_WORKDIR.
readonly TEMPLATE_DIR="/home/${APP_USER}/config_templates"
readonly CONFIG_PROCESSED_DIR="/home/${APP_USER}/config_processed"

readonly HADOOP_CONF_DIR="${CONFIG_PROCESSED_DIR}/hadoop"
readonly SPARK_CONF_DIR="${CONFIG_PROCESSED_DIR}/spark"

# --- Geração Dinâmica de Arquivos de Configuração ---
log_info "Gerando arquivos de configuração em ${CONFIG_PROCESSED_DIR}..."

# Função genérica e flexível para processar templates.
process_templates() {
    local template_subdir="$1" # ex: "hadoop" ou "spark"
    local output_subdir="$2"
    local extension="$3"       # ex: "xml" ou "sh"

    local input_dir="${TEMPLATE_DIR}/${template_subdir}"
    local output_dir="${CONFIG_PROCESSED_DIR}/${output_subdir}"

    if [[ ! -d "${input_dir}" ]]; then
        log_info "Diretório de templates ${input_dir} não encontrado, pulando."
        return
    fi
    mkdir -p "${output_dir}"

    # Exporta todas as variáveis de ambiente para que 'envsubst' possa usá-las.
    # Esta é uma abordagem simples e robusta.
    export HADOOP_HOME SPARK_HOME JAVA_HOME SPARK_MASTER_HOSTNAME MY_USERNAME

    find "${input_dir}" -type f -name "*.${extension}.template" | while read -r template; do
        filename=$(basename "${template}" .template)
        destination="${output_dir}/${filename}"
        log_info "Processando '${template}' -> '${destination}'"
        envsubst < "${template}" > "${destination}"
    done
}

# Gera arquivos de configuração do Hadoop e Spark
process_templates "hadoop" "hadoop" "xml"
process_templates "spark" "spark" "sh"
process_templates "system" "system" "sh" # Para arquivos como .bash_common, etc.

log_info "Geração de arquivos de configuração concluída. Verificando arquivos em ${CONFIG_PROCESSED_DIR}:"
ls -lR "${CONFIG_PROCESSED_DIR}"

# --- Configuração de Permissões ---
log_info "Configurando permissões para o usuário '${APP_USER}'..."

# Cria diretórios de dados e logs e define permissões.
# CORREÇÃO: Usa variáveis definidas no HADOOP/SPARK para consistência.
mkdir -p "${HADOOP_HOME}/logs" "${SPARK_HOME}/logs" "${SPARK_HOME}/work"
# Adicione outros diretórios aqui se necessário.

# Define o usuário como dono de todos os seus arquivos de trabalho.
chown -R "${APP_USER}:${APP_GROUP}" "/home/${APP_USER}"
chown -R "${APP_USER}:${APP_GROUP}" "${HADOOP_HOME}"
chown -R "${APP_USER}:${APP_GROUP}" "${SPARK_HOME}"

log_info "Permissões configuradas com sucesso."

# --- Execução do Script Principal da Aplicação ---
readonly BOOTSTRAP_SCRIPT="/home/${APP_USER}/scripts/bootstrap.sh"
if [ ! -x "${BOOTSTRAP_SCRIPT}" ]; then
    log_error "Script de bootstrap não encontrado ou não executável em ${BOOTSTRAP_SCRIPT}."
fi

log_info "Entregando a execução para: ${BOOTSTRAP_SCRIPT} (como usuário '${APP_USER}')..."
# Usa `gosu` para mudar de usuário de forma segura.
# `exec` substitui o processo do entrypoint, garantindo que o bootstrap seja o PID 1.
# "$@" passa todos os argumentos recebidos pelo entrypoint (ex: "master", "worker") para o bootstrap.
exec gosu "${APP_USER}" bash "${BOOTSTRAP_SCRIPT}" "$@"
log_info "Script de bootstrap concluído. Contêiner pronto para uso."

# --- Fim do Script de Ponto de Entrada ---
# Nota: O script acima deve ser executado como root no contêiner.
#       O usuário definido em MY_USERNAME será usado para executar o bootstrap.
#       Certifique-se de que o usuário tenha permissões adequadas para os diretórios e arquivos criados.
#       O script de bootstrap deve ser responsável por iniciar os serviços necessários (Hadoop, Spark, etc.).
#       Este script é o ponto de entrada do contêiner e deve ser executado como PID 1.
#       Ele deve ser executado com o comando `docker run` ou equivalente,
#       garantindo que o contêiner esteja configurado corretamente antes de iniciar os serviços.
#       Certifique-se de que o contêiner tenha acesso às variáveis de ambiente necessárias.
#       O contêiner deve ser iniciado com as opções corretas de rede e volumes,
#       dependendo do ambiente em que será executado (ex: Docker Compose, Kubernetes, etc.).
#       Este script é projetado para ser usado em um ambiente de desenvolvimento ou produção,
#       onde o usuário e as permissões são gerenciados adequadamente.
#       Certifique-se de que o contêiner tenha acesso aos recursos necessários (ex: rede, armazenamento, etc.).
#       O script deve ser testado em um ambiente seguro antes de ser usado em produção,
#       para garantir que todas as variáveis de ambiente e permissões estejam configuradas corretamente.
#      