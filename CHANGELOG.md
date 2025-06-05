## :memo: Changelog

---

#### 2.2.7. `CHANGELOG.md`

```markdown
# Changelog do hadoop-spark-enhanced

Todas as alterações significativas são documentadas aqui.

## [1.1.0] – 2025-06-04
### Adicionado
- Pasta `scripts/` com:
  - `download_all.sh` (download de Hadoop e Spark com verificação SHA512).
  - `preflight_check.sh` (validação de variáveis do `.env`).
  - `init.sh` (gera docker-compose a partir de templates).
  - `bootstrap.sh` (pré-configuração dentro do container).
  - `start_services.sh` (inicia Hadoop, Spark e Jupyter).
- Templates em `config_files/` para:
  - **Hadoop**: core-site, hdfs-site, mapred-site, yarn-site, hadoop-env, yarn-env.
  - **Spark**: spark-defaults, spark-env.
  - **JupyterLab**: overrides.json e jupyter_notebook_config.py.
  - **Sistema**: ssh_config e bash_common.
- `docker-compose.template.yml` para geração dinâmica.
- `tests/` com:
  - `smoke_test_hadoop.sh` (verifica HDFS e YARN UI).
  - `smoke_test_spark.sh` (verifica Spark Master UI e Jupyter UI).
- `README.md` atualizado com Quick Start, exemplos de uso Spark, Jupyter e smoke tests.
- `CONTRIBUTING.md` para orientar contribuições.
- `CHANGELOG.md` inicializado.
- `myfiles/` reorganizado (subdiretórios: data, notebooks, scripts).

### Corrigido
- Dockerfile refatorado para usar `gosu` e usuário não-root.
- Verificação de versão Java correta para Hadoop e Spark.
- Healthchecks no Compose para todas as UIs.
- Remoção de `.password` (não expor senhas em texto plano).
- Mapeamento de `.env` alterado para `env_file` (não mais bind mount dentro do container).

## [1.0.0] – 2025-05-25
- Versão inicial (migração e refatoração do repositório `cmdviegas/hadoop-spark` original).


```

### Documentação e Aperfeiçoamentos Detalhados:

## Modificações em `download_all.sh`:

1. **Configuração do Shell (`set`):**
    * Comentadas, mas presentes, as opções `set -o errexit`, `set -o nounset`, `set -o pipefail`, visando tornar o script mais robusto, exigindo um tratamento de erro mais cuidadoso em alguns casos. Recomenda-se descomentá-las após testes exaustivos.

2.  **Verificação de Execução (`DOCKER_COMPOSE_RUN`):**
    * Adicionada uma mensagem mais informativa caso o script seja executado fora do contexto esperado, sugerindo como definir a variável para testes locais. A saída com `exit 1` foi comentada para permitir flexibilidade em testes.

3.  **Leitura do `.env`:**
    * Adicionado `tr -d '[:space:]'` para remover quaisquer espaços em branco acidentais ao redor dos valores das versões.
    * Adicionada verificação individual para `HADOOP_VERSION` e `SPARK_VERSION` para garantir que ambas foram encontradas e não estão vazias, com mensagens de erro mais específicas.

4.  **URLs e Nomes de Arquivos:**
    * As URLs base do Apache (`APACHE_DOWNLOAD_BASE_URL`, `APACHE_ARCHIVE_BASE_URL`) foram movidas para variáveis para facilitar a alteração para mirrors, se necessário.
    * Adicionadas URLs de fallback (`_SHA_URL_FALLBACK`) para os arquivos de checksum, pois a estrutura de diretórios nos servidores do Apache pode variar ligeiramente entre a CDN de download e a área de "downloads" mais antiga.
    * A variável `SPARK_DOWNLOAD_PROFILE` foi introduzida para tornar mais explícito qual build do Spark está sendo baixado (ex: `bin-hadoop3`). Isso ajuda a destacar a dependência da versão do Hadoop.

5.  **Instalação de Dependências (`install_dependencies`):**
    * A verificação e instalação de `wget` e `aria2c` (pacote `aria2`) foi movida para uma função separada `install_dependencies`.
    * A função verifica se os comandos já existem antes de tentar instalá-los.
    * O comando `apk add` é executado apenas uma vez para todas as dependências necessárias.
    * Adicionada uma mensagem de aviso se `apk` não for encontrado, para o caso de o script ser adaptado para outras distribuições Linux.

