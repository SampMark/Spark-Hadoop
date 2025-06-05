# coding: utf-8
# -----------------------------------------------------------------------------
# Arquivo de Configuração do Servidor Jupyter Notebook (jupyter_notebook_config.py)
#
# Descrição:
#   Este arquivo é usado para configurar o servidor Jupyter Notebook.
#   Para JupyterLab, muitas dessas configurações também são relevantes, pois o
#   JupyterLab geralmente roda sobre um servidor Jupyter.
#   Para criar este arquivo, você pode executar: jupyter notebook --generate-config
#   Ele será criado em ~/.jupyter/jupyter_notebook_config.py
#
#   As configurações são definidas atribuindo valores a `c.ClasseDeConfiguracao.atributo`.
#
# -----------------------------------------------------------------------------

# Importa a classe de configuração base
from jupyter_server_config import ServerApp # Para Jupyter Server >= 2.0
# Ou para Jupyter Notebook clássico ou Jupyter Server < 2.0:
# from notebook.auth import passwd # Para gerar hash de senha

# c = get_config() # Obtém o objeto de configuração global (geralmente não é mais necessário definir explicitamente)

# === Configurações de Rede ===

# c.ServerApp.ip = 'localhost'
# [PT-BR] O endereço IP ao qual o servidor deve escutar.
#   - 'localhost': Apenas acessível da máquina local.
#   - '0.0.0.0' ou '': Escuta em todas as interfaces de rede disponíveis,
#                      permitindo acesso de outras máquinas na rede (útil para Docker/VMs).
#   - Um IP específico: Escuta apenas nesse IP.
# Se você definiu `spark.driver.bindAddress = 0.0.0.0` no seu spark-defaults.conf
# para o JupyterLab (que pode ser servido pelo driver Spark em alguns setups ou
# ser um serviço separado), pode querer consistência aqui.
# No seu overrides.json, não há uma configuração direta para o IP do servidor Jupyter,
# mas se o JupyterLab estiver acessível remotamente, esta configuração é crucial.
c.ServerApp.ip = '0.0.0.0'

# c.ServerApp.port = 8888
# [PT-BR] A porta na qual o servidor Jupyter irá escutar.
# O padrão é 8888. Se esta porta estiver em uso, o Jupyter tentará a próxima disponível.
# Seu `overrides.json` não especifica a porta do servidor, mas sim a porta do
# terminal (`fontSize: 16` é para o terminal, não relacionado à porta do servidor).
# O `spark-defaults.conf` mencionava `spark.history.ui.port = 18080` e `spark.connect.server.port = 15002`.
# Certifique-se de que a porta 8888 não entre em conflito se todos rodarem na mesma máquina.
c.ServerApp.port = 8888

# c.ServerApp.open_browser = True
# [PT-BR] Se `True`, tenta abrir o Jupyter Notebook/Lab automaticamente no navegador padrão
# ao iniciar o servidor.
# Pode ser útil desabilitar (`False`) se você estiver rodando o servidor em uma máquina remota
# ou dentro de um contêiner Docker e acessando via URL.
c.ServerApp.open_browser = False

# === Configurações de Autenticação ===

# c.ServerApp.token = '<token_gerado_automaticamente>'
# [PT-BR] Token de autenticação para acessar o Jupyter.
# Se vazio (`''`), um token será gerado automaticamente na inicialização e impresso no console.
# Se você definir uma senha (abaixo), o token geralmente é desabilitado ou ignorado.
# Para desabilitar completamente a autenticação por token (NÃO RECOMENDADO sem senha ou outra segurança):
# c.ServerApp.token = ''
# c.ServerApp.password = '' # Garante que a senha também esteja vazia

# c.ServerApp.password_required = False
# [PT-BR] Se `True`, uma senha será sempre necessária. Se `False` e nenhum token/senha
# for definido, pode permitir acesso sem autenticação (NÃO RECOMENDADO).
# No seu overrides.json, a configuração `pasteWithCtrlV` para o terminal não tem relação.
# No seu spark-defaults.conf, `IdentityProvider.token=''` para JupyterLab (dentro de nohup)
# sugere que você pode estar preferindo não usar tokens ou senhas para acesso direto,
# o que é arriscado se o servidor estiver exposto.

