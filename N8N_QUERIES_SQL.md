# Queries SQL para N8N - Validações de Permissão

## 📋 Queries para Nodes Postgres

### 1. Lookup Identity (Buscar Executor)

```sql
SELECT 
  ti.user_id as executor_id,
  e.nome as executor_nome,
  e.divisao_id,
  e.segmento_id
FROM telegram_identities ti
JOIN executores e ON e.id = ti.user_id
WHERE ti.telegram_user_id = $1::bigint
  AND e.ativo = true
LIMIT 1;
```

**Parâmetros:** `[$json.telegram_user_id]`

---

### 2. Authorize Context (Buscar Equipes do Executor)

```sql
SELECT DISTINCT equipe_id
FROM equipes_executores
WHERE executor_id = $1::uuid;
```

**Parâmetros:** `[$json.executor_id]`

**Nota:** Este resultado deve ser combinado com o contexto do executor.

---

### 3. Query Tasks Due (Vencendo/Atrasadas)

```sql
WITH executor_equipes AS (
  SELECT DISTINCT equipe_id
  FROM equipes_executores
  WHERE executor_id = $1::uuid
)
SELECT 
  t.id,
  t.tarefa,
  s.status,
  s.codigo as status_codigo,
  t.prioridade,
  t.data_inicio,
  t.data_fim,
  t.coordenador,
  r.regional,
  d.divisao,
  seg.segmento,
  COALESCE(
    (SELECT string_agg(e.nome, ', ')
     FROM tasks_executores te
     JOIN executores e ON e.id = te.executor_id
     WHERE te.task_id = t.id),
    '-N/A-'
  ) as executores_nomes,
  COALESCE(
    (SELECT string_agg(l.local, ', ')
     FROM tasks_locais tl
     JOIN locais l ON l.id = tl.local_id
     WHERE tl.task_id = t.id),
    '-N/A-'
  ) as locais_nomes,
  ttt.telegram_topic_id
FROM tasks t
LEFT JOIN status s ON s.id = t.status_id
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos seg ON seg.id = t.segmento_id
LEFT JOIN telegram_task_topics ttt ON ttt.task_id = t.id
WHERE 
  -- Filtro de data (vencendo/atrasadas)
  t.data_fim < NOW() AT TIME ZONE 'America/Sao_Paulo'
  AND t.status_id NOT IN (
    SELECT id FROM status WHERE codigo IN ('CONC', 'CANC', 'RPAR')
  )
  -- Filtro de permissão
  AND (
    -- Condição 1: Participante direto
    EXISTS (
      SELECT 1 FROM tasks_executores te
      WHERE te.task_id = t.id AND te.executor_id = $1::uuid
    )
    -- Condição 2: Via equipe
    OR EXISTS (
      SELECT 1
      FROM tasks_equipes tq
      JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
      WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
    )
    -- Condição 3: Por divisão/segmento
    OR (
      $2::uuid IS NOT NULL 
      AND t.divisao_id = $2::uuid
    )
    OR EXISTS (
      SELECT 1
      FROM executores_segmentos es
      WHERE es.executor_id = $1::uuid
        AND es.segmento_id = t.segmento_id
    )
  )
ORDER BY t.data_fim ASC
LIMIT 10;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id]`

---

### 4. Query Tasks Today (Hoje)

