### **config_files/**

- **hadoop/**: Configurações XML (`core-site`, `hdfs-site`, `yarn-site`, `mapred-site`) e os scripts de ambiente (`hadoop-env.sh`, `yarn-env.sh`).

- **spark/**: `spark-defaults.conf` (memória, recursos) e `spark-env.sh` (variáveis de ambiente para Spark em cluster YARN).

- **jupyterlab/**: Ajustes de configuração do Jupyter (configurações de senha, extensions).

- **system/**: Scripts comuns de Bash (ex.: .`bash_common`) e `ssh_config` para habilitar comunicação _passwordless_.