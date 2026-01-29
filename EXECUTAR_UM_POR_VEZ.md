# 🔧 EXECUTAR ÍNDICES UM POR VEZ NO SUPABASE STUDIO

## ⚠️ O SUPABASE STUDIO TEM BUG NO PARSER

Execute **cada comando separadamente** no SQL Editor:

http://212.85.0.249:8000/project/default/sql/new

---

## 📝 **COMANDOS (COPIAR E COLAR UM POR VEZ):**

### **1. Índice data_lancamento:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_data_lancamento ON horas_sap(data_lancamento DESC);
```

### **2. Índice numero_pessoa:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_numero_pessoa ON horas_sap(numero_pessoa);
```

### **3. Índice centro_trabalho:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_centro_trabalho ON horas_sap(centro_trabalho_real);
```

### **4. Índice nome_empregado:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_nome_empregado ON horas_sap(nome_empregado);
```

### **5. Índice ordem:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_ordem ON horas_sap(ordem);
```

### **6. Índice status_sistema:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_status_sistema ON horas_sap(status_sistema);
```

### **7. Índice tipo_atividade_real:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_tipo_atividade_real ON horas_sap(tipo_atividade_real);
```

### **8. Índice COMPOSTO data + centro (MAIS IMPORTANTE!):**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_data_centro ON horas_sap(data_lancamento DESC, centro_trabalho_real);
```

### **9. Índice COMPOSTO numero + data:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_numero_data ON horas_sap(numero_pessoa, data_lancamento DESC);
```

### **10. Habilitar extensão pg_trgm:**
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

### **11. Índice GIN para centro_trabalho:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_centro_trgm ON horas_sap USING gin(centro_trabalho_real gin_trgm_ops);
```

### **12. Índice GIN para nome_empregado:**
```sql
CREATE INDEX IF NOT EXISTS idx_horas_sap_nome_trgm ON horas_sap USING gin(nome_empregado gin_trgm_ops);
```

### **13. Atualizar estatísticas:**
```sql
ANALYZE horas_sap;
```

---

## ✅ **RESULTADO ESPERADO PARA CADA COMANDO:**

```
CREATE INDEX
```

ou

```
NOTICE: relation "idx_horas_sap_..." already exists, skipping
CREATE INDEX
```

---

## 🎯 **APÓS EXECUTAR TODOS:**

Teste no Flutter:
- Hot Restart (R)
- Abra "Horas"
- Deve carregar rápido! ⚡

---

**⏱️ Tempo estimado:** 5-10 minutos (executar os 13 comandos)
