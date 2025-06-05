#!/bin/sh
# -----------------------------------------------------------------------------
# Script de Inicialização e Geração do Docker Compose
#
# Descrição:
#   Este script é responsável por:
#   1. Gerar dinamicamente o arquivo 'docker-compose.yml' com base no número
#      de nós workers (SPARK_WORKER_INSTANCES) e outras configurações definidas
#      em variáveis de ambiente (espera-se que sejam carregadas de um .env).
#   2. Invocar o script 'download.sh' para baixar os artefatos do Hadoop e Spark,
#      se a variável DOWNLOAD_HADOOP_SPARK estiver definida como "true".
#
# Autor: [Marcus V D Sampaio/Organização: IFRN] - Baseado no script original de Carlos M D Viegas
# Versão: 1.1
# Data: 2024-05-07
#
# Inspiração Original:
#   (C) 2022-2025 CARLOS M D VIEGAS
#   https://github.com/cmdviegas
#   DEPARTAMENTO DE ENGENHARIA DE COMPUTACAO E AUTOMACAO
#   UNIVERSIDADE FEDERAL DO RIO GRANDE DO NORTE, NATAL/RN
#
# Uso:
#   Este script é projetado para ser executado dentro de um contêiner Docker
#   como parte de um processo de inicialização, através do comando:
#   docker compose run --rm init
#   O script espera que variáveis de ambiente como: STACK_NAME, IMAGE_NAME,
#   SPARK_WORKER_INSTANCES, HADOOP_VERSION, SPARK_VERSION, etc., estejam definidas.
#
# Requisitos:
#   - sh (POSIX shell)
#   - Variáveis de ambiente configuradas (normalmente via .env e Docker Compose)
#   - Script 'script_files/download.sh' presente e executável.
#
# Licença: MIT e Apache 2.0
# -----------------------------------------------------------------------------

# --- Configuração de Segurança e Comportamento do Shell ---
set -o errexit  # Sai imediatamente se um comando falhar (equivalente a set -e)
set -o nounset  # Trata variáveis não definidas como um erro (equivalente a set -u)
set -o pipefail # Faz com que o status de saída de um pipeline seja o do último comando que falhou

# --- Definição de Cores para Logs ---
RED_COLOR='\033[0;31m' # Uso \033 em vez de \e para maior portabilidade com 'sh'
GREEN_COLOR='\033[0;32m'
YELLOW_COLOR='\033[0;33m'
LIGHTBLUE_COLOR='\033[0;36m'
RESET_COLORS='\033[0m'

# --- Verificação de Compatibilidade do Shell ---
# Verifica se o shell é compatível com POSIX (sh)
if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
    echo "Este script deve ser executado com um shell compatível com POSIX (sh)."
    echo "Use: docker compose run --rm init"
    exit 1
fi
# Verifica se o shell é sh ou bash
if [ -n "${BASH_VERSION:-}" ] || [ -n "${ZSH_VERSION:-}" ]; then
    echo "Este script não deve ser executado diretamente com bash ou zsh."
    echo "Use: docker compose run --rm init"
    exit 1
fi
# Verifica se o shell é sh  ou dash
if [ -n "${SH_VERSION:-}" ] || [ -n "${DASH_VERSION:-}" ]; then
    echo "Este script deve ser executado com sh ou dash."
    echo "Use: docker compose run --rm init"
    exit 1
fi

# --- Prefixo para Mensagens de Log ---
INFO="[${GREEN_COLOR}INFO${RESET_COLORS}]"
ERROR="[${RED_COLOR}ERROR${RESET_COLORS}]"
WARN="[${YELLOW_COLOR}WARN${RESET_COLORS}]"

# --- Funções de Logging ---
log_info() { printf "%b %s\n" "${INFO}" "$1"; }
log_warn() { printf "%b %s\n" "${WARN}" "$1"; }
log_error() { printf "%b %s\n" "${ERROR}" "$1"; exit 1; } # Adicionado exit 1 para erros

