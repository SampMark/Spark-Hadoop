#!/bin/sh
# -----------------------------------------------------------------------------
# Script de Download para Hadoop e Spark
#
# Descrição:
#   Este script realiza o download dos arquivos binários do Apache Hadoop e
#   Apache Spark com base nas versões especificadas no arquivo .env.
#   Ele também verifica a integridade dos arquivos baixados utilizando
#   checksums SHA512 obtidos diretamente dos sites oficiais do Apache.
#
# Autor: [Marcus V D Sampaio/Organização: IFRN] GitHub: @SampMark
# Versão: 1.1
# Data: 2024-05-07
#
# Uso:
#   Este script é projetado para ser executado dentro de um contêiner Docker
#   como parte de um processo de inicialização, geralmente através do comando:
#   docker compose run --rm init
#   Não deve ser executado diretamente fora desse contexto, a menos que
#   as dependências (como 'aria2c', 'wget') e o arquivo '.env' estejam
#   configurados manualmente.
#
# Requisitos:
#   - sh (POSIX shell)
#   - wget (para baixar arquivos de checksum)
#   - aria2c (para downloads otimizados e verificação de checksum)
#   - Arquivo .env na raiz do projeto contendo:
#     HADOOP_VERSION=x.y.z
#     SPARK_VERSION=a.b.c
#
# Licença: MIT e Apache 2.0
# -----------------------------------------------------------------------------

# --- Configuração de Segurança e Comportamento do Shell ---
# set -o errexit  # Sai imediatamente se um comando falhar (equivalente a set -e)
# set -o nounset  # Trata variáveis não definidas como um erro (equivalente a set -u)
# set -o pipefail # Faz com que o status de saída de um pipeline seja o do último comando que falhou

# --- Definição de Cores para Logs ---
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
YELLOW_COLOR='\033[0;33m'
LIGHTBLUE_COLOR='\033[0;36m'
RESET_COLORS='\033[0m'

# --- Prefixo para Mensagens de Log ---
INFO="[${GREEN_COLOR}INFO${RESET_COLORS}]"
ERROR="[${RED_COLOR}ERROR${RESET_COLORS}]"
WARN="[${YELLOW_COLOR}WARN${RESET_COLORS}]"

# --- Funções de Logging ---
# Padronização da exibição de mensagens.
log_info() { printf "%b %s\n" "${INFO}" "$1"; }
log_warn() { printf "%b %s\n" "${WARN}" "$1"; }
log_error() { printf "%b %s\n" "${ERROR}" "$1"; }

# --- Verificação do Ambiente de Execução ---
# O script espera ser executado por 'docker compose run --rm init'.
# A variável DOCKER_COMPOSE_RUN pode ser definida no Dockerfile do serviço 'init'.
if [ -z "${DOCKER_COMPOSE_RUN}" ]; then
    log_warn "Este script deve ser executado usando: ${YELLOW_COLOR}docker compose run --rm init${RESET_COLORS}"
    log_warn "Se estiver testando localmente, defina a variável DOCKER_COMPOSE_RUN manualmente:"
    log_warn "Ex: ${LIGHTBLUE_COLOR}export DOCKER_COMPOSE_RUN=true && ./download.sh${RESET_COLORS}"
    # exit 1 # Descomente se quiser forçar a saída em caso de execução inadequada
fi

# --- Leitura de Variáveis do Arquivo .env ---
# Verifica a existência do arquivo .env e carrega as versões do Hadoop e Spark.
if [ ! -f ".env" ]; then
    log_error "Arquivo .env não encontrado. Crie um arquivo .env com HADOOP_VERSION e SPARK_VERSION."
    exit 1
fi

# Usar 'grep' e 'cut' para extrair as versões. Alternativamente, poderia usar 'source .env'
# se o formato do .env for garantido e seguro (sem comandos maliciosos).
# Adicionada verificação para garantir que as variáveis foram encontradas e não estão vazias.
HADOOP_VERSION=$(grep '^HADOOP_VERSION=' ".env" | cut -d '=' -f2 | tr -d '[:space:]')
SPARK_VERSION=$(grep '^SPARK_VERSION=' ".env" | cut -d '=' -f2 | tr -d '[:space:]')

if [ -z "${HADOOP_VERSION}" ]; then
    log_error "HADOOP_VERSION não definida ou não encontrada no arquivo .env."
    exit 1