```sql
WITH executor_equipes AS (
  SELECT DISTINCT equipe_id
  FROM equipes_executores
  WHERE executor_id = $1::uuid
)
SELECT 
  t.id,
  t.tarefa,
  s.status,
  s.codigo as status_codigo,
  t.prioridade,
  t.data_inicio,
  t.data_fim,
  t.coordenador,
  r.regional,
  d.divisao,
  seg.segmento,
  COALESCE(
    (SELECT string_agg(e.nome, ', ')
     FROM tasks_executores te
     JOIN executores e ON e.id = te.executor_id
     WHERE te.task_id = t.id),
    '-N/A-'
  ) as executores_nomes,
  COALESCE(
    (SELECT string_agg(l.local, ', ')
     FROM tasks_locais tl
     JOIN locais l ON l.id = tl.local_id
     WHERE tl.task_id = t.id),
    '-N/A-'
  ) as locais_nomes,
  ttt.telegram_topic_id
FROM tasks t
LEFT JOIN status s ON s.id = t.status_id
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos seg ON seg.id = t.segmento_id
LEFT JOIN telegram_task_topics ttt ON ttt.task_id = t.id
WHERE 
  -- Filtro de data (hoje)
  DATE(t.data_inicio AT TIME ZONE 'America/Sao_Paulo') <= CURRENT_DATE
  AND DATE(t.data_fim AT TIME ZONE 'America/Sao_Paulo') >= CURRENT_DATE
  -- Filtro de permissão (mesmo da query anterior)
  AND (
    EXISTS (
      SELECT 1 FROM tasks_executores te
      WHERE te.task_id = t.id AND te.executor_id = $1::uuid
    )
    OR EXISTS (
      SELECT 1
      FROM tasks_equipes tq
      JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
      WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
    )
    OR ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
    OR EXISTS (
      SELECT 1
      FROM executores_segmentos es
      WHERE es.executor_id = $1::uuid
        AND es.segmento_id = t.segmento_id
    )
  )
ORDER BY t.data_inicio ASC
LIMIT 10;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id]`

---

### 5. Query Tasks By Status

```sql
WITH executor_equipes AS (
  SELECT DISTINCT equipe_id
  FROM equipes_executores
  WHERE executor_id = $1::uuid
)
SELECT 
  t.id,
  t.tarefa,
  s.status,
  s.codigo as status_codigo,
  t.prioridade,
  t.data_inicio,
  t.data_fim,
  t.coordenador,
  r.regional,
  d.divisao,
  seg.segmento,
  COALESCE(
    (SELECT string_agg(e.nome, ', ')
     FROM tasks_executores te
     JOIN executores e ON e.id = te.executor_id
     WHERE te.task_id = t.id),
    '-N/A-'
  ) as executores_nomes,
  COALESCE(
    (SELECT string_agg(l.local, ', ')
     FROM tasks_locais tl
     JOIN locais l ON l.id = tl.local_id
     WHERE tl.task_id = t.id),
    '-N/A-'
  ) as locais_nomes,
  ttt.telegram_topic_id
FROM tasks t
LEFT JOIN status s ON s.id = t.status_id
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos seg ON seg.id = t.segmento_id
LEFT JOIN telegram_task_topics ttt ON ttt.task_id = t.id
WHERE 
  s.codigo = $3::text
  -- Filtro de permissão (mesmo padrão)
  AND (
    EXISTS (
      SELECT 1 FROM tasks_executores te
      WHERE te.task_id = t.id AND te.executor_id = $1::uuid
    )
    OR EXISTS (
      SELECT 1
      FROM tasks_equipes tq
      JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
      WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
    )
    OR ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
    OR EXISTS (
      SELECT 1
      FROM executores_segmentos es
      WHERE es.executor_id = $1::uuid
        AND es.segmento_id = t.segmento_id
    )
  )
ORDER BY t.data_inicio DESC
LIMIT 10;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id, $json.status_codigo]`

**Nota:** `status_codigo` deve ser extraído do comando (ANDA, PROG, CONC, CANC, RPAR)

---

### 6. Query Tasks By Name (Busca por texto)

```sql
WITH executor_equipes AS (
  SELECT DISTINCT equipe_id
  FROM equipes_executores
  WHERE executor_id = $1::uuid
)
SELECT 
  t.id,
  t.tarefa,
  s.status,
  s.codigo as status_codigo,
  t.prioridade,
  t.data_inicio,
  t.data_fim,
  t.coordenador,
  r.regional,
  d.divisao,
  seg.segmento,
  COALESCE(
    (SELECT string_agg(e.nome, ', ')
     FROM tasks_executores te
     JOIN executores e ON e.id = te.executor_id
     WHERE te.task_id = t.id),
    '-N/A-'
  ) as executores_nomes,
  COALESCE(
    (SELECT string_agg(l.local, ', ')
     FROM tasks_locais tl
     JOIN locais l ON l.id = tl.local_id
     WHERE tl.task_id = t.id),
    '-N/A-'
  ) as locais_nomes,
  ttt.telegram_topic_id
FROM tasks t
LEFT JOIN status s ON s.id = t.status_id
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos seg ON seg.id = t.segmento_id
LEFT JOIN telegram_task_topics ttt ON ttt.task_id = t.id
WHERE 
  t.tarefa ILIKE '%' || $3::text || '%'
  -- Filtro de permissão (mesmo padrão)
  AND (
    EXISTS (
      SELECT 1 FROM tasks_executores te
      WHERE te.task_id = t.id AND te.executor_id = $1::uuid
    )
    OR EXISTS (
      SELECT 1
      FROM tasks_equipes tq
      JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
      WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
    )
    OR ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
    OR EXISTS (
      SELECT 1
      FROM executores_segmentos es
      WHERE es.executor_id = $1::uuid
        AND es.segmento_id = t.segmento_id
    )
  )
ORDER BY t.data_inicio DESC
LIMIT 10;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id, $json.search_text]`

