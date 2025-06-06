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
        hdfs-site.xml contém parâmetros de configuração específicos para o HDFS (Hadoop Distributed FileSystem),
        como os diretórios de dados do NameNode e DataNode, fator de replicação, etc.
    -->

    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///opt/hadoop_data/hdfs/namenode</value>
        <!-- <value>/home/${user.name}/hdfs-data/nameNode</value> --> <!-- Valor Original -->
        <description>
            Determina onde no sistema de arquivos local o NameNode do HDFS deve armazenar
            seus metadados (imagem do sistema de arquivos - fsimage, e logs de edição - edits log).
            É CRUCIAL que este diretório seja persistente e não seja perdido.
            Em um ambiente Docker, este caminho DEVE ser montado como um volume persistente.
            O prefixo 'file://' é opcional para caminhos locais, mas bom para clareza.
            Alterado de `/home/${user.name}/...` para um caminho mais genérico como `/opt/hadoop_data/...`
            que é comum para dados de aplicação em contêineres.
            Certifique-se que o usuário Hadoop tenha permissão de escrita neste diretório.
        </description>
        <final>false</final>
    </property>

    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///opt/hadoop_data/hdfs/datanode</value>
        <!-- <value>/home/${user.name}/hdfs-data/dataNode</value> --> <!-- Valor Original -->
        <description>
            Determina onde no sistema de arquivos local um DataNode do HDFS deve armazenar
            os blocos de dados.
            Este diretório também DEVE ser persistente em um ambiente Docker (montado como volume)
            se a perda de dados não for aceitável. Pode ser uma lista de diretórios separados por vírgula
            para usar múltiplos discos.
            Alterado de `/home/${user.name}/...` para um caminho mais genérico.
            Certifique-se que o usuário Hadoop tenha permissão de escrita.
        </description>
        <final>false</final>
    </property>

    <property>
        <name>dfs.replication</name>
        <value>2</value>
        <description>
            O fator de replicação de bloco padrão para novos arquivos.
            Um valor de '2' significa que cada bloco de dados será replicado em 2 DataNodes diferentes.
            Para um cluster de desenvolvimento com poucos nós (ex: 2-3 DataNodes), um valor de '2'
            pode ser apropriado. Se você tiver apenas 1 DataNode, este valor deve ser '1'.
            Para produção, o padrão é '3'.
            O número de DataNodes disponíveis deve ser maior ou igual ao fator de replicação.
        </description>
    </property>

    <property>
        <name>dfs.blocksize</name>
        <value>128m</value> <!-- 128 Megabytes -->
        <description>
            O tamanho de bloco padrão do HDFS para novos arquivos, em bytes.
            Pode ser especificado com sufixos como 'k', 'm', 'g'.
            128MB (134217728 bytes) é um valor comum e bom para muitos casos de uso.
            Valores maiores (ex: 256MB, 512MB) podem ser benéficos para arquivos muito grandes,
            reduzindo a quantidade de metadados no NameNode e otimizando leituras sequenciais.
            Para arquivos menores, blocos menores podem ser mais eficientes.
        </description>
    </property>

    <!-- Propriedades Adicionais Sugeridas para hdfs-site.xml -->

    <property>
        <name>dfs.namenode.http-address</name>
        <value>spark-master:9870</value>
        <description>
            O endereço (hostname:porta) para a UI web do NameNode.
            'spark-master' deve ser o hostname do NameNode e '9870' é a porta padrão da UI.
            Importante para acessar informações do cluster via navegador.
        </description>
    </property>

    <property>
        <name>dfs.namenode.https-address</name>
        <value>spark-master:9871</value>
        <description>
            O endereço HTTPS para a UI web do NameNode, se SSL estiver habilitado.
            Comentado por padrão, pois SSL não é comum em setups de desenvolvimento simples.
        </description>
        <!-- <value>spark-master:9871</value> -->
    </property>

    <property>
        <name>dfs.datanode.http.address</name>
        <value>0.0.0.0:9864</value>
        <description>
            O endereço (hostname:porta) para a UI web do DataNode.
            Usar '0.0.0.0' permite que a UI seja acessível de fora do contêiner se a porta for exposta.
            A porta padrão é 9864 (era 50075 em versões mais antigas do Hadoop).
        </description>
    </property>

    <property>
        <name>dfs.datanode.address</name>
        <value>0.0.0.0:9866</value>
        <description>
            O endereço (hostname:porta) para o servidor de dados do DataNode.
            Usar '0.0.0.0' faz o DataNode escutar em todas as interfaces de rede disponíveis.
            A porta padrão é 9866 (era 50010).
        </description>
    </property>

    <property>
        <name>dfs.datanode.ipc.address</name>
        <value>0.0.0.0:9867</value>
        <description>
            O endereço (hostname:porta) para o servidor IPC do DataNode.
            Usar '0.0.0.0' faz o DataNode escutar em todas as interfaces de rede.
            A porta padrão é 9867 (era 50020).
        </description>
    </property>

    <property>
        <name>dfs.permissions.enabled</name>
        <value>true</value> <!-- Mude para 'false' se quiser desabilitar a verificação de permissões HDFS -->
        <description>
            Habilita ou desabilita o sistema de permissões do HDFS.
            Se 'true' (padrão), as permissões de arquivo/diretório no estilo POSIX são aplicadas.
            Para desenvolvimento, pode ser útil definir como 'false' para simplificar,
            mas 'true' é mais seguro e reflete melhor um ambiente de produção.
        </description>
    </property>

    <property>
        <name>dfs.namenode.handler.count</name>
        <value>20</value> <!-- Padrão é 10 -->
        <description>
            O número de threads do servidor NameNode para lidar com RPCs de clientes.
            O padrão é 10. Um valor maior pode ser útil em clusters maiores ou com mais clientes concorrentes.
            Para um ambiente pequeno, 20 pode ser um bom ponto de partida se o padrão de 10 se mostrar limitante.
            Um valor muito alto pode aumentar o uso de memória.
            dfs.namenode.service.handler.count (para RPCs de DataNodes) também pode ser ajustado.
        </description>
    </property>

    <!-- Propriedades para WebHDFS (REST API) -->
    <property>
        <name>dfs.webhdfs.enabled</name>
        <value>true</value>
        <description>
            Habilita ou desabilita o acesso ao HDFS via API REST WebHDFS.
            Útil para integração com outras ferramentas e acesso programático.
        </description>
    </property>

    <!--
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>hostname_do_secondary_namenode:9868</value>
        <description>
            O endereço HTTP para o Secondary NameNode.
            A porta padrão é 9868 (era 50090).
            Necessário se você estiver rodando um Secondary NameNode.
        </description>
    </property>
    -->

</configuration>