fi
if [ -z "${SPARK_VERSION}" ]; then
    log_error "SPARK_VERSION não definida ou não encontrada no arquivo .env."
    exit 1
fi

log_info "Hadoop Version: ${HADOOP_VERSION}"
log_info "Spark Version: ${SPARK_VERSION}"

# --- Definição de Nomes de Arquivos e URLs ---
# URLs base do Apache para downloads. Podem ser alteradas para mirrors, se necessário.
APACHE_DOWNLOAD_BASE_URL="https://dlcdn.apache.org" # URL oficial de distribuição CDN do Apache
# APACHE_ARCHIVE_BASE_URL="https://archive.apache.org/dist" # URL de arquivamento, pode ser um fallback

HADOOP_FILE="hadoop-${HADOOP_VERSION}.tar.gz"
HADOOP_URL="${APACHE_DOWNLOAD_BASE_URL}/hadoop/core/hadoop-${HADOOP_VERSION}/${HADOOP_FILE}"
HADOOP_SHA_URL="${APACHE_DOWNLOAD_BASE_URL}/hadoop/core/hadoop-${HADOOP_VERSION}/${HADOOP_FILE}.sha512"
# Fallback para checksums, caso a dlcdn não tenha o .sha512 no mesmo path (pode acontecer)
HADOOP_SHA_URL_FALLBACK="https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_FILE}.sha512"


# O nome do arquivo do Spark inclui '-bin-hadoop3', o que sugere compatibilidade com Hadoop 3.x.
# É importante garantir que a versão do Hadoop escolhida seja compatível.
SPARK_DOWNLOAD_PROFILE="bin-hadoop3" # Ex: bin-hadoop3, bin-without-hadoop, etc.
SPARK_FILE="spark-${SPARK_VERSION}-${SPARK_DOWNLOAD_PROFILE}.tgz"
SPARK_URL="${APACHE_DOWNLOAD_BASE_URL}/spark/spark-${SPARK_VERSION}/${SPARK_FILE}"
SPARK_SHA_URL="${APACHE_DOWNLOAD_BASE_URL}/spark/spark-${SPARK_VERSION}/${SPARK_FILE}.sha512"
SPARK_SHA_URL_FALLBACK="https://downloads.apache.org/spark/spark-${SPARK_VERSION}/${SPARK_FILE}.sha512"

# --- Verificação e Instalação de Dependências ---
# Verifica se wget e aria2c estão instalados. Se não, tenta instalá-los (para Alpine Linux).
# Este bloco deve ser executado apenas uma vez.
install_dependencies() {
    log_info "Verificando dependências (wget, aria2c)..."
    NEEDS_INSTALL=""
    if ! command -v wget >/dev/null 2>&1; then
        NEEDS_INSTALL="${NEEDS_INSTALL} wget"
    fi
    if ! command -v aria2c >/dev/null 2>&1; then
        NEEDS_INSTALL="${NEEDS_INSTALL} aria2" # aria2c está no pacote aria2
    fi

    if [ -n "${NEEDS_INSTALL}" ]; then
        log_info "Instalando pacotes necessários:${NEEDS_INSTALL}"
        # Assumindo Alpine Linux (comum em contêineres Docker)
        if command -v apk >/dev/null 2>&1; then
            apk add --no-cache ${NEEDS_INSTALL}
            if [ $? -ne 0 ]; then
                log_error "Falha ao instalar dependências. Verifique sua conexão ou permissões."
                exit 1
            fi
        else
            log_warn "Comando 'apk' não encontrado. Não foi possível instalar dependências automaticamente."
            log_warn "Certifique-se de que 'wget' e 'aria2c' estão instalados."
            # Em outros sistemas, você pode adicionar: apt-get install -y, yum install -y, etc.
        fi
    else
        log_info "Dependências já satisfeitas."
    fi
}