**Nota:** `search_text` deve ser sanitizado antes (remover caracteres perigosos)

---

### 7. Query Task By ID

```sql
WITH executor_equipes AS (
  SELECT DISTINCT equipe_id
  FROM equipes_executores
  WHERE executor_id = $1::uuid
)
SELECT 
  t.id,
  t.tarefa,
  s.status,
  s.codigo as status_codigo,
  t.prioridade,
  t.data_inicio,
  t.data_fim,
  t.coordenador,
  r.regional,
  d.divisao,
  seg.segmento,
  COALESCE(
    (SELECT string_agg(e.nome, ', ')
     FROM tasks_executores te
     JOIN executores e ON e.id = te.executor_id
     WHERE te.task_id = t.id),
    '-N/A-'
  ) as executores_nomes,
  COALESCE(
    (SELECT string_agg(l.local, ', ')
     FROM tasks_locais tl
     JOIN locais l ON l.id = tl.local_id
     WHERE tl.task_id = t.id),
    '-N/A-'
  ) as locais_nomes,
  ttt.telegram_topic_id
FROM tasks t
LEFT JOIN status s ON s.id = t.status_id
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos seg ON seg.id = t.segmento_id
LEFT JOIN telegram_task_topics ttt ON ttt.task_id = t.id
WHERE 
  t.id = $3::uuid
  -- Filtro de permissão (mesmo padrão)
  AND (
    EXISTS (
      SELECT 1 FROM tasks_executores te
      WHERE te.task_id = t.id AND te.executor_id = $1::uuid
    )
    OR EXISTS (
      SELECT 1
      FROM tasks_equipes tq
      JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
      WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
    )
    OR ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
    OR EXISTS (
      SELECT 1
      FROM executores_segmentos es
      WHERE es.executor_id = $1::uuid
        AND es.segmento_id = t.segmento_id
    )
  )
LIMIT 1;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id, $json.task_id]`

---

### 8. Check Task Permission (Para SAP e Chat)

```sql
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM tasks_executores te
      WHERE te.task_id = $3::uuid AND te.executor_id = $1::uuid
    ) THEN true
    WHEN EXISTS (
      SELECT 1
      FROM tasks_equipes tq
      JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
      WHERE tq.task_id = $3::uuid AND ee.executor_id = $1::uuid
    ) THEN true
    WHEN EXISTS (
      SELECT 1 FROM tasks t
      WHERE t.id = $3::uuid
        AND (
          ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
          OR EXISTS (
            SELECT 1
            FROM executores_segmentos es
            WHERE es.executor_id = $1::uuid
              AND es.segmento_id = t.segmento_id
          )
        )
    ) THEN true
    ELSE false
  END as has_access;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id, $json.task_id]`

---

### 9. Query Ordem (com validação de acesso)

