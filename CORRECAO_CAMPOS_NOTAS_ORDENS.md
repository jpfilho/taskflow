# Correção: Campos de Notas e Ordens

## ✅ Campos Corretos Identificados

### Tabela `notas_sap`
- **Campo identificador:** `nota` (VARCHAR(50), UNIQUE)
- **NÃO existe** campo `numero`
- **Campo descrição:** `descricao` (TEXT)

### Tabela `ordens`
- **Campo identificador:** `ordem` (TEXT, UNIQUE)
- **NÃO existe** campo `numero`
- **Campo descrição:** `texto_breve` (TEXT)

## 📝 Arquivos Atualizados

Todos os arquivos foram atualizados para usar os campos corretos:

1. ✅ **`queries_buscar_notas_ordens.sql`**
   - `ns.numero` → `ns.nota`
   - `o.numero` → `o.ordem`
   - `o.descricao` → `o.texto_breve`

2. ✅ **`PROPOSTA_TAGS_NOTAS_ORDENS.md`**
   - Queries atualizadas
   - Código Node.js atualizado
   - Código Flutter atualizado

3. ✅ **`EXEMPLOS_PAYLOAD_TAGS.md`**
   - Exemplos de queries atualizados
   - Código Dart atualizado

## 🔍 Queries Corretas

### Buscar Notas de uma Tarefa

```sql
SELECT 
    ns.id AS nota_id,
    ns.nota AS nota_numero,  -- ✅ Campo correto
    ns.descricao,
    COUNT(DISTINCT m.id) AS total_mensagens
FROM tasks_notas_sap tns
JOIN notas_sap ns ON ns.id = tns.nota_sap_id
LEFT JOIN mensagens m ON m.ref_type = 'NOTA' 
    AND m.ref_id = ns.id 
    AND m.deleted_at IS NULL
WHERE tns.task_id = '<task_id>'
GROUP BY ns.id, ns.nota, ns.descricao
ORDER BY ns.nota;  -- ✅ Ordenar por 'nota'
```

### Buscar Ordens de uma Tarefa

```sql
SELECT 
    o.id AS ordem_id,
    o.ordem AS ordem_numero,  -- ✅ Campo correto
    o.texto_breve AS ordem_descricao,  -- ✅ Campo correto
    COUNT(DISTINCT m.id) AS total_mensagens
FROM tasks_ordens to_rel
JOIN ordens o ON o.id = to_rel.ordem_id
LEFT JOIN mensagens m ON m.ref_type = 'ORDEM' 
    AND m.ref_id = o.id 
    AND m.deleted_at IS NULL
WHERE to_rel.task_id = '<task_id>'
GROUP BY o.id, o.ordem, o.texto_breve
ORDER BY o.ordem;  -- ✅ Ordenar por 'ordem'
```

## 💻 Código Node.js Corrigido

```javascript
// Buscar nota para gerar label
if (ref_type === 'NOTA') {
  const { data: nota } = await supabase
    .from('notas_sap')
    .select('nota')  // ✅ Campo correto
    .eq('id', ref_id)
    .single();
  mensagemData.ref_label = nota ? `NOTA ${nota.nota}` : null;  // ✅
}

// Buscar ordem para gerar label
if (ref_type === 'ORDEM') {
  const { data: ordem } = await supabase
    .from('ordens')
    .select('ordem')  // ✅ Campo correto
    .eq('id', ref_id)
    .single();
  mensagemData.ref_label = ordem ? `ORDEM ${ordem.ordem}` : null;  // ✅
}
```

## 📱 Código Flutter Corrigido

```dart
// Buscar notas
final response = await _supabase
    .from('tasks_notas_sap')
    .select('nota_sap_id, notas_sap(nota, descricao)')  // ✅ Campo correto
    .eq('task_id', taskId);

_refOptions = response.map((item) {
  final nota = item['notas_sap'];
  return RefOption(
    id: item['nota_sap_id'],
    label: 'NOTA ${nota['nota']}',  // ✅ Campo correto
  );
}).toList();

// Buscar ordens
final response = await _supabase
    .from('tasks_ordens')
    .select('ordem_id, ordens(ordem, texto_breve)')  // ✅ Campos corretos
    .eq('task_id', taskId);

_refOptions = response.map((item) {
  final ordem = item['ordens'];
  return RefOption(
    id: item['ordem_id'],
    label: 'ORDEM ${ordem['ordem']}',  // ✅ Campo correto
  );
}).toList();
```

## ✅ Validação

Execute estas queries para validar:

```sql
-- Verificar estrutura de notas_sap
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'notas_sap' 
  AND column_name IN ('nota', 'numero', 'descricao');

-- Verificar estrutura de ordens
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'ordens' 
  AND column_name IN ('ordem', 'numero', 'texto_breve', 'descricao');

-- Testar busca de notas
SELECT id, nota, descricao 
FROM notas_sap 
LIMIT 5;

-- Testar busca de ordens
SELECT id, ordem, texto_breve 
FROM ordens 
LIMIT 5;
```

## 🎯 Próximos Passos

1. ✅ **Campos corrigidos** em todos os arquivos
2. ⏭️ **Executar migração** (`migration_adicionar_tags_mensagens.sql`)
3. ⏭️ **Implementar Flutter** usando campos corretos
4. ⏭️ **Implementar Node.js** usando campos corretos
5. ⏭️ **Testar** com dados reais

Tudo pronto para implementar com os campos corretos! 🚀