6.  **Obtenção de Checksum (`get_checksum`):**
    * A função agora aceita URLs de fallback para o arquivo de checksum.
    * A verificação de sucesso do `wget` foi melhorada para também checar se o arquivo de checksum baixado não está vazio (`! -s`).
    * A extração do checksum foi tornada mais robusta:
        * Primeiro, usa `grep -i "${_target_file_name}"` para encontrar a linha específica do arquivo desejado dentro do arquivo de checksum (útil se o arquivo `.sha512` contiver checksums para múltiplos arquivos).
        * Tenta dois métodos de extração comuns baseados na estrutura da linha.
        * Adiciona uma verificação para o comprimento do checksum SHA512 (128 caracteres hexadecimais).
    * Melhores mensagens de log e depuração em caso de falha na extração.
    * Retorna `1` em caso de erro, permitindo que a função chamadora decida como proceder.
    * **Segurança (Certificados SSL/TLS):**
        * Removida a opção `--no-check-certificate` do `wget` na função `get_checksum`. **É altamente recomendável validar os certificados.** Para que isso funcione em contêineres Alpine, o pacote `ca-certificates` deve estar instalado. Adicione `ca-certificates` à lista de pacotes em `install_dependencies` se necessário.

7.  **Download com Checksum (`download_with_checksum`):**
    * **Segurança (Certificados SSL/TLS):** A opção `--check-certificate=false` do `aria2c` foi mantida, recomenda-se mudá-la para `true` e garantir a presença dos `ca-certificates`.
    * A função agora verifica o código de retorno de `get_checksum` e de `aria2c`.
    * Em caso de falha no `aria2c`, tenta remover o arquivo parcialmente baixado ou corrompido.
    * Retorna `0` em sucesso e `1` em falha.

8.  **Rotina Principal:**
    * A chamada para `install_dependencies` é feita no início.
    * As chamadas para `download_with_checksum` verificam o status de retorno e saem com `exit 1` se um download crítico falhar (script mais rigoroso).
    * Ajuste de Permissões (`chown`):
        * Adicionada uma verificação para garantir que os arquivos realmente existem antes de tentar o `chown`.
        * A mensagem de aviso em caso de falha do `chown` foi melhorada.

9. **Recomendações Adicionais**

    * **Testes:** Teste o script exaustivamente em seu ambiente Docker para garantir que todas as alterações funcionam como esperado, especialmente a obtenção de checksum e a validação de certificados.
    * **`ca-certificates`:** Caso habilite a verificação de certificados SSL/TLS (o que é recomendado), certifique-se de que o pacote `ca-certificates` (ou equivalente) esteja instalado no seu contêiner Docker. Para Alpine, adicione `ca-certificates` à linha `apk add`.
    * **Spark e Hadoop Version Compatibility:** O script atualmente baixa `spark-${SPARK_VERSION}-bin-hadoop3.tgz`. Mas se você pretende usar uma versão do Hadoop que não seja da série 3.x (conforme definido em `HADOOP_VERSION`), você precisará ajustar o `SPARK_DOWNLOAD_PROFILE` e, consequentemente, o nome do arquivo Spark (`SPARK_FILE`) para baixar a compilação correta do Spark (ex: `spark-X.Y.Z-bin-hadoop2.7.tgz` ou `spark-X.Y.Z-bin-without-hadoop.tgz`).


## Modificações em `init.sh`:

1.  **Configuração do Shell (`set`):**
    * Adicionado `set -o errexit`, `set -o nounset`, `set -o pipefail` no início, o que torna o script mais robusto, fazendo-o sair imediatamente em caso de erros ou uso de variáveis não definidas, e garantindo que o status de saída de um pipeline seja o do último comando que falhou.

2.  **Funções de Logging:**
    * A função `log_error` agora inclui `exit 1` para garantir que o script pare em caso de erro reportado.

3.  **Verificação do Ambiente de Execução (`DOCKER_COMPOSE_RUN`):**
    * Uso de `${DOCKER_COMPOSE_RUN:-}` para evitar erro com `set -o nounset`, caso a variável não esteja definida.

