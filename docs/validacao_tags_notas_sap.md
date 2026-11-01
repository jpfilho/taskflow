# TASKFLOW — NOTAS SAP: TAGS HIERÁRQUICAS POR PERFIL ORGANIZACIONAL
## RELATÓRIO DE VALIDAÇÃO TÉCNICA EM BANCO DEV E INTERFACE

Data de Execução: 01/11/2026  
Ambiente: **DEV** (`212.85.0.249`)  
Ambiente de Produção: **10.140.50.12** (**NÃO TOCADO / INTACTO**)

---

### 1. Resumo Executivo
A funcionalidade de **Tags Hierárquicas nas Notas SAP** foi completamente implementada, integrada e validada tecnicamente no banco de dados e na aplicação em ambiente de Desenvolvimento (DEV).  
A migration foi aplicada diretamente no PostgreSQL do container `supabase-db` do servidor DEV. Todas as constraints de integridade, índices parciais/compostos, normalização via trigger, regras de exclusão (`ON DELETE RESTRICT`), batch hydration anti-N+1, filtros multiselect OR e visibilidade cruzada foram comprovados com sucesso.

- **Status da Implementação**: `IMPLEMENTADA E VALIDADA TECNICAMENTE EM DEV`
- **Homologação com Usuários Reais**: `HOMOLOGAÇÃO HUMANA: PENDENTE`

---

### 2. Acesso Seguro ao Ambiente DEV
- **Servidor DEV**: `212.85.0.249`
- **Método Utilizado**: Acesso SSH administrativo direto ao host DEV (`root@212.85.0.249`) com execução de comandos SQL diretamente no container Docker oficial `supabase-db` (`psql -U postgres -d postgres`), sem exposição de credenciais em logs ou comandos e sem uso de brute force.
- **Produção**: `10.140.50.12` permanece intacto e isolado.

---

### 3. Precheck e Aplicação da Migration
- **Precheck Inicial**:
  - `to_regclass('public.notas_sap_tags')`: `NULO` (NÃO EXISTIA).
  - `to_regclass('public.notas_sap_tags_vinculos')`: `NULO` (NÃO EXISTIA).
- **Migration Oficial Aplicada**:
  - Arquivo: `supabase/migrations/20261101_notas_sap_tags_hierarquicas.sql`.
  - Execução transacional (`BEGIN ... COMMIT`) concluída com êxito no container `supabase-db`.

---

### 4. Evidência do Schema e Integridade no Banco Real
Após a aplicação da migration, o catálogo PostgreSQL comprovou:

1. **Tabela `public.notas_sap_tags`**:
   - Colunas: `id` (UUID PK), `nome`, `nome_normalizado`, `descricao`, `categoria`, `cor`, `icone`, `escopo_tipo`, `regional_id`, `divisao_id`, `segmento_id`, `ativo`, `created_at`, `updated_at`, `created_by`.
2. **Tabela `public.notas_sap_tags_vinculos`**:
   - Colunas: `id` (UUID PK), `nota_sap_id` (FK `notas_sap` CASCADE), `tag_id` (FK `notas_sap_tags` RESTRICT), `origem` (CHECK: MANUAL, REGRA, SUGESTAO, IA), `created_at`, `created_by`.
3. **CHECK de Escopo Estrito (`chk_notas_sap_tags_escopo_consistente`)**:
   ```sql
   CHECK (
     (escopo_tipo = 'GLOBAL'   AND regional_id IS NULL AND divisao_id IS NULL AND segmento_id IS NULL) OR
     (escopo_tipo = 'REGIONAL' AND regional_id IS NOT NULL AND divisao_id IS NULL AND segmento_id IS NULL) OR
     (escopo_tipo = 'DIVISAO'  AND regional_id IS NULL AND divisao_id IS NOT NULL AND segmento_id IS NULL) OR
     (escopo_tipo = 'SEGMENTO' AND regional_id IS NULL AND divisao_id IS NULL AND segmento_id IS NOT NULL)
   )
   ```
4. **Trigger de Normalização (`trg_notas_sap_tags_normalizar`)**:
   - Executa `trg_fn_notas_sap_tags_normalizar()` em `BEFORE INSERT OR UPDATE`.
   - Limpa espaços nas extremidades e converte para caixa baixa (`NEW.nome = TRIM(NEW.nome); NEW.nome_normalizado = LOWER(NEW.nome);`).
5. **Índice Único Composto de Escopo (`uq_notas_sap_tags_escopo_nome`)**:
   - Trata UUIDs nulos com sentinela `'00000000-0000-0000-0000-000000000000'::uuid` para garantir unicidade estrita de nome dentro do mesmo escopo.
6. **Integridade Referencial (`ON DELETE RESTRICT`)**:
   - `notas_sap_tags_vinculos_tag_id_fkey` possui `confdeltype = 'r'`, impedindo a exclusão física de tags com notas associadas.

---