# Para definir uma senha (RECOMENDADO se o token for desabilitado ou se você quiser uma senha fixa):
# 1. Gere um hash de senha:
#    No terminal, execute: python -c "from notebook.auth import passwd; print(passwd())"
#    Ou (para jupyter_server): python -c "from jupyter_server.auth import passwd; print(passwd())"
#    Digite sua senha duas vezes. Copie o hash gerado (ex: 'argon2:$argon2id$v=19$m=...').
# c.ServerApp.password = 'argon2:$argon2id$v=19$m=...seu_hash_de_senha_aqui...'
# Se uma senha for definida, o login por token geralmente é desabilitado.

# Para desabilitar completamente a autenticação (NÃO RECOMENDADO PARA AMBIENTES EXPOSTOS):
# c.ServerApp.token = ''
# c.ServerApp.password = ''
# c.ServerApp.disable_check_xsrf = True # Também pode ser necessário desabilitar a proteção XSRF

# === Configurações de Diretório e Arquivos ===

# c.ServerApp.notebook_dir = ''
# [PT-BR] O diretório que o Jupyter Notebook/Lab usará como raiz para seus arquivos.
# Se vazio, usa o diretório onde o comando `jupyter notebook` ou `jupyter lab` foi executado.
# É uma boa prática definir explicitamente, especialmente para serviços.
# Exemplo: '/home/myuser/notebooks' ou '/srv/jupyterhub/notebooks'
# Seu overrides.json configura `navigateToCurrentDirectory` para o filebrowser do Lab,
# mas esta configuração define o diretório raiz inicial do servidor.
# c.ServerApp.notebook_dir = '/home/myuser/myfiles' # Exemplo baseado no seu `spark-defaults.conf` para JupyterLab

# c.ServerApp.allow_root = False
# [PT-BR] Se `True`, permite que o servidor Jupyter seja executado como root.
# Por padrão, é `False` por razões de segurança.
# Se estiver rodando Jupyter dentro de um contêiner Docker que executa como root
# e você não quiser mudar o usuário, pode precisar definir como `True`.
# CUIDADO: Rodar como root tem implicações de segurança.
# c.ServerApp.allow_root = True # Use com cautela

# === Configurações de Interface (Mais relevantes para Notebook Clássico, mas algumas afetam o Lab) ===

# c.ServerApp.default_url = '/lab'
# [PT-BR] A URL padrão a ser aberta quando o servidor é acessado.
#   - '/tree': Abre a visualização de arquivos (Notebook Clássico).
#   - '/lab': Abre o JupyterLab (se instalado e padrão).
# Se o JupyterLab for seu ambiente principal, definir como '/lab' é uma boa escolha.
c.ServerApp.default_url = '/lab'

# c.ServerApp.terminals_enabled = True
# [PT-BR] Habilita ou desabilita o uso de terminais através da interface web.
# Seu `overrides.json` tem configurações para `@jupyterlab/terminal-extension:plugin`,
# o que implica que você usa terminais. Portanto, esta opção deve ser `True`.
c.ServerApp.terminals_enabled = True

# --- Configurações relacionadas a temas e aparências ---
# O tema geral do JupyterLab ("JupyterLab Dark") e os tamanhos de fonte do editor
# são configurados no `overrides.json` (frontend) e não aqui.
# No entanto, para o Notebook Clássico (se ainda for usado), você poderia
# tentar configurar algumas coisas aqui, embora seja menos comum hoje em dia.

# Exemplo (NÃO AFETA O TEMA DO JUPYTERLAB DIRETAMENTE):
# c.NotebookApp.extra_static_paths = []
# c.NotebookApp.extra_template_paths = []
# Para temas de sintaxe no editor de texto do Notebook Clássico (não JupyterLab):
# c.HighlightingExtension.theme = 'monokai' # (requer a extensão jupyter_highlight_selected_word ou similar)