```sql
WITH accessible_tasks AS (
  SELECT DISTINCT t.id as task_id
  FROM tasks t
  WHERE 
    -- Filtro de permissão
    (
      EXISTS (
        SELECT 1 FROM tasks_executores te
        WHERE te.task_id = t.id AND te.executor_id = $1::uuid
      )
      OR EXISTS (
        SELECT 1
        FROM tasks_equipes tq
        JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
        WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
      )
      OR ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
      OR EXISTS (
        SELECT 1
        FROM executores_segmentos es
        WHERE es.executor_id = $1::uuid
          AND es.segmento_id = t.segmento_id
      )
    )
)
SELECT 
  o.ordem,
  o.descricao,
  o.data_emissao,
  o.data_vencimento,
  string_agg(DISTINCT t.id::text, ', ') as task_ids,
  string_agg(DISTINCT t.tarefa, ' | ') as task_nomes
FROM ordens o
JOIN tasks_ordens to_rel ON to_rel.ordem_id = o.id
JOIN accessible_tasks at ON at.task_id = to_rel.task_id
JOIN tasks t ON t.id = at.task_id
WHERE o.ordem = $3::text
GROUP BY o.ordem, o.descricao, o.data_emissao, o.data_vencimento
LIMIT 1;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id, $json.ordem_num]`

---

### 10. Query Nota SAP (com validação de acesso)

```sql
WITH accessible_tasks AS (
  SELECT DISTINCT t.id as task_id
  FROM tasks t
  WHERE 
    (
      EXISTS (
        SELECT 1 FROM tasks_executores te
        WHERE te.task_id = t.id AND te.executor_id = $1::uuid
      )
      OR EXISTS (
        SELECT 1
        FROM tasks_equipes tq
        JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
        WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
      )
      OR ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
      OR EXISTS (
        SELECT 1
        FROM executores_segmentos es
        WHERE es.executor_id = $1::uuid
          AND es.segmento_id = t.segmento_id
      )
    )
)
SELECT 
  ns.nota,
  ns.descricao,
  ns.data_emissao,
  ns.data_vencimento,
  string_agg(DISTINCT t.id::text, ', ') as task_ids,
  string_agg(DISTINCT t.tarefa, ' | ') as task_nomes
FROM nota_sap ns
JOIN tasks_notas_sap tns_rel ON tns_rel.nota_sap_id = ns.id
JOIN accessible_tasks at ON at.task_id = tns_rel.task_id
JOIN tasks t ON t.id = at.task_id
WHERE ns.nota = $3::text
GROUP BY ns.nota, ns.descricao, ns.data_emissao, ns.data_vencimento
LIMIT 1;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id, $json.nota_num]`

---

### 11. Query SI (com validação de acesso)

```sql
WITH accessible_tasks AS (
  SELECT DISTINCT t.id as task_id
  FROM tasks t
  WHERE 
    (
      EXISTS (
        SELECT 1 FROM tasks_executores te
        WHERE te.task_id = t.id AND te.executor_id = $1::uuid
      )
      OR EXISTS (
        SELECT 1
        FROM tasks_equipes tq
        JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
        WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
      )
      OR ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
      OR EXISTS (
        SELECT 1
        FROM executores_segmentos es
        WHERE es.executor_id = $1::uuid
          AND es.segmento_id = t.segmento_id
      )
    )
)
SELECT 
  si.si,
  si.descricao,
  si.data_emissao,
  string_agg(DISTINCT t.id::text, ', ') as task_ids,
  string_agg(DISTINCT t.tarefa, ' | ') as task_nomes
FROM si
JOIN tasks_si tsi_rel ON tsi_rel.si_id = si.id
JOIN accessible_tasks at ON at.task_id = tsi_rel.task_id
JOIN tasks t ON t.id = at.task_id
WHERE si.si = $3::text
GROUP BY si.si, si.descricao, si.data_emissao
LIMIT 1;
```

**Parâmetros:** `[$json.executor_id, $json.divisao_id, $json.si_num]`

---

### 12. Query SAP Links (de uma tarefa específica)

```sql
SELECT 
  COALESCE(
    (SELECT string_agg(DISTINCT o.ordem, ', ')
     FROM tasks_ordens to_rel
     JOIN ordens o ON o.id = to_rel.ordem_id
     WHERE to_rel.task_id = $1::uuid),
    'Nenhuma'
  ) as ordens,
  COALESCE(
    (SELECT string_agg(DISTINCT ns.nota::text, ', ')
     FROM tasks_notas_sap tns_rel
     JOIN nota_sap ns ON ns.id = tns_rel.nota_sap_id
     WHERE tns_rel.task_id = $1::uuid),
    'Nenhuma'
  ) as notas,
  COALESCE(
    (SELECT string_agg(DISTINCT si.si, ', ')
     FROM tasks_si tsi_rel
     JOIN si ON si.id = tsi_rel.si_id
     WHERE tsi_rel.task_id = $1::uuid),
    'Nenhum'
  ) as sis,
  ttt.telegram_topic_id
FROM tasks t
LEFT JOIN telegram_task_topics ttt ON ttt.task_id = t.id
WHERE t.id = $1::uuid
LIMIT 1;
```