### 5. Resultados dos Testes de Integridade no Banco Real
- **CHECK Negativo 1 (GLOBAL + regional_id)**: Rejeitado com `check_violation`.
- **CHECK Negativo 2 (DIVISAO + regional_id)**: Rejeitado com `check_violation`.
- **CHECK Negativo 3 (SEGMENTO + divisao_id)**: Rejeitado com `check_violation`.
- **Normalização Real**: Inserção de `"  TESTE VEGETAÇÃO  "` resultou em `nome_normalizado = "teste vegetação"`.
- **Duplicidade no Mesmo Escopo**: Inserção subsequente de `"teste vegetação"` no mesmo escopo bloqueada por `unique_violation` (`uq_notas_sap_tags_escopo_nome`).
- **Mesmo Nome em Escopos Diferentes**: Permitido (criou com sucesso em `GLOBAL` e `SEGMENTO`).
- **Duplicidade de Vínculo**: Tentativa de vincular a mesma tag duas vezes à mesma nota bloqueada por `unique_violation` (`uq_nota_sap_tag`).
- **Exclusão Física com Vínculo Ativo**: Tentativa de `DELETE` físico da tag bloqueada por `foreign_key_violation` (`ON DELETE RESTRICT`).
- **Desativação Lógica**: `UPDATE notas_sap_tags SET ativo = FALSE` executado com sucesso mantendo o vínculo intacto.

---

### 6. Validação de Perfis e Escopos Organizacionais
Utilizou-se usuários reais existentes na base de DEV:
- **Perfil Root** (`f6801beb-9e1e-441b-bcc1-4ee61f3eeac7`): `is_root = true`.
- **Perfil LT** (`145c1ff3-fa04-4098-89c2-86ce6fd8aff4` - Marcelo): Regional Fortaleza, Divisão NEPTRFMF, Segmento Linhas de Transmissão.
- **Perfil SE** (`6d7d4a5c-8f73-44c3-ae7b-5d9ec9a1e32c` - Wagner): Segmento Subestação.
- **Perfil Múltiplos Segmentos** (`1d96fe48-6281-4f8b-8950-168fc76d51d0` - Uelder): Segmentos Linhas de Transmissão e Subestação.

**Resultados no Seletor de Atribuição**:
- Usuário LT: Vê `TESTE GLOBAL`, `TESTE REGIONAL` (Fortaleza), `TESTE DIVISÃO` (NEPTRFMF) e `TESTE LT`. **NÃO VÊ `TESTE SE`**.
- Usuário SE: Vê `TESTE GLOBAL` e `TESTE SE`. **NÃO VÊ `TESTE LT`** nem Regional/Divisão de LT.
- Usuário Múltiplo: Vê a união dos escopos (`TESTE LT` + `TESTE SE`).
- Usuário Root: Vê **todas** as tags ativas do catálogo.

---

### 7. Validação da Distinção: Visualizar vs Atribuir vs Filtrar
- **Visualização Cruzada**: A tag `TESTE SE` vinculada por um operador de Subestação a uma Nota SAP é visualizada normalmente pelo usuário de Linhas de Transmissão ao abrir a nota (`Tag != Permissão`).
- **Atribuição Cruzada**: O usuário de Linhas de Transmissão **não encontra** a tag `TESTE SE` ao clicar em `+ Adicionar Tag`.
- **Filtro Cruzado**: Na tabela de notas, a tag `TESTE SE` aparece disponível como opção de filtro para o usuário de Linhas de Transmissão, pois está presente em uma nota carregada no universo visível da listagem.

---

### 8. Anti-N+1 e Performance Real Medida
- **Estratégia**: Batch hydration com chunking estrito <= 100 IDs (`buscarTagsEmLote`).
- **Medição Real em DEV**:
  - Amostra: **50 notas SAP reais**.
  - Quantidade de Queries de Rede: **1 query única** (`ceil(50 / 100) = 1`).
  - Tempo de Rede (PostgREST HTTP): **107.71 ms** (média de ~2.15 ms por nota).
  - Consulta em Cache de Memória: **155 µs (0.15 ms)** (0 queries de banco).

---

### 9. Testes Automatizados e Análise Estática
- **Testes Unitários e de Regra de Negócio (`nota_sap_tag_service_test.dart`)**: 38/38 testes aprovados.
- **Testes de Widgets e Renderização (`nota_sap_tags_widget_test.dart`)**: 3/3 testes aprovados.
- **Suíte de Regressão de Notas SAP e Workspace**: 100 testes executados, 100 aprovados sem regressões.
- **Flutter Analyze**: **0 issues found** nos arquivos modificados e criados.

---

### 10. Apontamentos de Segurança e Débito Técnico
1. **Credencial Supabase Exposta**: Durante as sessões de teste e em arquivos do histórico do projeto foram identificados tokens Supabase. Recomenda-se a **rotação da chave `anon`** do ambiente DEV.
2. **Exposição de RPC dblink via PostgREST**: O schema do PostgreSQL expõe endpoints como `/rpc/dblink_exec` no catálogo público da API REST. Recomenda-se revogar o `EXECUTE` da role `public` e `anon` para essa função.
3. **RLS das Novas Tabelas**:
   - Em DEV, as policies foram criadas alinhadas ao padrão existente (`FOR SELECT USING (true)`, `FOR ALL WITH CHECK (true)`).
   - O controle de acesso atual é exercido funcionalmente na camada de **UI e Service** (`isRoot`, `Usuario`).
   - A proteção estrita contra clientes HTTP maliciosos (RLS forte no banco) permanece como **débito de segurança corporativa**.

---

### 11. Limpeza
Todos os vínculos temporários e as 5 tags de teste (`TESTE GLOBAL`, `TESTE REGIONAL`, `TESTE DIVISÃO`, `TESTE LT`, `TESTE SE`) criadas para validação foram completamente removidos da base DEV ao final da bateria de testes.
