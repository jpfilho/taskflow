# GUIA DE DEPLOY EM PRODUÇÃO — TASKFLOW (10.140.50.12)
**Data:** 01/11/2026  
**Commit Release:** `5231157` (com suporte explícito a `--dart-define=ENVIRONMENT=production` e base href `/`)  
**Servidor Alvo:** `10.140.50.12` (Rede Corporativa)  
**Porta Alvo:** `8085` (Contêiner `taskflow-web-teste`)  
**Diretório Alvo:** `/home/jpfilho/taskflow/build/web`  

---

## 1. Visão Geral da Situação

- **Servidor Corporativo:** `10.140.50.12`
- **Contêiner Ativo Web:** `taskflow-web-teste` (porta `8085`)
- **Diretório Ativo Web:** `/home/jpfilho/taskflow/build/web`
- **Base Href:** `/` (raiz, compatível com a rota do Nginx na porta 8085)
- **Endpoints de Produção Configurados no Build:**
  - Supabase / Kong: `http://10.140.50.12:8000`
  - API Node: `http://10.140.50.12:3001`
  - Autenticação Microsoft Entra ID compatível com a URL de produção na raiz

---

## 2. Conteúdo do Pacote de Release

O diretório `release_20261101_producao/` contém:

```text
release_20261101_producao/
├── taskflow_web_prod_20261101.tar.gz  # Build Flutter Web Release limpo compilado com base-href="/"
├── scripts/
│   ├── publicar_web_producao.sh          # Script de publicação web definitivo (porta 8085 / taskflow-web-teste)
│   ├── deploy_docker_producao.sh         # Script alternativo de deploy geral
│   └── rollback_producao.sh              # Script de rollback imediato do frontend e instruções DB
├── sql/
│   ├── 01_pre_requisitos_e_analise_base.sql
│   ├── 02_grupos_previsao.sql
│   ├── 03_anexos_storage_e_anotacoes.sql
│   ├── 04_analise_evidencias_polimorficas.sql
│   ├── 05_tags_hierarquicas.sql
│   ├── 06_recarregar_schema_postgrest.sql
│   ├── migracao_producao_notas_sap_20261101.sql  # SQL consolidado sequencial
│   ├── rollback_migracao_notas_sap.sql           # Rollback cirúrgico e seguro do banco
│   └── validar_pos_migracao.sql                  # Bateria de testes de integridade
├── docs/
│   └── PROCEDIMENTO_DEPLOY_PRODUCAO.md           # Este manual
└── SHA256SUMS.txt                                # Hashes de integridade de todos os arquivos
```

---

## 3. Instruções de Execução no Servidor Corporativo (`10.140.50.12`)

Como a transferência ocorre via Git no servidor corporativo:

```bash
# 1. Acessar o diretório do projeto no servidor corporativo:
cd /home/jpfilho/taskflow-release-20261101

# 2. Obter as atualizações mais recentes do GitHub:
git fetch origin release/production-20261101
git checkout release/production-20261101
git pull origin release/production-20261101

# 3. Entrar na pasta do pacote de produção:
cd release_20261101_producao

# 4. Executar a publicação web definitiva:
bash scripts/publicar_web_producao.sh
```

---

## 4. O que o Script `publicar_web_producao.sh` Executa Automaticamente:

1. **Validação do Pacote:** Testa se `taskflow_web_prod_20261101.tar.gz` está íntegro.
2. **Backup Prévio:** Salva o conteúdo anterior em `/home/jpfilho/taskflow/build/web_backup_<timestamp>`.
3. **Extração Isolada:** Extrai em diretório dedicado sem misturar arquivos de builds anteriores.
4. **Verificação Estrutural:** Valida a presença de `index.html` (com `<base href="/">`), `main.dart.js` e `flutter_bootstrap.js`.
5. **Publicação Atômica:** Atualiza `/home/jpfilho/taskflow/build/web` e define permissões 755.
6. **Recarga do Contêiner:** Envia comando de reload gracioso do Nginx para o contêiner `taskflow-web-teste`.
7. **Bateria de Testes HTTP:**
   - Verifica HTTP 200 para `http://127.0.0.1:8085/`
   - Verifica HTTP 200 para `http://127.0.0.1:8085/main.dart.js`
   - Verifica HTTP 200 para `http://127.0.0.1:8085/flutter_bootstrap.js`
8. **Conferência Criptográfica:** Valida se os hashes dos arquivos publicados conferem com o build gerado.
9. **Rollback Automático:** Caso ocorra qualquer falha durante as validações, restaura a versão anterior imediatamente.

---

## 5. Procedimento de Rollback Manual (Se Necessário)

Caso precise reverter para a versão anterior a qualquer momento:

```bash
bash scripts/rollback_producao.sh
```

---

## 6. Checklist de Validação pelo Navegador Corporativo

Acesse:
`http://10.140.50.12:8085/`

1. Faça um **Hard Refresh** no navegador (`Ctrl + F5` ou `Cmd + Shift + R`) para atualizar os caches do Service Worker.
2. Faça login com a conta corporativa.
3. Abra a tela de **Notas SAP**:
   - Verifique a coluna de **Tags** e os chips de tags coloridas na tabela.
   - Abra os detalhes de uma nota (clicando no badge de análise ou no botão de ações).
   - Verifique o modal completo **Workspace da Nota**:
     - Aba **Análise Técnica**
     - Aba **Materiais e Peças**
     - Aba **Fotos e Anexos**
     - Aba **Comentários / Timeline**
     - Seletor e Gestor de **Tags Hierárquicas**
     - Gestão de **Grupos e Previsão Macro**