# --- Função para Obter Checksum ---
# Baixa o arquivo .sha512 e extrai o valor do checksum.
# Tenta lidar com os formatos comuns de arquivos de checksum do Apache.
get_checksum() {
    _sha_url="$1"
    _sha_url_fallback="$2" # URL de fallback para o arquivo de checksum
    _target_file_name="$3" # Nome do arquivo principal (ex: hadoop-3.3.6.tar.gz)
    _sha_temp_file="checksum_temp.sha512" # Nome temporário para o arquivo de checksum

    log_info "Obtendo checksum de ${_sha_url} (ou fallback)"

    # Tenta baixar da URL primária
    wget -q --progress=dot:giga -O "${_sha_temp_file}" "${_sha_url}"
    # Opção: --check-certificate=true (RECOMENDADO, mas requer ca-certificates no container)
    # Por padrão, wget em muitos distros já valida certificados. Se falhar, pode ser por
    # falta do bundle de CA-certs no container Alpine (instalar 'ca-certificates').

    if [ $? -ne 0 ] || [ ! -s "${_sha_temp_file}" ]; then # Se falhou ou o arquivo está vazio
        log_warn "Falha ao baixar checksum de ${_sha_url}. Tentando URL de fallback: ${_sha_url_fallback}"
        wget -q --progress=dot:giga -O "${_sha_temp_file}" "${_sha_url_fallback}"
        if [ $? -ne 0 ] || [ ! -s "${_sha_temp_file}" ]; then
            log_error "Falha ao baixar arquivo de checksum de ambas as URLs: ${_sha_temp_file}"
            rm -f "${_sha_temp_file}"
            return 1 # Retorna código de erro
        fi
    fi

    # Extrai o checksum.
    # Formato 1 (comum, ex: `sha512sum -b`): checksum  *filename
    # Formato 2 (às vezes usado pelo Apache): SHA512 (filename) = checksum
    # Formato 3 (às vezes usado pelo Apache): checksum (filename)
    # O grep busca pela linha que contém o nome do arquivo para garantir que pegamos o checksum correto
    # em arquivos .sha512 que podem listar múltiplos arquivos.
    # A busca realizada de forma mais robusta para cobrir variações.
    # Exemplo de linha: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spark-3.5.0-bin-hadoop3.tgz"
    # Ou: "SHA512 (spark-3.5.0-bin-hadoop3.tgz) = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    _checksum_line=$(grep -i "${_target_file_name}" "${_sha_temp_file}")

    if [ -z "${_checksum_line}" ]; then
        log_error "Não foi possível encontrar a linha de checksum para '${_target_file_name}' no arquivo '${_sha_temp_file}'."
        log_info "Conteúdo do arquivo de checksum:"
        cat "${_sha_temp_file}" # Mostra o conteúdo para depuração
        rm -f "${_sha_temp_file}"
        return 1
    fi

    _extracted_checksum=""
    # Tenta extrair o checksum (primeira palavra da linha se não for o formato "SHA512 (...) =")
    _extracted_checksum=$(echo "${_checksum_line}" | awk '{print $1}')

    # Se a linha contém "=", é provável que seja o formato "SHA512 (...) = checksum"
    if echo "${_checksum_line}" | grep -q '='; then
        _extracted_checksum=$(echo "${_checksum_line}" | awk -F'=' '{print $2}' | tr -d '[:space:]')
    fi

    # Remove espaços em branco e converte para minúsculas para consistência.
    _final_checksum=$(echo "${_extracted_checksum}" | tr -d '[:space:]' | tr 'A-F' 'a-f')

    if [ -z "${_final_checksum}" ] || [ ${#_final_checksum} -ne 128 ]; then # SHA512 tem 128 caracteres hex
        log_error "Checksum extraído inválido ou não encontrado para ${_target_file_name}."
        log_info "Linha do Checksum: ${_checksum_line}"
        log_info "Checksum Extraído: ${_final_checksum}"
        rm -f "${_sha_temp_file}"
        return 1
    fi

    rm -f "${_sha_temp_file}" # Limpa o arquivo temporário
    echo "${_final_checksum}" # Retorna o checksum
    return 0
}

# --- Função para Download com Verificação de Checksum ---
# Utiliza aria2c para baixar o arquivo e verificar o checksum SHA512.
download_with_checksum() {
    _filename="$1"
    _url="$2"
    _sha_url="$3"
    _sha_url_fallback="$4"

    log_info "Iniciando download de ${_filename} de ${_url}"

    # Obtém o checksum esperado
    _expected_checksum=$(get_checksum "${_sha_url}" "${_sha_url_fallback}" "${_filename}")
    if [ $? -ne 0 ] || [ -z "${_expected_checksum}" ]; then
        log_error "Não foi possível obter o checksum para ${_filename}. Download cancelado."
        # exit 1 # Considerar sair se o checksum não puder ser obtido
        return 1 # Retorna código de erro para a função chamadora decidir
    fi
    log_info "Checksum SHA512 esperado para ${_filename}: ${_expected_checksum}"

    # Opções do aria2c:
    # -x 6: Número máximo de conexões por servidor.
    # -s 6: Divide o download em N partes.
    # --disable-ipv6: Desabilita IPv6 se causar problemas.
    # --file-allocation=none: Evita pré-alocação de espaço, útil em alguns sistemas de arquivos.
    # --allow-overwrite=true: Permite sobrescrever o arquivo se já existir (embora o script já verifique isso).
    # --check-certificate=false: DESABILITA a verificação de certificado SSL.
    #   RECOMENDAÇÃO: Mudar para true e garantir que os certificados CA estão no contêiner.
    #   Para Alpine, adicione 'ca-certificates' ao apk add.
    # --checksum=sha-512=<checksum>: Verifica o arquivo baixado contra o checksum fornecido.
    aria2c -x 6 -s 6 \
        --disable-ipv6 \
        --file-allocation=none \
        --allow-overwrite=true \
        --check-certificate=false \
        --checksum=sha-512="${_expected_checksum}" \
        --out="${_filename}" \
        "${_url}"

    if [ $? -ne 0 ]; then
        log_error "Download ou verificação de checksum falhou para ${_filename}."
        # Tenta limpar o arquivo parcialmente baixado para evitar problemas na próxima execução
        if [ -f "${_filename}" ]; then
            log_info "Removendo arquivo parcialmente baixado ou corrompido: ${_filename}"
            rm -f "${_filename}"
        fi
        # exit 1 # Considerar sair em caso de falha no download
        return 1
    fi

    log_info "Download de ${_filename} concluído e verificado com sucesso."
    return 0
}

# --- Rotina Principal ---

# 1. Instalar dependências (se necessário)
install_dependencies

# 2. Download do Apache Hadoop
log_info "--- Processando Apache Hadoop ---"
if [ -f "${HADOOP_FILE}" ]; then
    log_info "Arquivo ${HADOOP_FILE} já existe. Pulando download."
    # Opcional: Adicionar verificação de checksum para arquivos existentes também.
else
    download_with_checksum "${HADOOP_FILE}" "${HADOOP_URL}" "${HADOOP_SHA_URL}" "${HADOOP_SHA_URL_FALLBACK}"
    if [ $? -ne 0 ]; then
        log_error "Falha crítica no download do Hadoop. Abortando."
        exit 1
    fi
fi

# 3. Download do Apache Spark
log_info "--- Processando Apache Spark ---"
if [ -f "${SPARK_FILE}" ]; then
    log_info "Arquivo ${SPARK_FILE} já existe. Pulando download."
else
    download_with_checksum "${SPARK_FILE}" "${SPARK_URL}" "${SPARK_SHA_URL}" "${SPARK_SHA_URL_FALLBACK}"
    if [ $? -ne 0 ]; then
        log_error "Falha crítica no download do Spark. Abortando."
        exit 1
    fi
fi

# 4. Ajustar Permissões dos Arquivos Baixados (Opcional, mas útil em Docker)
# Tenta mudar o proprietário para uid 1000, gid 1000.
# O '2>/dev/null || true' evita que o script falhe se o chown não for permitido
# (por exemplo, se executado como não-root ou se o usuário/grupo não existir).
log_info "Ajustando permissões dos arquivos baixados (tentando chown 1000:1000)..."
if [ -f "${HADOOP_FILE}" ] && [ -f "${SPARK_FILE}" ]; then
    chown 1000:1000 "${HADOOP_FILE}" "${SPARK_FILE}" 2>/dev/null || \
        log_warn "Não foi possível alterar o proprietário dos arquivos. Isso pode ser normal se não executado como root."
else
    log_warn "Um ou ambos os arquivos (${HADOOP_FILE}, ${SPARK_FILE}) não foram encontrados para ajuste de permissões."
fi

log_info "Script de download concluído com sucesso!"
exit 0
# --- Fim do Script ---
# Nota: Este script é projetado para ser executado em um ambiente controlado
# (como um contêiner Docker) e pode precisar de ajustes se for executado fora desse contexto.
# Certifique-se de que as dependências estão instaladas e o ambiente está configurado corretamente.
# Recomenda-se testar o script em um ambiente de desenvolvimento antes de usá-lo em produção.
# -----------------------------------------------------------------------------
# Fim do script
# -----------------------------------------------------------------------------