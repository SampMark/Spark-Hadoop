### **Spark em `config_files/spark/`:**

  * `spark-defaults.conf`: Vários parâmetros comentados, como `spark.driver.memory`, `spark.executor.memory`, os valores padrão do Spark 3.3.x se aplicam caso o usuário não descomente/edite.
  * `spark-env.sh`: Exporta `SPARK_WORKER_CORES=1`, `SPARK_WORKER_MEMORY=1g`, etc., entretanto, não herda variáveis de ambiente do host—o script copia esse arquivo para `/opt/spark/conf` sem mesclar com variáveis `.env`.