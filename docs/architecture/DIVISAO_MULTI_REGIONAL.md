# Arquitetura — Divisão em Múltiplas Regionais (`divisoes_regionais` N:N)

## 1. Problema e Cenário de Negócio
No ecossistema operacional do TaskFlow, determinadas divisões atuam de forma transversal em múltiplas regionais (exemplo real: a divisão **`NEPTMC`** atua na manutenção civil em várias regionais no Nordeste, como Pernambuco, Bahia e Ceará).

Anteriormente, o sistema utilizava uma relação restritiva de **1 Regional $\rightarrow$ N Divisões** (`divisoes.regional_id`), o que forçava a duplicação cadastral de divisões ou impedia a correlação correta de equipes, frotas e tarefas.

---

## 2. Arquitetura Anterior vs. Nova Arquitetura

### 2.1. Modelo Anterior (1:N)
```text
regionais (1) <----------------- (N) divisoes (1) <--- (N) divisoes_segmentos (N) ---> (1) segmentos
```

### 2.2. Novo Modelo Canônico (N:N Real)
```text
regionais (1) <--- (N) divisoes_regionais (N) ---> (1) divisoes (1) <--- (N) divisoes_segmentos (N) ---> (1) segmentos
```

---

## 3. Estratégia de Compatibilidade Legada (Dual-Read / Dual-Write)

Para garantir **zero downtime** e **zero quebra de integrações legadas**:
1. **Fonte Canônica**: `divisoes_regionais` é a fonte canônica de verdade para a associação Divisão $\leftrightarrow$ Regional.
2. **Preservação de `divisoes.regional_id`**: A coluna legada `regional_id` **NÃO foi removida** (`DO NOT DROP`).
3. **Dual-Write**: Ao criar ou atualizar uma divisão, o primeiro ID de regional vinculado (ou o ID legado pré-existente) continua sendo gravado em `divisoes.regional_id`.
4. **Dual-Read**: O modelo Dart `Divisao` expõe `regionalIds` e `regionais`, mantendo os getters `regionalId` e `regional` com fallback estável e automático.

---

## 4. Banco de Dados (Supabase / PostgreSQL)

### 4.1. Migration (`supabase/migrations/20260917_divisoes_regionais.sql`)
- **Tabela**: `public.divisoes_regionais (divisao_id UUID, regional_id UUID, created_at TIMESTAMPTZ, PRIMARY KEY (divisao_id, regional_id))`
- **Foreign Keys**: `ON DELETE CASCADE` para `divisoes(id)` e `regionais(id)`.
- **Índices**:
  - `idx_divisoes_regionais_divisao_id`
  - `idx_divisoes_regionais_regional_id`
- **Backfill Idempotente**:
  ```sql
  INSERT INTO public.divisoes_regionais (divisao_id, regional_id)
  SELECT id, regional_id FROM public.divisoes
  WHERE regional_id IS NOT NULL
  ON CONFLICT (divisao_id, regional_id) DO NOTHING;
  ```
- **RLS**: Políticas de leitura, inserção e deleção configuradas com segurança.

---

## 5. Banco Local Offline (SQLite) & Sincronização

- **Tabela Local**: `divisoes_regionais_local` em `LocalDatabaseService`.
- **Schema**:
  ```sql
  CREATE TABLE IF NOT EXISTS divisoes_regionais_local (
    divisao_id TEXT NOT NULL,
    regional_id TEXT NOT NULL,
    created_at TEXT,
    sync_status TEXT DEFAULT 'synced',
    PRIMARY KEY (divisao_id, regional_id),
    FOREIGN KEY (divisao_id) REFERENCES divisoes_local(id) ON DELETE CASCADE,
    FOREIGN KEY (regional_id) REFERENCES regionais_local(id) ON DELETE CASCADE
  );
  ```
- **Sync Pipeline**: Suporte à sincronização e resolução de deltas.

---

## 6. Modelo Dart (`lib/models/divisao.dart`)

- Adicionados campos `final List<String> regionalIds` e `final List<String> regionais`.
- Helper centralizado:
  ```dart
  bool atuaNaRegional(String? id) {
    if (id == null || id.isEmpty) return false;
    if (regionalIds.contains(id)) return true;
    return regionalId == id;
  }
  ```
- Serialização `toMap()` com dual-write e `fromMap()` com leitura de `divisoes_regionais` e fallback legado.

---

## 7. Camada de Serviço (`lib/services/divisao_service.dart`)

- **Queries Otimizadas**: Batch join com `divisoes_regionais` e fallback em cascata caso a relação remota esteja pendente de sincronização.
- **Sincronização Delta**: `updateDivisao` calcula `toInsert` e `toDelete` para `divisoes_regionais` e `divisoes_segmentos`, evitando recriações desnecessárias.
- **Comunidades Telegram**: Atualização de comunidades para todas as combinações válidas de regionais e segmentos vinculados.

---

## 8. Interface com Usuário (TFDS)

- **`DivisaoFormDialog`**:
  - Seleção de regional migrada de dropdown único para multi-select com checkboxes e indicação de quantidade selecionada.
  - Validação estrita: exige pelo menos 1 regional selecionada ($\ge 1$).
  - Pré-seleção completa de todos os vínculos no modo de edição.
  - Preservação da regional legada de forma determinística e estável.
- **`DivisaoListView`**:
  - Exibição de múltiplas regionais como badges informativas (`TFStatusBadge`) na tabela desktop e na lista mobile.
  - Busca textual em memória considerando nomes de todas as regionais vinculadas.

---

## 9. Filtros em Cascata Dependentes

Todos os formulários e visualizações que filtravam divisões por regional foram migrados para o helper `d.atuaNaRegional(selectedRegionalId)`:
- `lib/widgets/equipe_form_dialog.dart`
- `lib/widgets/empresa_form_dialog.dart`
- `lib/widgets/centro_trabalho_form_dialog.dart`
- `lib/widgets/team_schedule_view.dart`

---

## 10. Segurança de Tarefas (`tasks`) e Métricas SQL

- **Cardinalidade de Tarefas**: Uma tarefa continua associada a exatamente 1 `regional_id` e 1 `divisao_id`. O schema de tarefas **não sofreu qualquer alteração**.
- **Prevenção de Duplicação em Métricas SQL**: As views de tarefas do TaskFlow já realizam `JOIN regionais r ON r.id = t.regional_id` e `JOIN divisoes d ON d.id = t.divisao_id` de forma independente, garantindo que agregação de tarefas, horas e ordens não sofram efeito cartesiano ou duplicação.

---

## 11. Plano de Rollback

Caso seja necessário reverter a migração:
1. Como `divisoes.regional_id` permaneceu preenchido em dual-write, o sistema continua funcionando perfeitamente apenas com a estrutura legada.
2. O rollback no Supabase consiste simplesmente em:
   ```sql
   DROP TABLE IF EXISTS public.divisoes_regionais CASCADE;
   ```
3. Nenhum dado de divisões, tarefas ou cadastros é perdido.

---

## 12. Roadmap Futuro (Cleanup Legado)

A remoção definitiva da coluna `divisoes.regional_id` (`DROP COLUMN`) só deverá ocorrer em uma fase posterior quando:
- 100% dos clientes e integrações externas consumirem exclusivamente `divisoes_regionais`.
- Todas as rotinas legadas de sincronização estiverem atualizadas.
