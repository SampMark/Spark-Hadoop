### **docker/**

- **Dockerfile**: baseia-se em uma imagem Linux (Ubuntu), instala dependências (OpenJDK, Hadoop, Spark, Python, JupyterLab) e adiciona configurações customizadas.

- `entrypoint.sh`: ao iniciar container, define ambientes, cria usuário, ajusta permissões, inicia SSH e, no master, dispara `services.sh`.