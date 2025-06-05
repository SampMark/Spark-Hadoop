#!/usr/bin/env bash
set -euo pipefail

# Carrega variáveis de ambiente do .env
if [[ -f "/home/${MY_USERNAME}/.env" ]]; then
  source "/home/${MY_USERNAME}/.env"
fi

# Executa o bootstrap como root
bash /home/${MY_USERNAME}/scripts/bootstrap.sh
