# Explicação da Lógica da VIEW `notas_sap_com_prazo`

## Objetivo
Calcular automaticamente a data de vencimento e dias restantes para cada nota SAP, baseado nas regras de prazo cadastradas.

## Estrutura de Dados

### Tabelas Envolvidas:
1. **`notas_sap`** - Notas SAP (tem `text_prioridade`, `centro_trabalho_responsavel`, `criado_em`, `inicio_desejado`)
2. **`regras_prazo_notas`** - Regras de prazo (tem `prioridade`, `dias_prazo`, `data_referencia`, `ativo`)
3. **`regras_prazo_notas_segmentos`** - Tabela de junção (liga regras a segmentos)
4. **`segmentos`** - Segmentos cadastrados
5. **`centros_trabalho`** - Centros de trabalho (tem `centro_trabalho`, `segmento_id`)

## Fluxo da Lógica

### 1. Verificação Inicial
```sql
WHEN ns.text_prioridade IS NULL OR TRIM(ns.text_prioridade) = '' THEN NULL
```
- Se a nota não tem prioridade, não calcula prazo (retorna NULL)

### 2. Determinar Data de Referência
A VIEW verifica qual data usar para calcular o prazo, baseado nas regras cadastradas:
- **Se a nota tem `inicio_desejado`** → busca regras com `data_referencia = 'inicio_desejado'`
- **Se a nota tem `criado_em`** → busca regras com `data_referencia = 'criacao'`
- **Cada tipo de data tem sua própria regra específica na tabela de regras**
- Não há fallback: se não houver regra para `inicio_desejado`, não usa `criacao` como alternativa

### 3. Buscar Regra Apropriada

Para cada nota, a VIEW busca uma regra que:
1. **Corresponda à prioridade** (case-insensitive, sem acentos):
   ```sql
   UPPER(TRIM(TRANSLATE(rpn.prioridade, ...))) = UPPER(TRIM(TRANSLATE(ns.text_prioridade, ...)))
   ```

2. **Tenha a data de referência correta**:
   ```sql
   rpn.data_referencia = 'inicio_desejado' OU 'criacao'
   ```

3. **Esteja ativa**:
   ```sql
   rpn.ativo = true
   ```

4. **Se aplique à nota** (aqui está a lógica de segmentos):

### 4. Lógica de Segmentos (PARTE CRÍTICA)

A VIEW verifica se a regra se aplica à nota de duas formas:

#### A) Regra SEM Segmentos Específicos (Aplica a TODOS)
```sql
NOT EXISTS (
    SELECT 1 FROM regras_prazo_notas_segmentos rpns
    WHERE rpns.regra_prazo_nota_id = rpn.id
)
```
- Se a regra NÃO tem entradas na tabela `regras_prazo_notas_segmentos`, ela se aplica a TODAS as notas
- **Esta é a regra mais genérica e tem prioridade**

#### B) Regra COM Segmentos Específicos (Aplica apenas a segmentos específicos)
```sql
EXISTS (
    SELECT 1 
    FROM regras_prazo_notas_segmentos rpns
    WHERE rpns.regra_prazo_nota_id = rpn.id
      AND EXISTS (
          SELECT 1
          FROM segmentos s
          INNER JOIN centros_trabalho ct ON ct.segmento_id = s.id
          WHERE s.id = rpns.segmento_id
            AND ct.ativo = true
            AND (
                -- Verificar correspondência do centro de trabalho
                UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
                OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
                OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
            )
      )
)
```

**Como funciona:**
1. Busca todos os segmentos cadastrados na regra (`regras_prazo_notas_segmentos`)
2. Para cada segmento, busca todos os centros de trabalho que pertencem a ele
3. Verifica se o `centro_trabalho_responsavel` da nota corresponde (exato ou parcial) a algum desses centros

### 5. Priorização
```sql
ORDER BY 
    CASE WHEN NOT EXISTS (
        SELECT 1 FROM regras_prazo_notas_segmentos rpns
        WHERE rpns.regra_prazo_nota_id = rpn.id
    ) THEN 0 ELSE 1 END
LIMIT 1
```
- Regras SEM segmentos têm prioridade 0 (vêm primeiro)
- Regras COM segmentos têm prioridade 1 (vêm depois)
- Pega apenas a primeira regra encontrada (a mais genérica)

### 6. Cálculo Final
```sql
(ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date
```
- Data de referência + dias de prazo = data de vencimento

```sql
((ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date - CURRENT_DATE)::integer
```
- Data de vencimento - data atual = dias restantes

## Problemas Identificados

### Problema 1: Centros de Trabalho Não Estão na Tabela
- **Situação**: 8881 de 9400 notas de Média não têm centro na tabela `centros_trabalho`
- **Consequência**: Regras com segmentos específicos não conseguem verificar correspondência
- **Solução Atual**: Regras sem segmentos se aplicam a todas (mas não existem para Média, Urgência, Alta)

### Problema 2: Correspondência de Centros
- A VIEW verifica se o centro da nota está na tabela `centros_trabalho`
- Se não estiver, regras com segmentos não se aplicam
- **Possível correção**: Melhorar a lógica de correspondência ou criar regras sem segmentos

## Onde Pode Estar o Erro

1. **Correspondência de Centros**: A lógica atual exige que o centro esteja na tabela `centros_trabalho`. Se o centro da nota não estiver cadastrado, a regra com segmentos não se aplica.

2. **Lógica de Segmentos**: A verificação está aninhada (EXISTS dentro de EXISTS), o que pode estar causando problemas de performance ou lógica.

3. **Priorização**: A VIEW prioriza regras sem segmentos, mas se não existirem, tenta usar regras com segmentos. Se o centro não estiver na tabela, nenhuma regra se aplica.

## Sugestão de Correção

A lógica atual está correta, mas pode ser melhorada:

1. **Criar regras sem segmentos** para prioridades que têm muitas notas sem prazo
2. **Melhorar correspondência de centros** (talvez usando prefixos ou padrões)
3. **Simplificar a lógica** removendo um nível de EXISTS aninhado
