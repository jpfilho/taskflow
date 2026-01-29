# 🔧 SOLUÇÃO PARA TIMEOUT NA TELA DE HORAS

## ❌ **PROBLEMA IDENTIFICADO:**

A tela "Horas" está apresentando **timeouts** do PostgreSQL (código 57014) por causa de:

1. **Queries lentas sem índices** - Filtros com `ILIKE` em campos sem índice
2. **COUNT ineficiente** - Buscava todos os IDs antes de contar
3. **Scans completos de tabela** - PostgreSQL varria toda a tabela `horas_sap`

---

## ✅ **SOLUÇÕES IMPLEMENTADAS:**

### 1. **Criado Script SQL com Índices Otimizados**

Arquivo: `otimizar_horas_sap_indices.sql`

**O que o script faz:**
- ✅ Cria índices para `data_lancamento` (ordenação)
- ✅ Cria índices para `centro_trabalho_real`, `numero_pessoa`, `nome_empregado`
- ✅ Cria índice composto `(data_lancamento, centro_trabalho_real)` - **CRÍTICO!**
- ✅ Habilita extensão `pg_trgm` para buscas ILIKE rápidas
- ✅ Cria view materializada `horas_sap_contagem_rapida` para contagens
- ✅ Cria view `horas_sap_por_empregado_mes` para agregações

### 2. **Otimizado Código Flutter**

Arquivo: `lib/services/hora_sap_service.dart`

**Mudança na função `contarHoras()`:**

**ANTES** (lento 🐢):
```dart
dynamic query = _supabase.from('horas_sap').select('id');
// ... filtros ...
final response = await query;
return (response as List).length; // Busca TODOS os IDs e conta localmente
```

**DEPOIS** (rápido ⚡):
```dart
dynamic query = _supabase.from('horas_sap').select().count(CountOption.exact);
// ... filtros ...
final response = await query;
return response.count ?? 0; // COUNT no servidor (não busca dados)
```

---

## 🚀 **COMO APLICAR A SOLUÇÃO:**

### **PASSO 1: Executar Script SQL no Supabase**

1. Acesse o Supabase Studio:
   ```
   http://212.85.0.249:8000/project/default/sql/new
   ```

2. Abra o arquivo no editor:
   ```
   otimizar_horas_sap_indices.sql
   ```

3. Copie TODO o conteúdo do arquivo

4. Cole no SQL Editor do Supabase

5. Clique em **"RUN"** ou pressione **Ctrl+Enter**

6. Aguarde alguns minutos ⏳ (os índices levam tempo para criar em tabelas grandes)

**✅ Sucesso esperado:**
```
CREATE INDEX
CREATE INDEX
CREATE INDEX
...
CREATE EXTENSION
CREATE MATERIALIZED VIEW
```

**⚠️ Se der erro "index already exists":**
- É normal! Significa que algum índice já existia
- Continue normalmente

### **PASSO 2: Teste no Flutter**

1. **Hot Restart** do app (ou reinicie):
   ```powershell
   # No terminal onde o Flutter está rodando:
   # Pressione: R (maiúsculo)
   ```

2. **Faça login** no app

3. **Navegue até "Horas"** na sidebar

4. **Aguarde** - Deve carregar **MUITO MAIS RÁPIDO** agora! ⚡

---

## 📊 **RESULTADOS ESPERADOS:**

### **ANTES:**
- ❌ Timeout após 30 segundos
- ❌ Erro: `PostgrestException code: 57014`
- ❌ Tela não carregava

### **DEPOIS:**
- ✅ Carregamento em **1-5 segundos**
- ✅ Paginação funciona perfeitamente
- ✅ Filtros rápidos
- ✅ Contagem instantânea

---

## 🔍 **VERIFICAÇÕES OPCIONAIS:**

### **Verificar Se Os Índices Foram Criados:**

```sql
SELECT 
  schemaname, 
  tablename, 
  indexname, 
  pg_size_pretty(pg_relation_size(indexrelid::regclass)) AS tamanho
FROM pg_stat_user_indexes 
WHERE tablename = 'horas_sap'
ORDER BY pg_relation_size(indexrelid::regclass) DESC;
```

**Índices esperados:**
- `idx_horas_sap_data_lancamento`
- `idx_horas_sap_data_centro` ⭐ **MAIS IMPORTANTE**
- `idx_horas_sap_numero_pessoa`
- `idx_horas_sap_centro_trgm`
- e outros...

### **Verificar Uso Dos Índices:**

```sql
SELECT 
  schemaname, 
  tablename, 
  indexname, 
  idx_scan AS vezes_usado,
  idx_tup_read AS linhas_lidas
FROM pg_stat_user_indexes 
WHERE tablename = 'horas_sap'
ORDER BY idx_scan DESC;
```

**Após usar a tela "Horas"**, `idx_scan` deve ser > 0 nos índices principais.

---

## 🛠️ **MANUTENÇÃO:**

### **Atualizar View Materializada (Após Importar Novos Dados):**

```sql
SELECT refresh_horas_sap_contagem();
```

**Quando fazer:**
- ✅ Após importar novos dados de horas SAP
- ✅ Uma vez por dia (automatize se possível)

### **Reindexar (Se Performance Degradar):**

```sql
REINDEX TABLE horas_sap;
ANALYZE horas_sap;
```

---

## 📝 **ARQUIVOS ALTERADOS:**

1. ✅ `otimizar_horas_sap_indices.sql` - **NOVO** (executar no Supabase)
2. ✅ `lib/services/hora_sap_service.dart` - **MODIFICADO** (já aplicado)
3. ✅ `lib/widgets/sidebar.dart` - **MODIFICADO** (liberado para todos)
4. ✅ `SOLUCAO_TIMEOUT_HORAS.md` - **NOVO** (este arquivo)

---

## ⚠️ **SE AINDA DER TIMEOUT:**

### **1. Verifique se os índices foram criados:**
```sql
\d horas_sap
-- Deve listar vários índices
```

### **2. Reduza a janela de data padrão:**

No arquivo `lib/widgets/horas_sap_view.dart`, linha 56:

**ATUAL:**
```dart
final dataInicioPadrao = DateTime(agora.year, agora.month - 3, 1); // Últimos 3 meses
```

**REDUZIR PARA 1 MÊS:**
```dart
final dataInicioPadrao = DateTime(agora.year, agora.month - 1, 1); // Último mês
```

### **3. Verifique estatísticas da tabela:**
```sql
ANALYZE horas_sap;
```

### **4. Aumentar timeout (última opção):**
```sql
ALTER DATABASE postgres SET statement_timeout = '60s'; -- Aumenta para 60s
```

---

## 🎯 **PRÓXIMOS PASSOS:**

1. ✅ Executar `otimizar_horas_sap_indices.sql` no Supabase
2. ✅ Reiniciar o Flutter app
3. ✅ Testar a tela "Horas"
4. ✅ Me avisar se funcionou! 🚀

---

**Qualquer dúvida ou erro, me avise!** 💬
