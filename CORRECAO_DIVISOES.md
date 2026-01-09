# Correção: Cadastro e Edição de Divisões

## Problema Identificado

A constraint UNIQUE estava aplicada globalmente na coluna `divisao`, impedindo que uma regional tivesse várias divisões com o mesmo nome. Porém, o correto é:
- **Uma regional pode ter várias divisões**
- **Uma divisão pode ter vários segmentos**
- **O nome da divisão deve ser único APENAS dentro da mesma regional**

## Solução Implementada

### 1. Script SQL de Correção

Execute o script `corrigir_unique_divisoes.sql` no Supabase Dashboard:

```sql
-- Remove a constraint UNIQUE global da coluna divisao
-- Adiciona constraint UNIQUE composta (divisao, regional_id)
```

Este script:
- Remove a constraint `divisoes_divisao_key` (UNIQUE global)
- Adiciona a constraint `divisoes_divisao_regional_id_key` (UNIQUE composta)
- Verifica duplicatas antes de aplicar

### 2. Validação no Código Flutter

O `DivisaoService` foi atualizado para:
- Verificar duplicatas por `regional_id` (não globalmente)
- Mensagens de erro mais específicas: "Já existe uma divisão com o nome X nesta regional"

### 3. Scripts de Criação Atualizados

Os scripts `criar_tabela_divisoes.sql` e `supabase_schema.sql` foram atualizados para:
- Remover `UNIQUE` da coluna `divisao`
- Adicionar `UNIQUE(divisao, regional_id)` na criação da tabela

## Como Aplicar

1. **Execute o script SQL de correção:**
   - Acesse o Supabase Dashboard
   - Vá para SQL Editor
   - Execute `corrigir_unique_divisoes.sql`

2. **Teste o cadastro:**
   - Tente criar duas divisões com o mesmo nome em regionais diferentes (deve funcionar)
   - Tente criar duas divisões com o mesmo nome na mesma regional (deve dar erro)

## Estrutura Correta

```
Regional 1
  ├── Divisão A (única na Regional 1)
  │   ├── Segmento 1
  │   └── Segmento 2
  └── Divisão B (única na Regional 1)
      └── Segmento 3

Regional 2
  ├── Divisão A (única na Regional 2) ✅ Pode ter mesmo nome
  │   └── Segmento 1
  └── Divisão C (única na Regional 2)
```

## Arquivos Modificados

- `corrigir_unique_divisoes.sql` (novo)
- `lib/services/divisao_service.dart` (atualizado)
- `criar_tabela_divisoes.sql` (atualizado)
- `supabase_schema.sql` (atualizado)