# --- Verificação do Ambiente de Execução ---
# DOCKER_COMPOSE_RUN é esperado ser definido pelo serviço 'init' no docker-compose.yml
if [ -z "${DOCKER_COMPOSE_RUN:-}" ]; then # :-} evita erro com nounset se não definida
    log_warn "Este script deve ser executado usando: ${YELLOW_COLOR}docker compose run --rm init${RESET_COLORS}"
    # Em um cenário de produção, um log_error aqui seria apropriado.
    # Para depuração, pode-se permitir a execução com um aviso.
    # exit 1 # Descomente se quiser forçar a saída
fi

# --- Definições de Arquivos e Variáveis ---
COMPOSE_FILE_GENERATED="docker-compose.yml" # Nome do arquivo a ser gerado
SCRIPT_DIR_RELATIVE="script_files" # Diretório relativo onde os scripts auxiliares estão
DOWNLOAD_SCRIPT_PATH="${SCRIPT_DIR_RELATIVE}/download_all.sh"

# --- Validação das Variáveis de Ambiente Essenciais ---
# Essas variáveis são cruciais para a geração do docker-compose.yml
: "${STACK_NAME:?Variável STACK_NAME não definida. Defina-a no arquivo .env}"
: "${IMAGE_NAME:?Variável IMAGE_NAME não definida. Defina-a no arquivo .env}"
: "${SPARK_WORKER_INSTANCES:?Variável SPARK_WORKER_INSTANCES (número de workers) não definida. Defina-a no arquivo .env}"
: "${HADOOP_VERSION:?Variável HADOOP_VERSION não definida. Defina-a no arquivo .env}"
: "${SPARK_VERSION:?Variável SPARK_VERSION não definida. Defina-a no arquivo .env}"
# : "${APT_MIRROR:-}" # APT_MIRROR é opcional, por isso o uso de :-

# Valida se SPARK_WORKER_INSTANCES é um número inteiro positivo
if ! echo "${SPARK_WORKER_INSTANCES}" | grep -Eq '^[1-9][0-9]*$'; then
    log_error "SPARK_WORKER_INSTANCES deve ser um número inteiro positivo. Valor recebido: '${SPARK_WORKER_INSTANCES}'"
fi