# --- Configurações de Kernel ---

# c.ServerApp.kernel_manager_class = 'jupyter_server.kernel_manager.AsyncKernelManager'
# [PT-BR] Classe para gerenciar kernels. O padrão é geralmente adequado.

# c.MappingKernelManager.cull_idle_timeout = 0
# [PT-BR] Timeout (em segundos) para desligar kernels ociosos. 0 desabilita o culling.
# Se > 0, kernels sem atividade por este período serão desligados. Útil para economizar recursos.
# Exemplo: 3600 (1 hora)
# c.MappingKernelManager.cull_idle_timeout = 3600

# c.MappingKernelManager.cull_interval = 300
# [PT-BR] Intervalo (em segundos) para verificar kernels ociosos. Padrão 300 (5 minutos).
# Relevante se cull_idle_timeout > 0.
# c.MappingKernelManager.cull_interval = 300

# c.MappingKernelManager.cull_connected = False
# [PT-BR] Se `True`, kernels ociosos com conexões ativas (ex: um notebook aberto no navegador)
# também podem ser desligados. Padrão `False`.
# c.MappingKernelManager.cull_connected = True

# --- Outras Configurações ---

# c.ServerApp.allow_origin = ''
# [PT-BR] Define o padrão 'Access-Control-Allow-Origin' para requisições cross-origin.
# Use '*' para permitir de qualquer origem (CUIDADO: implicações de segurança).
# Se o JupyterLab estiver sendo embutido em outra aplicação ou acessado de um domínio diferente,
# pode ser necessário configurar isso.
# c.ServerApp.allow_origin = '*' # Exemplo, use com cautela

# c.ServerApp.allow_credentials = False
# [PT-BR] Define o header 'Access-Control-Allow-Credentials'.
# Relevante para requisições cross-origin com credenciais.
# c.ServerApp.allow_credentials = True

# c.ServerApp.log_level = 'INFO'
# [PT-BR] Nível de log do servidor. Opções: 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'.
c.ServerApp.log_level = 'INFO'

# c.FileContentsManager.delete_to_trash = True
# [PT-BR] Se `True` (padrão), arquivos excluídos pela UI são movidos para uma lixeira
# (no sistema de arquivos do servidor, dentro do diretório de dados do Jupyter)
# em vez de serem permanentemente excluídos. Se `False`, a exclusão é permanente.
c.FileContentsManager.delete_to_trash = True

# --- Configurações que NÃO são mapeadas do seu overrides.json ---
# A grande maioria das configurações no seu `overrides.json` são para o frontend do JupyterLab
# e não têm equivalentes diretos no `jupyter_notebook_config.py`. Estas incluem:
# - Configurações de editor de código e células (autoClosingBrackets, codeFolding, lineNumbers, rulers, etc.)
# - Tamanhos de fonte específicos para UI, código, terminal.
# - Tema do terminal, tema visual do JupyterLab ("JupyterLab Dark").
# - Comportamento do navegador de arquivos do Lab (showHiddenFiles, sortNotebooksFirst).
# - Notificações do Lab (checkForUpdates, fetchNews).
#
# Essas personalizações devem permanecer no sistema de configuração do JupyterLab
# (seja via "Advanced Settings Editor" na UI do Lab, que modifica arquivos JSON
# na pasta de configuração do usuário, ou via arquivos `overrides.json` em locais específicos).

# Para mais opções, consulte a documentação oficial do Jupyter Server ou Jupyter Notebook:
# https://jupyter-server.readthedocs.io/en/latest/users/configuration.html
# https://jupyter-notebook.readthedocs.io/en/stable/config_overview.html

# Nota: Algumas configurações podem variar entre Jupyter Notebook e Jupyter Server.
# Se você estiver usando JupyterLab, muitas dessas configurações ainda são relevantes,
# pois o JupyterLab geralmente roda sobre um servidor Jupyter (Notebook ou Server).
# Para JupyterLab, você pode precisar de um arquivo separado de configuração   
# (como `jupyter_lab_config.py`), mas muitas configurações do Notebook ainda se aplicam.
