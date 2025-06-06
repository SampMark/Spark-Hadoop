### **`config_files/hadoop/`:**

#### **Padrões de Configuração Hadoop/Spark**

  * `core-site.xml`: define `fs.defaultFS` como `hdfs://${HDFS_NAMENODE_HOST}:9000`.
  * `hdfs-site.xml`: Configurações de replicação, como `<property><name>dfs.replication</name><value>1</value></property>`. Em cluster real, talvez replicação > 1 seja desejável.
  * `yarn-site.xml`: Define `yarn.resourcemanager.hostname` como “master” e configura `resourceManager` com memória/cpu, mas valores de memória (`yarn.nodemanager.resource.memory-mb=2048`) não são parametrizados externamente.
  * `mapred-site.xml`: Mapeia `mapreduce.framework.name=yarn` e define recursos para o ApplicationMaster, porém novamente com valores fixos (e.g., `<value>512</value>`).