# --- Função para Gerar o Arquivo docker-compose.yml ---
generate_compose_file() {
    local num_workers="$1"

    log_info "Gerando ${COMPOSE_FILE_GENERATED} para ${YELLOW_COLOR}${num_workers}${RESET_COLORS} nó(s) worker(s)..."

    # Usar delimitadores de Here Document que não conflitem com o conteúdo YAML.
    # Adicionado 'name' no topo do compose para definir o nome do projeto Docker Compose.
    # A variável USER_PASSWORD_FILE é usada para o segredo, em vez de .password diretamente.
    # A rede foi simplificada para usar o nome padrão gerado pelo Docker Compose (baseado em STACK_NAME).
    cat > "${COMPOSE_FILE_GENERATED}" << EOF_COMPOSE
# -----------------------------------------------------------------------------
# ARQUIVO DOCKER COMPOSE GERADO AUTOMATICAMENTE
#
# ATENÇÃO: Este arquivo é gerado pelo script '${SCRIPT_DIR_RELATIVE}/init.sh'.
#          Alterações manuais podem ser sobrescritas na próxima execução do init.
#
# Para adicionar serviços customizados, considere usar um arquivo de override
# como 'docker-compose.override.yml' ou 'docker-compose.aux.yml' e execute com:
#   docker compose -f docker-compose.yml -f docker-compose.override.yml up
#
# Inspiração Original:
#   (C) 2022-2025 CARLOS M D VIEGAS
#   https://github.com/cmdviegas
# -----------------------------------------------------------------------------
version: '3.8' # Especificar uma versão do compose format

name: ${STACK_NAME} # Define o nome do projeto/stack no Docker

x-common-properties: &common-properties
  image: \${IMAGE_NAME} # Usar \ para escapar o $ e permitir a interpolação pelo Docker Compose
  tty: true
  restart: on-failure
  entrypoint: ["bash", "bootstrap.sh"] # Assumindo que bootstrap.sh está no PATH ou WORKDIR da imagem
  networks:
    - spark_cluster_net # Nome da rede definida abaixo
  secrets:
    - source: user_password_secret # Nome do segredo definido na seção 'secrets'
      target: /run/secrets/user_password_file # Caminho onde o segredo será montado no container
  environment:
    - MY_SECRETS_FILE=/run/secrets/user_password_file
    - SPARK_WORKER_INSTANCES=\${SPARK_WORKER_INSTANCES} # Passa o número de workers para os containers
    - STACK_NAME=\${STACK_NAME} # Passa o nome da stack para os containers

networks:
  spark_cluster_net: # Nome da rede
    driver: bridge
    name: \${STACK_NAME}_network # Nome explícito da rede para evitar ambiguidades
    ipam:
      driver: default
      config:
        - subnet: \${DOCKER_NETWORK_SUBNET:-172.31.0.0/24} # Permite customizar a subrede via .env

volumes:
  hadoop_master_data: # Volume para persistência de dados do HDFS NameNode, etc.
    name: \${STACK_NAME}_master_volume
    driver: local
  # Adicionar outros volumes conforme necessário, ex: para logs, dados de apps
  # shared_data:
  #   name: \${STACK_NAME}_shared_data
  #   driver: local

secrets:
  user_password_secret: # Nome do segredo
    file: \${USER_PASSWORD_FILE:-./.password} # Caminho para o arquivo de senha no host, com fallback

services:
  # O serviço 'init' que executa este script.
  # Pode ser útil para re-gerar o compose ou executar outras tarefas de setup.
  init:
    image: alpine/git:latest # Uma imagem leve com sh e git (se precisar clonar algo)
    # Alternativa: usar a mesma imagem base do Hadoop/Spark se precisar de ferramentas específicas
    container_name: \${STACK_NAME}-init
    profiles: ["init-tools"] # Permite rodar este serviço apenas quando o perfil 'init-tools' é ativado
    tty: true
    restart: "no"
    working_dir: /workspace
    volumes:
      - ./:/workspace # Monta o diretório atual do projeto
      - /var/run/docker.sock:/var/run/docker.sock # Opcional: se o script precisar interagir com o Docker daemon
    environment:
      # Passa todas as variáveis do .env para o container init
      # Isso é geralmente feito automaticamente pelo Docker Compose se 'env_file' é usado
      # ou se as variáveis já estão no ambiente do host.
      # Exemplo explícito:
      - DOCKER_COMPOSE_RUN=true
      - DOWNLOAD_HADOOP_SPARK=\${DOWNLOAD_HADOOP_SPARK:-false}
      - SPARK_WORKER_INSTANCES=\${SPARK_WORKER_INSTANCES}
      - STACK_NAME=\${STACK_NAME}
      - IMAGE_NAME=\${IMAGE_NAME}
      - HADOOP_VERSION=\${HADOOP_VERSION}
      - SPARK_VERSION=\${SPARK_VERSION}
      - USER_PASSWORD_FILE=\${USER_PASSWORD_FILE:-./.password}
      - DOCKER_NETWORK_SUBNET=\${DOCKER_NETWORK_SUBNET:-172.31.0.0/24}
      # Outras variáveis...
    # O entrypoint é o próprio script init.sh (ou um wrapper se necessário)
    # O caminho deve ser relativo ao working_dir montado
    entrypoint: ["sh", "${SCRIPT_DIR_RELATIVE}/init.sh"]
    # Se o init.sh precisar do .env, ele deve ser lido pelo script ou
    # as variáveis devem ser passadas via 'environment'.
    # Docker Compose v2+ normalmente já disponibiliza vars do .env.

  # Serviço Master (Hadoop NameNode, YARN ResourceManager, Spark Master)
  master:
    <<: *common-properties # Herda propriedades comuns
    container_name: \${STACK_NAME}-master
    hostname: \${STACK_NAME}-master
    build:
      context: . # Caminho para o diretório de build da imagem
      dockerfile: Dockerfile # Nome do Dockerfile principal
      args: # Argumentos de build para o Dockerfile
        SPARK_VERSION: \${SPARK_VERSION}
        HADOOP_VERSION: \${HADOOP_VERSION}
        # APT_MIRROR: \${APT_MIRROR} # Opcional, se usado no Dockerfile
    ports: # Mapeamento de portas do container para o host
      # HDFS
      - "\${HDFS_NAMENODE_UI_PORT:-9870}:9870"      # NameNode UI
      - "\${HDFS_NAMENODE_IPC_PORT:-9000}:9000"      # NameNode IPC (fs.defaultFS)
      # YARN
      - "\${YARN_RM_UI_PORT:-8088}:8088"            # ResourceManager UI
      # Spark
      - "\${SPARK_MASTER_UI_PORT:-8080}:8080"       # Spark Master UI (standalone)
      - "\${SPARK_MASTER_PORT:-7077}:7077"           # Spark Master Port (standalone)
      - "\${SPARK_HISTORY_UI_PORT:-18080}:18080"   # Spark History Server UI
      # Outros (Exemplos)
      # - "\${JUPYTER_PORT:-8888}:8888"            # Jupyter Lab/Notebook
      # - "\${SPARK_CONNECT_PORT:-15002}:15002"     # Spark Connect (se habilitado)
      # - "\${MAPRED_HISTORY_UI_PORT:-19888}:19888" # MapReduce Job History UI
    volumes:
      - hadoop_master_data:/ Ruta/Dentro/Del/Container/Para/HDFS/NameNode # Ex: /opt/hadoop_data/namenode
      # Montar diretórios de configuração (pode ser gerenciado dentro da imagem ou via entrypoint)
      # Exemplo de montagem de arquivos de configuração individuais:
      - ./config_files/hadoop/core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml:ro
      - ./config_files/hadoop/hdfs-site.xml:/opt/hadoop/etc/hadoop/hdfs-site.xml:ro
      # ... outros arquivos de configuração do Hadoop ...
      - ./config_files/spark/spark-defaults.conf:/opt/spark/conf/spark-defaults.conf:ro
      - ./config_files/spark/spark-env.sh:/opt/spark/conf/spark-env.sh:ro
      # Montar um diretório compartilhado para dados ou aplicações
      # - shared_data:/opt/shared_files
      # Montar o .env dentro do master se ele precisar ler algo diretamente (cuidado com segredos)
      # - ./.env:/opt/cluster_env/.env:ro
    command: ["MASTER"] # Argumento para o bootstrap.sh
    # depends_on: # Se houver dependências explícitas, como um banco de dados externo
    #   - some-other-service

EOF_COMPOSE

    # --- Geração Dinâmica dos Nós Workers ---
    # Os workers herdam de *common-properties e têm configurações específicas.
    # A numeração dos workers começa em 1.
    current_worker_num=1
    while [ "${current_worker_num}" -le "${num_workers}" ]; do
        # Usar printf para formatação e evitar problemas com caracteres especiais no nome do worker
        # Os volumes de configuração são semelhantes ao master, mas podem ser customizados por worker se necessário.
        printf "  worker-%d:\n" "${current_worker_num}" >> "${COMPOSE_FILE_GENERATED}"
        cat >> "${COMPOSE_FILE_GENERATED}" << EOF_WORKER_SERVICE
    <<: *common-properties
    container_name: \${STACK_NAME}-worker-${current_worker_num}
    hostname: \${STACK_NAME}-worker-${current_worker_num}
    # volumes: # Volumes específicos para workers, se necessário
    #   - shared_data:/opt/shared_files
    #   - ./config_files/hadoop/core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml:ro # Exemplo
    #   - ./.env:/opt/cluster_env/.env:ro
    command: ["WORKER", "${current_worker_num}"] # Passa o ID do worker para o bootstrap.sh
    # depends_on: # Workers geralmente dependem do master estar minimamente pronto
    #   master:
    #     condition: service_started # Ou service_healthy, se healthchecks estiverem configurados
EOF_WORKER_SERVICE
        current_worker_num=$((current_worker_num + 1))
    done

    log_info "${YELLOW_COLOR}${COMPOSE_FILE_GENERATED}${RESET_COLORS} gerado com sucesso."
} # Fim da função generate_compose_file

