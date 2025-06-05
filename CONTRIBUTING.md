# Contribuições para o repositório Spark-Hadoop

## 🎯 Objetivos
- Fornecer um ambiente Docker reprodutível para clusters Hadoop + Spark + Jupyter.
- Manter scripts e configurações organizados, com templates e validações.

Antes de abrir uma issue ou PR, verifique se o pedido está alinhado a este escopo.  

## 📋 Reportar Bugs
1. Verifique se o erro já não está registrado em [`issues`](https://github.com/SampMark/spark-hadoop/issues). 
2. Abra uma nova issue contendo:
   - **Resumo**: título curto e descritivo.  
   - **Descrição**: passo a passo para reproduzir localmente.  
   - **Logs**: mensagens de erro de containers (`docker logs <container>`).  
   - **Ambiente**: versão do Docker, Docker Compose, `.env` (omitindo senhas).

## ✨ Propor Features
1. Abra uma issue detalhando o caso de uso.  
2. Aguarde discussões e alinhamentos com mantenedores.  
3. Após aprovação, faça fork e crie branch `feature/minha-feature`.
4. Garanta que:
   - Scripts Bash passem em `shellcheck`.  
   - Adicione testes de smoke em `tests/` se fizer alterações que afetem saúde do cluster.  
   - Atualize `README.md`, `CHANGELOG.md` e `docker-compose.template.yml` (se necessário).

## 💻 Submissão de Pull Request
1. Crie branch no seu fork:
   ```bash
   git checkout -b feature/exemplo-feature

Siga estas diretrizes acima. Obrigado por querer colaborar! 
