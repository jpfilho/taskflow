# Instruções para Corrigir Estrutura de Divisões-Segmentos no Supabase

## Problema Identificado

O problema ao editar segmentos das divisões pode estar relacionado à estrutura da tabela `divisoes_segmentos` no Supabase. Possíveis causas:

1. **Estrutura incorreta**: A tabela pode ter sido criada com uma coluna `id` separada ao invés de chave primária composta `(divisao_id, segmento_id)`
2. **Políticas RLS restritivas**: As políticas podem estar exigindo autenticação quando deveriam permitir todas as operações
3. **Dados não migrados**: Os dados existentes podem não ter sido migrados para a nova estrutura

## Solução

Execute os scripts SQL na seguinte ordem no Supabase Dashboard:

### 1. Verificar Estrutura Atual

Primeiro, verifique como a tabela está estruturada atualmente:

```sql
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos'
ORDER BY ordinal_position;
```

### 2. Executar Script de Correção

Execute o script `corrigir_estrutura_divisoes_segmentos.sql` que:

- ✅ Cria a tabela `divisoes_segmentos` com chave primária composta
- ✅ Migra dados existentes da coluna `segmento_id` da tabela `divisoes`
- ✅ Configura políticas RLS corretas (permitindo todas as operações)
- ✅ Cria índices para melhor performance

### 3. Se a Tabela Já Existe com Estrutura Incorreta

Se a tabela já foi criada com uma coluna `id` separada, execute o script `migrar_divisoes_segmentos_para_chave_composta.sql` que:

- ✅ Faz backup dos dados
- ✅ Remove a coluna `id` antiga
- ✅ Cria chave primária composta `(divisao_id, segmento_id)`
- ✅ Remove duplicatas
- ✅ Corrige políticas RLS

### 4. Verificar Resultado

Após executar os scripts, verifique:

```sql
-- Verificar estrutura
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos'
ORDER BY ordinal_position;

-- Verificar chave primária
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'divisoes_segmentos'
    AND tc.constraint_type = 'PRIMARY KEY';

-- Verificar dados
SELECT 
    COUNT(*) as total_relacionamentos,
    COUNT(DISTINCT divisao_id) as total_divisoes,
    COUNT(DISTINCT segmento_id) as total_segmentos
FROM divisoes_segmentos;
```

## Estrutura Esperada

A tabela `divisoes_segmentos` deve ter a seguinte estrutura:

```sql
CREATE TABLE divisoes_segmentos (
    divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE CASCADE,
    segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (divisao_id, segmento_id)
);
```

**Importante**: A chave primária deve ser composta `(divisao_id, segmento_id)`, **NÃO** uma coluna `id` separada.

## Políticas RLS Esperadas

A política RLS deve ser:

```sql
CREATE POLICY "Permitir todas as operações em divisoes_segmentos" 
    ON divisoes_segmentos
    FOR ALL 
    USING (true) 
    WITH CHECK (true);
```

Isso permite todas as operações sem exigir autenticação específica, compatível com as outras tabelas do sistema.

## Após Executar os Scripts

1. Teste a edição de uma divisão no aplicativo
2. Verifique se os segmentos são carregados corretamente
3. Tente salvar alterações nos segmentos
4. Verifique os logs do console para ver se há erros

Se ainda houver problemas, verifique os logs do console do aplicativo para identificar onde está falhando.