**Parâmetros:** `[$json.task_id]`

**Nota:** Esta query só é executada APÓS validação de permissão.

---

### 13. Query Chat Messages (de uma tarefa específica)

```sql
SELECT 
  m.id,
  m.conteudo,
  m.created_at,
  m.source,
  COALESCE(e.nome, u.email, 'Sistema') as autor_nome,
  gc.tarefa_id,
  t.tarefa as tarefa_nome
FROM mensagens m
JOIN grupos_chat gc ON gc.id = m.grupo_id
JOIN tasks t ON t.id = gc.tarefa_id
LEFT JOIN executores e ON e.id = m.usuario_id
LEFT JOIN auth.users u ON u.id = m.usuario_id
WHERE 
  gc.tarefa_id = $1::uuid
  AND m.deleted_at IS NULL
ORDER BY m.created_at DESC
LIMIT 5;
```

**Parâmetros:** `[$json.task_id]`

**Nota:** Esta query só é executada APÓS validação de permissão.

---

## 🔒 Sanitização de Inputs

### Function Node: Sanitize Input

```javascript
// Sanitizar inputs antes de usar em queries
const input = $input.item.json.params?.value || '';

// UUID: apenas hexadecimais e hífens
if (intent === 'id' || intent === 'sap' || intent === 'chat') {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input)) {
    throw new Error('UUID inválido');
  }
}

// Status: apenas valores permitidos
if (intent === 'status') {
  const allowed = ['ANDA', 'PROG', 'CONC', 'CANC', 'RPAR'];
  if (!allowed.includes(input.toUpperCase())) {
    throw new Error('Status inválido');
  }
}

// Números: apenas dígitos
if (intent === 'ordem' || intent === 'nota' || intent === 'si') {
  if (!/^\d+$/.test(input)) {
    throw new Error('Número inválido');
  }
}

// Texto: remover caracteres perigosos
if (intent === 'tarefa') {
  const sanitized = input.replace(/[;'\"\\]/g, '');
  return { json: { ...$input.item.json, search_text: sanitized } };
}

return { json: $input.item.json };
```

---

## 📊 Índices Recomendados

Execute estes índices no Supabase para melhorar performance:

```sql
-- Índices para validação de permissão
CREATE INDEX IF NOT EXISTS idx_tasks_executores_task_executor 
  ON tasks_executores(task_id, executor_id);

CREATE INDEX IF NOT EXISTS idx_equipes_executores_equipe_executor 
  ON equipes_executores(equipe_id, executor_id);

CREATE INDEX IF NOT EXISTS idx_tasks_equipes_task_equipe 
  ON tasks_equipes(task_id, equipe_id);

CREATE INDEX IF NOT EXISTS idx_executores_segmentos_executor_segmento 
  ON executores_segmentos(executor_id, segmento_id);

-- Índices para consultas de chat
CREATE INDEX IF NOT EXISTS idx_grupos_chat_tarefa_id 
  ON grupos_chat(tarefa_id);

CREATE INDEX IF NOT EXISTS idx_mensagens_grupo_created 
  ON mensagens(grupo_id, created_at DESC) 
  WHERE deleted_at IS NULL;

-- Índices para consultas SAP
CREATE INDEX IF NOT EXISTS idx_tasks_ordens_task_ordem 
  ON tasks_ordens(task_id, ordem_id);

CREATE INDEX IF NOT EXISTS idx_tasks_notas_sap_task_nota 
  ON tasks_notas_sap(task_id, nota_sap_id);

CREATE INDEX IF NOT EXISTS idx_tasks_si_task_si 
  ON tasks_si(task_id, si_id);
```
