<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<configuration>
    <!--
        mapred-site.xml contém parâmetros de configuração para o framework MapReduce.
        Quando se usa YARN, muitas dessas configurações definem como os jobs MapReduce
        interagem com o YARN para alocação de recursos e execução.
    -->

    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
        <description>
             O framework de execução para jobs MapReduce.
            'yarn' é o valor padrão e recomendado para executar MapReduce no YARN.
            Outras opções (menos comuns hoje) seriam 'local' ou 'classic'.
        </description>
    </property>

    <!-- Configurações de Recursos para ApplicationMaster do MapReduce -->
    <property>
        <name>yarn.app.mapreduce.am.resource.mb</name> <!-- Nome corrigido de memory-mb para mb -->
        <value>1536</value>
        <description>
            A quantidade de memória (em MB) solicitada para o contêiner do ApplicationMaster (AM)
            de um job MapReduce. O padrão é 1536MB.
            Este valor deve ser <= yarn.scheduler.maximum-allocation-mb (em yarn-site.xml)
            e >= yarn.scheduler.minimum-allocation-mb.
            Ajuste conforme a complexidade e o número de tarefas do job.
        </description>
    </property>

    <property>
        <name>yarn.app.mapreduce.am.resource.cpu-vcores</name> <!-- Nome corrigido de vcores para cpu-vcores -->
        <value>1</value>
        <description>
            O número de vCores (núcleos virtuais de CPU) solicitados para o contêiner
            do ApplicationMaster do MapReduce. O padrão é 1.
            Este valor deve ser <= yarn.scheduler.maximum-allocation-vcores.
        </description>
    </property>

    <!-- Configurações de Recursos para Tarefas Map -->
    <property>
        <name>mapreduce.map.memory.mb</name> <!-- Nome corrigido de resource.memory-mb para memory.mb -->
        <value>1024</value>
        <description>
            A quantidade de memória (em MB) solicitada para cada contêiner de tarefa Map.
            O padrão é 1024MB.
            Deve ser ajustado com base nos requisitos de memória das suas tarefas Map.
            Deve ser <= yarn.scheduler.maximum-allocation-mb.
        </description>
    </property>

    <property>
        <name>mapreduce.map.cpu.vcores</name> <!-- Nome corrigido de resource.vcores para cpu.vcores -->
        <value>1</value>
        <description>
            O número de vCores solicitados para cada contêiner de tarefa Map.
            O padrão é 1.
        </description>
    </property>

    <!-- Configurações de Recursos para Tarefas Reduce -->
    <property>
        <name>mapreduce.reduce.memory.mb</name> <!-- Nome corrigido de resource.memory-mb para memory.mb -->
        <value>1024</value> <!-- Pode precisar ser maior que map.memory.mb, dependendo da tarefa -->
        <description>
            A quantidade de memória (em MB) solicitada para cada contêiner de tarefa Reduce.
            O padrão é 1024MB. Tarefas Reduce frequentemente requerem mais memória que Maps.
            Ajuste conforme os requisitos das suas tarefas Reduce.
        </description>
    </property>

    <property>
        <name>mapreduce.reduce.cpu.vcores</name> <!-- Nome corrigido de resource.vcores para cpu.vcores -->
        <value>1</value>
        <description>
            O número de vCores solicitados para cada contêiner de tarefa Reduce.
            O padrão é 1.
        </description>
    </property>

    <!-- Configurações de Ambiente e Classpath para MapReduce -->
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*,$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*,$PWD/mrFrameworkLocal/*</value>
        <!-- <value>${HADOOP_MAPRED_HOME}/share/hadoop/mapreduce/*,${HADOOP_MAPRED_HOME}/share/hadoop/mapreduce/lib/*</value> --> <!-- Valor Original -->
        <description>
            O CLASSPATH para aplicações MapReduce.
            As variáveis como $HADOOP_MAPRED_HOME (ou ${HADOOP_MAPRED_HOME}) são expandidas
            pelo YARN.
            Adicionado $PWD/mrFrameworkLocal/* que é uma entrada comum que pode aparecer em alguns logs,
            referente ao tarball do framework MapReduce localizado.
            Certifique-se que as variáveis de ambiente (HADOOP_MAPRED_HOME) estejam corretamente
            definidas no ambiente dos NodeManagers.
        </description>
    </property>

    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_MAPRED_HOME:-$HADOOP_HOME}</value>
        <!-- <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value> --> <!-- Valor Original -->
        <description>
            Variáveis de ambiente para o ApplicationMaster do MapReduce.
            Garante que HADOOP_MAPRED_HOME esteja definido. Usar `:-$HADOOP_HOME`
            fornece um fallback se HADOOP_MAPRED_HOME não estiver explicitamente definido.
        </description>
    </property>

    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_MAPRED_HOME:-$HADOOP_HOME}</value>
        <!-- <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value> --> <!-- Valor Original -->
        <description>
            Variáveis de ambiente para as tarefas Map.
        </description>
    </property>

    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_MAPRED_HOME:-$HADOOP_HOME}</value>
        <!-- <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value> --> <!-- Valor Original -->
        <description>
            Variáveis de ambiente para as tarefas Reduce.
        </description>
    </property>

    <!-- Configurações do JobHistory Server -->
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>spark-master:10020</value>
        <!-- <value>0.0.0.0:10020</value> --> <!-- Valor Original -->
        <description>
            O endereço (hostname:porta) onde o JobHistory Server escuta por requisições RPC.
            'spark-master' deve ser o hostname onde o JobHistory Server está rodando.
            A porta padrão é 10020.
            Usar '0.0.0.0' (como no original) faria o JHS escutar em todas as interfaces,
            mas é mais preciso especificar o hostname se ele for fixo.
        </description>
    </property>

    <property>
        <name>mapreduce.jobhistory.webapp.address</name>
        <value>spark-master:19888</value>
        <!-- <value>0.0.0.0:19888</value> --> <!-- Valor Original -->
        <description>
            O endereço (hostname:porta) para a UI web do JobHistory Server.
            'spark-master' deve ser o hostname do JHS. A porta padrão é 19888.
        </description>
    </property>

    <property>
        <name>mapreduce.jobhistory.done-dir</name>
        <value>/user/${user.name}/mapredHistory/done</value> <!-- Diretório HDFS -->
        <description>
            O diretório no HDFS onde os logs de histórico de jobs concluídos
            (processados pelo JHS) são armazenados.
            Este diretório deve existir no HDFS e ter permissões adequadas.
            O ${user.name} será o usuário que executa o JobHistory Server.
        </description>
    </property>

    <property>
        <name>mapreduce.jobhistory.intermediate-done-dir</name>
        <value>/user/${user.name}/mapredHistory/intermediate-done</value> <!-- Diretório HDFS -->
        <description>
            O diretório no HDFS onde os logs de histórico de jobs em progresso
            (ainda não totalmente processados pelo JHS) são armazenados temporariamente.
            Deve existir no HDFS com permissões adequadas.
        </description>
    </property>

    <!-- Diretório de Staging para Aplicações MapReduce -->
    <property>
        <name>yarn.app.mapreduce.am.staging-dir</name>
        <value>/user/${user.name}/.staging</value> <!-- Nome de diretório mais comum -->
        <!-- <value>/user/${user.name}/.hadoopStaging</value> --> <!-- Valor Original -->
        <description>
            O diretório de staging no HDFS usado pelo ApplicationMaster do MapReduce
            para arquivos de job (JARs, configurações, etc.).
            O padrão é /tmp/hadoop-yarn/staging/${user.name}/.staging ou similar, mas
            definir explicitamente em /user/${user.name}/.staging é uma prática comum.
            Este diretório deve existir no HDFS com permissões adequadas para os usuários
            que submetem jobs.
        </description>
    </property>

    <!-- Outras Propriedades MapReduce Úteis (Comentadas) -->
    <!--
    <property>
        <name>mapreduce.map.output.compress</name>
        <value>true</value>
        <description>
            Se a saída intermediária das tarefas Map deve ser comprimida.
            Pode melhorar o desempenho reduzindo I/O de rede na fase de shuffle.
        </description>
    </property>

    <property>
        <name>mapreduce.map.output.compress.codec</name>
        <value>org.apache.hadoop.io.compress.SnappyCodec</value>
        <description>
            Codec de compressão a ser usado para a saída intermediária do Map,
            se mapreduce.map.output.compress for true. Snappy é rápido e geralmente uma boa escolha.
            Requer bibliotecas nativas Snappy.
        </description>
    </property>

    <property>
        <name>mapreduce.output.fileoutputformat.compress</name>
        <value>true</value>
        <description>
            Se a saída final do job MapReduce deve ser comprimida.
        </description>
    </property>

    <property>
        <name>mapreduce.output.fileoutputformat.compress.codec</name>
        <value>org.apache.hadoop.io.compress.SnappyCodec</value>
        <description>
            Codec para a saída final, se a compressão estiver habilitada.
        </description>
    </property>

    <property>
        <name>mapreduce.task.io.sort.mb</name>
        <value>256</value>
        <description>
            A quantidade de memória (em MB) usada para ordenação durante a fase de Map e Reduce.
            Padrão é 100MB. Aumentar pode melhorar o desempenho de jobs com muito shuffle/sort.
        </description>
    </property>
    -->

</configuration>