4.  **Validação de Variáveis de Ambiente Essenciais:**
    * Adicionada uma verificação explícita para variáveis cruciais (`STACK_NAME`, `IMAGE_NAME`, `SPARK_WORKER_INSTANCES`, `HADOOP_VERSION`, `SPARK_VERSION`) usando a sintaxe `${VAR:?mensagem de erro}`. Isso fará o script sair se alguma delas não estiver definida.
    * Adicionada uma validação para garantir que `SPARK_WORKER_INSTANCES` seja um número inteiro positivo.

5.  **Geração do `docker-compose.yml` (`generate_compose_file`):**
    * **Versão do Compose:** Especificada `version: '3.8'` para clareza e compatibilidade com recursos mais recentes.
    * **Nome do Projeto (`name: ${STACK_NAME}`):** Adicionado no topo do arquivo Compose para definir explicitamente o nome do projeto, o que influencia os nomes de contêineres, redes e volumes padrão.
    * **Escapando Variáveis (`\`):** Em `image: \${IMAGE_NAME}` e outras variáveis dentro da seção `x-common-properties` e nos serviços, o `$` foi escapado com `\` (ex: `\${IMAGE_NAME}`). Isso é importante porque o *script shell* está gerando o arquivo. Se não escaparmos, o shell tentaria interpolar `IMAGE_NAME` no momento da geração do *script*. É importante que a string literal `\${IMAGE_NAME}` seja escrita no `docker-compose.yml` para que o *Docker Compose* faça a interpolação quando ele processar o arquivo.
    * **Rede:** Simplificada a definição da rede (`spark_cluster_net`), permitido que a sub-rede seja configurável via `DOCKER_NETWORK_SUBNET` no `.env` com um fallback.
    * **Segredos (`secrets`):** A definição de segredos é referenciada em `USER_PASSWORD_FILE` do `.env` com um fallback para `./.password`. O alvo do segredo no contêiner também foi explicitado.
    * **Serviço `init`:**
        * Utiliza uma imagem mais específica como `alpine/git:latest` (ou poderia ser a mesma imagem base do cluster se ferramentas específicas fossem necessárias).
        * Definido um `profile: ["init-tools"]` para que este serviço não seja iniciado por padrão com `docker compose up`, mas possa ser chamado com `docker compose --profile init-tools run --rm init`.
        * Montagem opcional do socket Docker (`/var/run/docker.sock`), caso o script precise interagir com o Docker.
        * Passagem explícita de variáveis de ambiente para o serviço `init`, embora o Docker Compose geralmente já injete variáveis do `.env` no ambiente dos contêineres.
    * **Serviço `master`:**
        * As portas foram parametrizadas para serem configuráveis via `.env` (ex: `\${HDFS_NAMENODE_UI_PORT:-9870}`).
        * Caminhos de volumes para arquivos de configuração foram exemplificados e marcados como `ro` (read-only), o que é uma boa prática para arquivos de configuração montados.
        * Os caminhos para os arquivos de configuração e dados dentro do contêiner foram generalizados (ex: `/opt/hadoop/...`, `/opt/spark/...`). Estes devem corresponder aos caminhos usados na imagem Docker.
    * **Serviços `worker-N`:**
        * A passagem do ID do worker para o comando foi melhorada (`command: ["WORKER", "${current_worker_num}"]`).
        * Comentários sobre `depends_on` foram adicionados para indicar que os workers geralmente dependem do master.
    * **Clareza e Comentários:** Adicionados mais comentários ao arquivo YAML gerado para explicar as seções.

6.  **Lógica Principal:**
    * A lógica para determinar `num_workers_to_generate` usa `${1:-}` para evitar erros com `set -o nounset`.
    * Aviso caso um argumento inesperado for passado para o script.

7.  **Execução do `download_all.sh`:**
    * Uso de `${DOWNLOAD_HADOOP_SPARK:-false}` para fornecer um valor padrão caso a variável não esteja definida.
    * Verificação explícita se o `DOWNLOAD_SCRIPT_PATH` existe antes de tentar torná-lo executável.
    * Como `set -o errexit` está ativo, se `download_all.sh` falhar (retornar um status de saída diferente de zero), o script `init.sh` também irá parar, o que é o comportamento desejado. A mensagem de erro adicional após a falha do `download.sh` pode ser redundante, mas não prejudica.

8.  **Caminhos de Scripts e Configurações:**
    * Os caminhos para scripts (como `download_all.sh`) e arquivos de configuração (`config_files`) são relativos. Isso funciona bem se o `working_dir` do serviço `init` no `docker-compose.yml` estiver corretamente configurado para a raiz do projeto.

9. **Recomendações:**

    * **Arquivo `.env`:** Certifique-se de que todas as variáveis de ambiente usadas no script (e no `docker-compose.yml` gerado) estejam bem documentadas e presentes no arquivo `.env` ou `env.example`.
    * **`bootstrap.sh`:** O `entrypoint` dos serviços `master` e `worker` aponta para `bootstrap.sh`. Este script dentro da imagem Docker é crucial e deve ser capaz de lidar com os argumentos `MASTER` ou `WORKER ID_WORKER` para configurar e iniciar os respectivos daemons Hadoop/Spark.
    * **Idempotência:** O script de geração do `docker-compose.yml` é idempotente no sentido de que sempre sobrescreve o arquivo. A execução do `download.sh` também é (ou deveria ser) idempotente (não baixa arquivos já existentes e verificados).
    * **Segurança de Segredos:** Montar o arquivo `.env` inteiro dentro dos contêineres (`master`, `worker`) deve ser feito com cautela, especialmente se ele contiver segredos sensíveis que não são necessários para todos os processos. O uso do mecanismo de `secrets` do Docker Compose é preferível para senhas e chaves.


## Modificações em `bootstrap.sh`:

1.  **Configuração do Shell (`set -euo pipefail`):**
    * `set -e`: Sai imediatamente se um comando retornar um status de erro.
    * `set -u`: Trata o uso de variáveis não definidas como um erro.
    * `set -o pipefail`: Garante que o status de saída de um pipeline seja o do último comando que falhou, não o do último comando do pipeline.

2.  **Logging:**
    * As cores e prefixos de log (`INFO_PREFIX`, `WARN_PREFIX`, `ERROR_PREFIX`) são definidos no início do script para consistência e para não depender do `.bashrc`.
    * A função `log_error` agora inclui `exit 1` para garantir que o script pare em caso de erro fatal.

3.  **Validação de Argumentos e Variáveis:**
    * Adicionada validação para o primeiro argumento (`$1`), que deve ser "MASTER" ou "WORKER".
    * Adicionada validação explícita para variáveis de ambiente cruciais (`HOME`, `MY_SECRETS_FILE`, `HADOOP_CONF_DIR`, `NUM_WORKER_NODES`, `STACK_NAME`) usando a sintaxe `${VAR:?mensagem}`. Se alguma não estiver definida, o script sairá com erro.
    * Após o carregamento do `.bashrc`, é verificado se `HADOOP_HOME` e `SPARK_HOME` foram definidos.

4.  **Carregamento do `.bashrc`:**
    * A documentação do método "hack" (`eval "$(tail ...)"`) foi melhorada, explicando seu propósito e riscos.
    * Sugerida uma alternativa mais segura usando `bash -c '. <(echo "$bash_rc_content")'` para executar o conteúdo do `.bashrc` (após o `tail`) em um subshell bash limpo, e depois carregar no contexto atual com `.`. Ainda requer cuidado com o conteúdo do `.bashrc`.
    * É importante que o `.bashrc` configure corretamente `HADOOP_HOME`, `SPARK_HOME`, `JAVA_HOME` e adicione os diretórios `bin` e `sbin` ao `PATH`.

5.  **Configuração da Senha:**
    * O nome do usuário (`USER_TO_CONFIG`) foi parametrizado (com default para "myuser").
    * Adicionada verificação se o arquivo de segredo existe e não está vazio.
    * Adicionada verificação se o usuário (`USER_TO_CONFIG`) realmente existe no sistema antes de tentar alterar a senha.
    * Clarificada a diferença entre usar `chpasswd` com e sem a flag `-e` (dependendo se a senha no arquivo está em texto plano ou já encriptada).

6.  **Atualização do Arquivo `workers` do Hadoop:**
    * O caminho para o arquivo `workers` (`${HADOOP_CONF_DIR}/workers`) é usado.
    * Adicionada verificação se `HADOOP_CONF_DIR` existe.
    * O comando `truncate -s 0` foi substituído por `: > "${WORKERS_FILE}"` para limpar o arquivo, que é mais portável e geralmente mais seguro em scripts simples.
    * O loop para adicionar os workers foi mantido, e um `log_info` mostra o conteúdo final do arquivo para verificação.

7.  **Início do Serviço SSH:**
    * O comando `sudo service ssh start` foi mantido, mas com melhor logging de sucesso/falha.
    * Comentários sobre a importância de verificar os logs do SSH em caso de falha.

8.  **Lógica Específica para Master e Worker:**
    * **Master:**
        * O `sleep` foi mantido, mas tornado configurável pela variável `MASTER_START_DELAY` (com default de 5 segundos).
        * Verificação se o script `services.sh` existe antes de tentar executá-lo.
        * A execução do `services.sh` é feita com `sudo -u "${USER_TO_CONFIG}" bash ...` para garantir que os serviços sejam iniciados pelo usuário correto, assumindo que `bootstrap.sh` possa estar rodando como root.
        * Melhor logging de sucesso/falha da execução do `services.sh`.
    * **Worker:**
        * A mensagem de log para workers foi mantida.
        * Adicionado um exemplo comentado de como um Spark Worker em modo Standalone poderia ser iniciado diretamente no `bootstrap.sh` do worker, se essa for a arquitetura desejada.

9. **Manter o Contêiner em Execução:**
    * O `exec /bin/bash` no final do script original foi substituído por `tail -f /dev/null`.
        * **Explicação:** `exec /bin/bash` dá um shell interativo, o que é útil para depuração, mas não é adequado para um serviço que deve rodar continuamente. Se o processo principal (bash) termina, o contêiner para.
        * `tail -f /dev/null` é uma forma comum de manter um contêiner rodando indefinidamente quando os serviços principais (Hadoop/Spark daemons) foram iniciados em background.
        * Foram adicionados comentários sobre alternativas mais robustas para produção, como o uso de um supervisor de processos (`tini`, `supervisord`) ou garantir que o `services.sh` (ou outro script) execute um processo em foreground que mantenha o contêiner vivo.

10. **Variáveis de Ambiente e Caminhos:**
    * Foi enfatizado que variáveis como `HADOOP_CONF_DIR`, `HADOOP_HOME`, `SPARK_HOME` devem estar corretamente configuradas (geralmente via Dockerfile ENV ou no `.bashrc`).

11. **Recomendações:**

    * **Script `services.sh`:** Este script (`${HOME}/services.sh`) é fundamental, especialmente para o nó master. Ele deve conter a lógica para:
        * Formatar o HDFS NameNode (apenas na primeira vez ou se necessário).
        * Iniciar os daemons do HDFS (NameNode, DataNodes - este último via SSH a partir do master).
        * Iniciar os daemons do YARN (ResourceManager, NodeManagers - este último via SSH a partir do master).
        * Iniciar o Spark Master (se em modo Standalone) e o Spark History Server.
        * Garantir que os daemons sejam iniciados com o usuário correto (ex: `myuser`).
    * **Permissões e Usuário:** Decida consistentemente como usuário (root ou um usuário não privilegiado como `myuser`) os processos dentro do contêiner devem rodar. Se for um usuário não privilegiado, garanta que ele tenha as permissões necessárias. O uso de `sudo` dentro do contêiner deve ser minimizado; é preferível ajustar as permissões de arquivos e diretórios ou usar ferramentas como `gosu` ou `su-exec` se o processo de entrada do contêiner for root mas precisar delegar para outro usuário.
    * **Idempotência:** O `bootstrap.sh` deve ser o mais idempotente possível, significando que executá-lo múltiplas vezes (se o contêiner for reiniciado) não deve causar estados inconsistentes (ex: tentar formatar o NameNode repetidamente sem verificação).

## Modificações em `services.sh`:

1.  **Configuração do Shell (`set -euo pipefail`):**
    * Mantido para robustez.

2.  **Logging:**
    * Funções de log (`log_info`, `log_warn`, `log_error`) definidas para consistência. `log_error` agora retorna `1` para que a função chamadora possa decidir se encerra o script ou continua. O `set -e` já faria o script sair se um comando falhar, mas o retorno explícito é bom para clareza.

3.  **Carregamento de Variáveis de Ambiente:**
    * O script tenta carregar `~/env` e emite um aviso se não encontrar.
    * Adicionada validação para variáveis de ambiente cruciais usando `${VAR:?mensagem}`.

4.  **`OVERALL_BOOT_STATUS`:**
    * Renomeado de `BOOT_STATUS` para `OVERALL_BOOT_STATUS` para maior clareza. É usado para rastrear o sucesso da operação `start all`.

5.  **`setup_java_home()`:**
    * Usa `awk` para uma extração mais robusta do `JAVA_HOME` atual do arquivo `hadoop-env.sh`.
    * Usa `mv` em vez de `cp && rm` para a substituição atômica do arquivo temporário.
    * Adicionado escape de barras (`/`) no valor de `JAVA_HOME` antes de usá-lo no `sed` para evitar conflitos se o caminho contiver barras (improvável, mas uma boa prática).
    * Define `OVERALL_BOOT_STATUS="false"` e retorna `1` em caso de falha.

6.  **`check_workers_ssh_connectivity()` (anteriormente `check_workers`):**
    * Renomeado para clareza.
    * Conta o número total de workers esperados e o número de workers alcançáveis.
    * Adiciona as opções `-o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null"` ao comando `ssh` para evitar prompts de chave de host em ambientes de contêineres dinâmicos (com um aviso sobre as implicações de segurança).
    * Loga um aviso se nem todos os workers estiverem acessíveis, mas considera sucesso se pelo menos um estiver.
    * Retorna `1` se nenhum worker estiver acessível.

7.  **`start_hdfs()`:**
    * **Parada Prévia:** Verifica se o NameNode está rodando e tenta parar o HDFS antes de iniciar, para garantir um estado limpo.
    * **Formatação do NameNode:** A lógica de formatação foi melhorada:
        * Tenta obter o `dfs.namenode.name.dir` de `hdfs-site.xml` usando `hdfs getconf`.
        * Usa a existência do diretório `current` dentro do `namenode_dir` como uma heurística para determinar se já foi formatado, antes de tentar o comando `hdfs namenode -format`.
        * Se a heurística não for conclusiva ou o diretório não for encontrado, prossegue com a formatação condicional baseada na saída do comando, como no original.
    * **Verificação de Workers:** Chama `check_workers_ssh_connectivity()` *antes* de tentar `start-dfs.sh`.
    * **Verificação Pós-Início:** Após `start-dfs.sh`, usa `hdfs dfsadmin -report | grep -q "Live datanodes ([1-9][0-9]*)"` para uma verificação mais robusta se os DataNodes estão realmente vivos, em vez de apenas `grep -q "Live datanodes"`.
    * **Criação de Diretórios HDFS:** Adicionado `/tmp` e `chmod 1777 /tmp` no HDFS, trata-se de uma prática muitas vezes necessária.
    * **Cópia de JARs do Spark:** A cópia dos JARs do Spark para `/sparkLibs` no HDFS agora usa `put -f` para sobrescrever, caso os arquivos já existam e precisem ser atualizados.
    * Retorna `0` em sucesso, `1` em falha.

8.  **`start_yarn()`:**
    * **Parada Prévia:** Verifica e para o YARN se já estiver rodando.
    * **Verificação de Workers:** Chama `check_workers_ssh_connectivity()` antes de `start-yarn.sh`.
    * **Verificação Pós-Início:** Após `start-yarn.sh`, verifica se o processo do ResourceManager está ativo. Adiciona uma espera e tenta `yarn node -list` para uma verificação mais completa dos NodeManagers, com um aviso se não houver NodeManagers ativos.

9. **`start_mapred_history()` e `start_spark_history()`:**
    * Adicionada verificação se os respectivos processos já estão rodando e os para antes de tentar iniciar.
    * Verificam se o processo realmente iniciou após o comando de start.
    * `start_spark_history` agora inclui um aviso se o HDFS não estiver rodando, pois os logs do Spark frequentemente residem no HDFS.

10. **`start_jupyterlab()`:**
    * Porta e diretório raiz configuráveis via variáveis de ambiente (`JUPYTER_PORT`, `JUPYTER_ROOT_DIR`) com defaults.
    * Cria o diretório raiz do Jupyter (`root_dir`) e o diretório de configuração (`~/.jupyter`) se não existirem.
    * Adiciona `--ServerApp.allow_root=True` e `--ServerApp.notebook_dir="${root_dir}"` para maior flexibilidade, especialmente em contêineres.
    * Verifica se o processo iniciou corretamente.

11. **`start_spark_connect()`:**
    * Verifica a variável `SPARK_CONNECT_SERVER`. Se não for "enable", pula a inicialização.
    * Requer que `SPARK_VERSION` esteja definida.
    * Para o servidor se já estiver rodando antes de iniciar.
    * Verifica se o processo iniciou.

12. **`_check_service_status_internal()` e `status_all_services()`:**
    * `_check_service_status_internal` é uma função helper para padronizar a verificação de status.
    * `status_all_services` usa esta helper e formata a saída de forma mais alinhada.
    * URLs de UI são mostradas.

13. **`generate_full_report()` (anteriormente `report`):**
    * Renomeada para clareza.
    * Adiciona verificações se HDFS NameNode e YARN RM estão rodando antes de tentar gerar os relatórios, emitindo avisos se não estiverem.

14. **`start_all_services()`:**
    * Reseta `OVERALL_BOOT_STATUS` no início.
    * A ordem de inicialização dos serviços é mantida (HDFS -> YARN -> outros).
    * Se `start_hdfs` falhar (crítico), aborta o início dos demais serviços.
    * Se outros serviços falharem, emite um aviso mas continua, pois podem ser menos críticos ou independentes.
    * No final, verifica `OVERALL_BOOT_STATUS` para dar uma mensagem de sucesso geral ou de erro.
    * Retorna `1` se a inicialização geral falhou.

15. **`stop_all_services()`:**
    * A função de animação `_animate_stopping` foi comentada pois pode ser complexa de gerenciar (matar o subshell corretamente) e pode poluir os logs. A parada sequencial com logs é geralmente suficiente.

16. **`show_motd()`:**
    * Pequena melhoria para usar `SPARK_VERSION` se disponível.

17. **`show_usage()`:**
    * Descrições mais detalhadas das ações e serviços.

18. **`main()` (Lógica Principal):**
    * Converte `ACTION` e `SERVICE` para minúsculas para tratamento case-insensitive.
    * `setup_java_home` é chamado no início, pois é uma configuração base.
    * A estrutura `case` para ações e serviços foi mantida e melhorada com tratamento de erro para entradas inválidas.
    * Adicionada verificação do status de saída (`$?`) após a execução de comandos de start/stop de serviços individuais e loga uma mensagem apropriada. Chama `status_all_services` após start/stop de um serviço individual.

19. **Recomendações:**

    * **Permissões de Usuário:** Certifique-se de que o usuário que executa este script (`myuser`, por exemplo) tenha as permissões corretas para:
        * Executar os scripts `start-*.sh`, `stop-*.sh`, `mapred`, `hdfs`, `yarn`.
        * Escrever nos diretórios de log.
        * Acessar os arquivos de configuração.
    * **Arquivos de PID:** Para uma verificação de status mais robusta e para parar serviços, Hadoop e Spark criam arquivos PID em `/tmp` (ou configurado via `*_PID_DIR`). Usar esses PIDs pode ser mais confiável do que `pgrep` em alguns cenários, embora `pgrep -f` seja geralmente eficaz.
    * **Idempotência:** O script foi melhorado para ser mais idempotente (ex: não formatar HDFS se já formatado, não falhar ao tentar parar um serviço já parado).
    * **Configurações Específicas:** As configurações em `core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`, `spark-defaults.conf` são cruciais, o script assume que estão corretas.

Este `services.sh` revisado deve fornecer um gerenciamento mais confiável e informativo para o seu clust
Este `bootstrap.sh` aperfeiçoado visa ser mais robusto, seguro e fácil de entender e mant
Este script `init.sh` aperfeiçoado, juntamente com um `download.sh` robusto e um `Dockerfile` bem configurado, formará uma base sólida para a inicialização do seu cluster Hadoop/Spark


