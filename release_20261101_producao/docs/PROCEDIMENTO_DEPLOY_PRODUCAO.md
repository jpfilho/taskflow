# GUIA DE DEPLOY EM PRODUÇÃO — TASKFLOW (10.140.50.12)
**Data:** 01/11/2026  
**Commit Release:** `5231157` (com suporte explícito a `--dart-define=ENVIRONMENT=production` em `a009f40`)  
**Servidor Alvo:** `10.140.50.12` (Rede Corporativa)  

---

## 1. Visão Geral da Situação

- **Servidor Corporativo:** `10.140.50.12`
- **Código Fonte no Servidor:** `/home/jpfilho/taskflow-release-20261101`
- **Diretório Ativo Web:** `/home/jpfilho/taskflow/build/web` (compartilhado pelos contêineres Nginx 8080 e 8085)
- **Backup Validado:** `/home/jpfilho/backups_taskflow/20261101_153023/postgres.dump`
- **Endpoints de Produção Configurados no Build:**
  - Supabase / Kong: `http://10.140.50.12:8000`
  - API Node: `http://10.140.50.12:3001`
  - Base Href: `/task2026/`
  - Autenticação Microsoft Entra ID integrada via MSAL JS

---

## 2. Conteúdo do Pacote de Release

O diretório `release_20261101_producao/` contém:

```text
release_20261101_producao/
├── taskflow_web_prod_20261101.tar.gz  # Build Flutter Web Release compilado para produção
├── sql/
│   ├── 01_pre_requisitos_e_analise_base.sql
│   ├── 02_grupos_previsao.sql
│   ├── 03_anexos_storage_e_anotacoes.sql
│   ├── 04_analise_evidencias_polimorficas.sql
│   ├── 05_tags_hierarquicas.sql
│   ├── 06_recarregar_schema_postgrest.sql
│   ├── migracao_producao_notas_sap_20261101.sql  # SQL consolidado sequencial
│   └── validar_pos_migracao.sql                  # Bateria de testes de integridade
├── scripts/
│   ├── executar_migracao_producao.sh             # Script automatizado de migração do banco
│   ├── deploy_docker_producao.sh                 # Deploy Docker com teste na porta 8088
│   └── rollback_producao.sh                      # Rollback imediato do frontend e instruções DB
├── docs/
│   └── PROCEDIMENTO_DEPLOY_PRODUCAO.md           # Este manual
└── SHA256SUMS.txt                                # Hashes de integridade dos arquivos
```

---

## 3. Passo 1 — Transferência do Pacote para o Servidor

No seu computador local, transfira o pacote compactado para o servidor corporativo:

```bash
# Compactar o pacote de release para envio:
tar -czf release_20261101_producao.tar.gz release_20261101_producao/

# Transferir via SCP para o servidor corporativo:
scp release_20261101_producao.tar.gz jpfilho@10.140.50.12:/home/jpfilho/

# No servidor corporativo:
ssh jpfilho@10.140.50.12
tar -xzf release_20261101_producao.tar.gz
cd release_20261101_producao
```

---

## 4. Passo 2 — Execução das Migrations no PostgreSQL

Execute o script de automação, que:
1. Valida se o backup `/home/jpfilho/backups_taskflow/20261101_153023/postgres.dump` está íntegro.
2. Aplica as 6 etapas na ordem estrita de dependências com `ON_ERROR_STOP=1`.
3. Executa a bateria de testes de validação pós-migração.
4. Gera log com timestamp em `logs/migracao_prod_YYYYMMDD_HHMMSS.log`.

```bash
bash scripts/executar_migracao_producao.sh
```

> **Critério de Aceite:** O script deve finalizar com a mensagem `RESULTADO GLOBAL: ✅ TODAS AS VALIDAÇÕES FORAM CONCLUÍDAS COM SUCESSO!`. Se houver qualquer erro, a execução é interrompida imediatamente sem avançar.

---

## 5. Passo 3 — Deploy Controlado do Frontend Docker

O script `deploy_docker_producao.sh` executa o procedimento seguro sem risco de indisponibilidade:

1. Extrai o build em `/home/jpfilho/taskflow/build/releases/release_20261101_<timestamp>/`.
2. Sobe um contêiner temporário Nginx na **porta 8088** apontando para a nova versão.
3. Executa um teste automatizado (`curl` e validação de `<base href="/task2026/">`).
4. Finaliza o contêiner temporário após o teste aprovado.
5. Faz backup da versão anterior em `/home/jpfilho/taskflow/build/web_backup_<timestamp>/`.
6. Atualiza o diretório oficial `/home/jpfilho/taskflow/build/web` via sincronização atômica (`rsync`).
7. Testa a resposta dos dois contêineres oficiais (portas 8080 e 8085).

Comando de execução:

```bash
bash scripts/deploy_docker_producao.sh
```

---

## 6. Procedimento de Rollback (Se Necessário)

### Reversão do Frontend Web:
Caso identifique qualquer problema visual ou funcional após a atualização, execute:

```bash
# Reverte para o último backup criado automaticamente
bash scripts/rollback_producao.sh
```

### Reversão Segura do Banco de Dados:
⚠️ **REGRA DE SEGURANÇA:** NUNCA execute `pg_restore --clean` diretamente sobre o banco ativo, pois isso apagaria notas, ordens e tarefas criadas pelos usuários após o horário do backup.

**Procedimento Cirúrgico Recomendado:**
Execute o script de rollback seletivo, que remove apenas as novas estruturas criadas nas migrations de outubro/novembro 2026, mantendo todas as tabelas e dados operacionais intocados:

```bash
docker exec -i supabase-db psql -U postgres -d postgres < sql/rollback_migracao_notas_sap.sql
# (ou caso necessário sudo):
sudo docker exec -i supabase-db psql -U postgres -d postgres < sql/rollback_migracao_notas_sap.sql
```

---

## 7. Checklist Final de Validação em Produção

Acesse pelo navegador corporativo:
1. `http://10.140.50.12:8085/task2026/` (ou `http://10.140.50.12:8080/task2026/`).
2. Efetue login com as credenciais corporativas / Microsoft Entra ID.
3. Acesse a tela de **Notas SAP**:
   - Abra o drawer/modal de uma nota e verifique a aba de **Análise Prévia**.
   - Verifique a seção de **Materiais/Peças**, **Fotos/Anexos** e **Comentários**.
   - Verifique o campo de **Tags** e teste a atribuição/filtro de Tags hierárquicas.
   - Verifique a seção de **Grupos de Previsão**.