# --- Rotina Principal de Execução ---

# Define o número de workers a serem gerados.
# Se o primeiro argumento do script for "default", usa 2 workers.
# Caso contrário, usa o valor da variável de ambiente SPARK_WORKER_INSTANCES.
num_workers_to_generate="${SPARK_WORKER_INSTANCES}"
if [ "${1:-}" = "default" ]; then # :-} para evitar erro com nounset se $1 não estiver definido
    log_info "Argumento 'default' recebido. Revertendo para 2 nós workers."
    num_workers_to_generate=2
    # Se estiver usando "default", garantir que SPARK_WORKER_INSTANCES seja atualizado para consistência
    # Isso é mais para o caso de outros scripts ou o próprio docker-compose lerem essa variável.
    # export SPARK_WORKER_INSTANCES=2 # Cuidado: export aqui afeta apenas este script e seus filhos.
                                  # A alteração no .env seria mais persistente.
elif [ -n "${1:-}" ]; then
    log_warn "Argumento '$1' recebido e ignorado. Usando SPARK_WORKER_INSTANCES=${SPARK_WORKER_INSTANCES}."
    # Ou tratar $1 como o número de workers se essa for a intenção.
fi

generate_compose_file "${num_workers_to_generate}"

# --- Execução do Script de Download ---
# Verifica a variável DOWNLOAD_HADOOP_SPARK.
# Se "true", torna o script de download executável e o executa.
if [ "${DOWNLOAD_HADOOP_SPARK:-false}" = "true" ]; then # :-false para default se não definida
    log_info "DOWNLOAD_HADOOP_SPARK está definido como true. Executando script de download..."
    if [ ! -f "${DOWNLOAD_SCRIPT_PATH}" ]; then
        log_error "Script de download não encontrado em: ${DOWNLOAD_SCRIPT_PATH}"
    fi

    chmod +x "${DOWNLOAD_SCRIPT_PATH}"
    # Executa o script de download. Se falhar, o log_error dentro dele (se usar set -e) ou aqui tratará.
    if "${DOWNLOAD_SCRIPT_PATH}"; then
        log_info "Script de download concluído com sucesso."
    else
        # O script download.sh já deve ter emitido um erro.
        # A opção 'set -o errexit' fará este script sair se download.sh falhar.
        log_error "O script ${DOWNLOAD_SCRIPT_PATH} falhou. Verifique os logs acima."
    fi
else
    log_info "DOWNLOAD_HADOOP_SPARK não está como 'true'. Pulando execução do script de download."
fi

log_info "Script de inicialização concluído!"
log_info "Você pode agora tentar construir e iniciar o cluster com:"
log_info "${YELLOW_COLOR}docker compose build && docker compose up -d${RESET_COLORS}"
# Ou se você usou perfis:
# log_info "${YELLOW_COLOR}docker compose --profile <profile_name> up -d${RESET_COLORS}"

exit 0

# -----------------------------------------------------------------------------
# Fim do script init.sh
# -----------------------------------------------------------------------------