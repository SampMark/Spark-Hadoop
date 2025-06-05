spark-hadoop/
├── .dockerignore
├── .env
├── .env.example
├── .gitattributes
├── .gitignore
├── .password
├── CHANGELOG.md
├── CONTRIBUTING.md
├── docker-compose.template.yml
├── docker-compose.yml      ← gerado por init.sh
├── LICENSE.apache          ← Apache 2.0 (Hadoop)
├── LICENSE.mit             ← MIT (scripts e infra)
├── pgsql
├── README.md
├── config_files/
│   ├── README.md
│   ├── hadoop/
│   │   ├── core-site.xml.template
│   │   ├── hadoop-env.sh.template
│   │   ├── hdfs-site.xml.template
│   │   ├── mapred-site.xml.template
│   │   ├── yarn-env.sh.template
│   │   └── yarn-site.xml.template
│   ├── jupyterlab/
│   │   ├── overrides.json.template
│   │   └── jupyter_notebook_config.py.template
│   ├── spark/
│   │   ├── spark-defaults.conf.template
│   │   └── spark-env.sh.template
│   └── system/
│       ├── README.md
│       ├── bash_common
│       └── ssh_config.template
├── docker/
│   ├── Dockerfile
│   └── entrypoint.sh
├── myfiles/
│   ├── README.md
│   ├── data/
│   ├── notebooks/
│   └── scripts/
├── scripts/
│   ├── download_all.sh
│   ├── init.sh
│   ├── preflight_check.sh
│   ├── bootstrap.sh
│   └── start_services.sh
└── tests/
    ├── smoke_test_hadoop.sh
    └── smoke_test_spark.sh



