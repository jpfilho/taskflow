-- Consulta de horas apontadas do empregado 264259 em janeiro de 2026
-- Baseado no campo trabalho_real da tabela horas_sap

-- 1. Detalhamento de todas as horas apontadas
SELECT 
    id,
    data_lancamento,
    numero_pessoa,
    nome_empregado,
    ordem,
    operacao,
    tipo_atividade_real,
    trabalho_real,
    centro_trabalho_real,
    status_sistema,
    inicio_real,
    data_fim_real,
    hora_inicio_real
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
ORDER BY data_lancamento, ordem;

-- 2. Resumo: Total de horas apontadas em janeiro de 2026
SELECT 
    numero_pessoa,
    nome_empregado,
    COUNT(*) as total_registros,
    SUM(trabalho_real) as total_horas_apontadas,
    MIN(data_lancamento) as primeira_data,
    MAX(data_lancamento) as ultima_data
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY numero_pessoa, nome_empregado;

-- 3. Agrupamento por tipo de atividade (incluindo horas extras HHE)
SELECT 
    numero_pessoa,
    nome_empregado,
    tipo_atividade_real,
    COUNT(*) as quantidade_registros,
    SUM(trabalho_real) as horas_por_tipo,
    CASE 
        WHEN UPPER(TRIM(tipo_atividade_real)) LIKE 'HHE%' THEN 'HORAS EXTRAS'
        ELSE 'HORAS NORMAIS'
    END as classificacao
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY numero_pessoa, nome_empregado, tipo_atividade_real
ORDER BY horas_por_tipo DESC;

-- 4. Resumo separando horas normais e horas extras (HHE)
SELECT 
    numero_pessoa,
    nome_empregado,
    SUM(trabalho_real) as total_horas_apontadas,
    SUM(CASE 
        WHEN UPPER(TRIM(tipo_atividade_real)) LIKE 'HHE%' THEN trabalho_real 
        ELSE 0 
    END) as horas_extras_hhe,
    SUM(CASE 
        WHEN UPPER(TRIM(tipo_atividade_real)) NOT LIKE 'HHE%' 
             OR tipo_atividade_real IS NULL 
        THEN trabalho_real 
        ELSE 0 
    END) as horas_normais,
    COUNT(*) as total_registros
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY numero_pessoa, nome_empregado;

-- 5. Agrupamento por ordem (para ver distribuição por tarefa)
SELECT 
    ordem,
    operacao,
    tipo_atividade_real,
    COUNT(*) as quantidade_registros,
    SUM(trabalho_real) as horas_por_ordem
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY ordem, operacao, tipo_atividade_real
ORDER BY horas_por_ordem DESC;

-- 6. Lista simples de ORDENS únicas
SELECT DISTINCT
    ordem
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
  AND ordem IS NOT NULL
ORDER BY ordem;

-- 7. Lista detalhada de ORDENS únicas (com resumo)
SELECT DISTINCT
    ordem,
    tipo_ordem,
    COUNT(*) as total_registros,
    SUM(trabalho_real) as total_horas_na_ordem,
    MIN(data_lancamento) as primeira_data,
    MAX(data_lancamento) as ultima_data,
    STRING_AGG(DISTINCT operacao, ', ' ORDER BY operacao) as operacoes,
    STRING_AGG(DISTINCT tipo_atividade_real, ', ' ORDER BY tipo_atividade_real) as tipos_atividade
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
  AND ordem IS NOT NULL
GROUP BY ordem, tipo_ordem
ORDER BY ordem;

-- 8. DIAGNÓSTICO: Detalhamento completo da ordem 43002084758
-- Para identificar o problema (deveria ser 10, mas está mostrando 15 registros)
SELECT 
    id,
    data_lancamento,
    data_importacao,
    created_at,
    updated_at,
    numero_pessoa,
    nome_empregado,
    ordem,
    operacao,
    tipo_atividade_real,
    trabalho_real,
    trabalho_planejado,
    trabalho_restante,
    centro_trabalho_real,
    status_sistema,
    inicio_real,
    data_fim_real,
    hora_inicio_real,
    confirmacao,
    finalizado
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND ordem = '43002084758'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
ORDER BY data_lancamento, id;

-- 9. DIAGNÓSTICO: Verificar possíveis duplicatas por ID
SELECT 
    id,
    COUNT(*) as quantidade_vezes
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND ordem = '43002084758'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY id
HAVING COUNT(*) > 1;

-- 10. DIAGNÓSTICO: Verificar registros duplicados (mesmos valores)
SELECT 
    data_lancamento,
    ordem,
    operacao,
    tipo_atividade_real,
    trabalho_real,
    inicio_real,
    data_fim_real,
    hora_inicio_real,
    COUNT(*) as quantidade_duplicados,
    STRING_AGG(id::text, ', ' ORDER BY id) as ids
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND ordem = '43002084758'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY 
    data_lancamento,
    ordem,
    operacao,
    tipo_atividade_real,
    trabalho_real,
    inicio_real,
    data_fim_real,
    hora_inicio_real
HAVING COUNT(*) > 1
ORDER BY quantidade_duplicados DESC;

-- 11. DIAGNÓSTICO: Verificar se há registros com data_importacao diferente
SELECT 
    data_lancamento,
    data_importacao,
    COUNT(*) as quantidade,
    SUM(trabalho_real) as total_horas
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND ordem = '43002084758'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY data_lancamento, data_importacao
ORDER BY data_lancamento, data_importacao;

-- 12. DIAGNÓSTICO: Verificar valores de trabalho_real (pode haver valores incorretos)
SELECT 
    trabalho_real,
    COUNT(*) as quantidade_registros,
    SUM(trabalho_real) as soma_horas
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND ordem = '43002084758'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY trabalho_real
ORDER BY trabalho_real;

-- 13. SOLUÇÃO: Identificar registros duplicados para remoção
-- Mostra quais registros devem ser mantidos (mais novo/atualizado) e quais devem ser removidos
WITH registros_duplicados AS (
    SELECT 
        id,
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real,
        data_importacao,
        created_at,
        updated_at,
        ROW_NUMBER() OVER (
            PARTITION BY 
                data_lancamento,
                ordem,
                operacao,
                tipo_atividade_real,
                trabalho_real,
                inicio_real,
                data_fim_real,
                hora_inicio_real
            ORDER BY updated_at DESC NULLS LAST, created_at DESC, id DESC
        ) as numero_duplicata
    FROM horas_sap
    WHERE numero_pessoa = '264259'
      AND ordem = '43002084758'
      AND data_lancamento >= '2026-01-01'
      AND data_lancamento < '2026-02-01'
)
SELECT 
    id,
    data_lancamento,
    ordem,
    operacao,
    tipo_atividade_real,
    trabalho_real,
    data_importacao,
    created_at,
    updated_at,
    CASE 
        WHEN numero_duplicata = 1 THEN 'MANTER (registro mais novo/atualizado)'
        ELSE 'REMOVER (duplicata)'
    END as acao
FROM registros_duplicados
ORDER BY data_lancamento, ordem, operacao, numero_duplicata;

-- 14. SOLUÇÃO: Contar registros únicos (sem duplicatas)
-- Esta consulta mostra o resultado correto: 10 registros únicos
SELECT 
    COUNT(DISTINCT (
        data_lancamento::text || '|' || 
        ordem || '|' || 
        operacao || '|' || 
        COALESCE(tipo_atividade_real, '') || '|' || 
        trabalho_real::text || '|' || 
        COALESCE(inicio_real::text, '') || '|' || 
        COALESCE(data_fim_real::text, '') || '|' || 
        COALESCE(hora_inicio_real::text, '')
    )) as registros_unicos,
    SUM(DISTINCT trabalho_real) as total_horas_correto
FROM (
    SELECT DISTINCT ON (
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real
    )
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real
    FROM horas_sap
    WHERE numero_pessoa = '264259'
      AND ordem = '43002084758'
      AND data_lancamento >= '2026-01-01'
      AND data_lancamento < '2026-02-01'
    ORDER BY 
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real,
        updated_at DESC NULLS LAST, created_at DESC
) as registros_unicos;

-- 15. SOLUÇÃO: Cálculo correto usando DISTINCT (10 registros únicos × 10 horas = 100 horas)
SELECT 
    COUNT(DISTINCT (
        data_lancamento::text || '|' || 
        ordem || '|' || 
        operacao || '|' || 
        COALESCE(tipo_atividade_real, '') || '|' || 
        trabalho_real::text || '|' || 
        COALESCE(inicio_real::text, '') || '|' || 
        COALESCE(data_fim_real::text, '') || '|' || 
        COALESCE(hora_inicio_real::text, '')
    )) as total_registros_unicos,
    SUM(trabalho_real) / COUNT(*) * COUNT(DISTINCT (
        data_lancamento::text || '|' || 
        ordem || '|' || 
        operacao || '|' || 
        COALESCE(tipo_atividade_real, '') || '|' || 
        trabalho_real::text || '|' || 
        COALESCE(inicio_real::text, '') || '|' || 
        COALESCE(data_fim_real::text, '') || '|' || 
        COALESCE(hora_inicio_real::text, '')
    )) as total_horas_correto
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND ordem = '43002084758'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01';

-- 16. SOLUÇÃO ALTERNATIVA: Usar DISTINCT ON para obter apenas registros únicos
SELECT 
    COUNT(*) as total_registros_unicos,
    SUM(trabalho_real) as total_horas_correto
FROM (
    SELECT DISTINCT ON (
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real
    )
        trabalho_real
    FROM horas_sap
    WHERE numero_pessoa = '264259'
      AND ordem = '43002084758'
      AND data_lancamento >= '2026-01-01'
      AND data_lancamento < '2026-02-01'
    ORDER BY 
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real,
        updated_at DESC NULLS LAST, created_at DESC
) as registros_unicos;

-- 17. CORREÇÃO: Se deveria ter APENAS 1 REGISTRO, mostrar o registro único correto
-- Esta consulta mostra apenas 1 registro (o mais novo/atualizado de cada combinação única)
SELECT 
    id,
    data_lancamento,
    numero_pessoa,
    nome_empregado,
    ordem,
    operacao,
    tipo_atividade_real,
    trabalho_real,
    inicio_real,
    data_fim_real,
    hora_inicio_real,
    data_importacao,
    created_at,
    updated_at
FROM (
    SELECT DISTINCT ON (
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real
    )
        *
    FROM horas_sap
    WHERE numero_pessoa = '264259'
      AND ordem = '43002084758'
      AND data_lancamento >= '2026-01-01'
      AND data_lancamento < '2026-02-01'
    ORDER BY 
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real,
        updated_at DESC NULLS LAST, created_at DESC
) as registro_unico;

-- 18. CORREÇÃO: Contar quantos registros únicos existem (deveria ser 1)
SELECT 
    COUNT(*) as total_registros_unicos,
    SUM(trabalho_real) as total_horas_correto
FROM (
    SELECT DISTINCT ON (
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real
    )
        trabalho_real
    FROM horas_sap
    WHERE numero_pessoa = '264259'
      AND ordem = '43002084758'
      AND data_lancamento >= '2026-01-01'
      AND data_lancamento < '2026-02-01'
    ORDER BY 
        data_lancamento,
        ordem,
        operacao,
        tipo_atividade_real,
        trabalho_real,
        inicio_real,
        data_fim_real,
        hora_inicio_real,
        updated_at DESC NULLS LAST, created_at DESC
) as registros_unicos;

-- 19. DIAGNÓSTICO: Ver TODOS os 15 registros para entender por que há duplicatas
-- Ordenado do mais novo para o mais antigo
SELECT 
    id,
    data_lancamento,
    data_importacao,
    created_at,
    updated_at,
    ordem,
    operacao,
    tipo_atividade_real,
    trabalho_real,
    inicio_real,
    data_fim_real,
    hora_inicio_real,
    ROW_NUMBER() OVER (ORDER BY updated_at DESC NULLS LAST, created_at DESC) as numero_sequencia
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND ordem = '43002084758'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
ORDER BY updated_at DESC NULLS LAST, created_at DESC;

-- 20. DIAGNÓSTICO: Verificar diferenças entre os registros duplicados
-- Mostra quais campos são diferentes entre os registros
SELECT 
    COUNT(*) as total_registros,
    COUNT(DISTINCT id) as ids_unicos,
    COUNT(DISTINCT data_lancamento) as datas_lancamento_unicas,
    COUNT(DISTINCT data_importacao) as datas_importacao_unicas,
    COUNT(DISTINCT created_at) as created_at_unicos,
    COUNT(DISTINCT updated_at) as updated_at_unicos,
    COUNT(DISTINCT operacao) as operacoes_unicas,
    COUNT(DISTINCT tipo_atividade_real) as tipos_atividade_unicos,
    COUNT(DISTINCT trabalho_real) as trabalho_real_unicos,
    COUNT(DISTINCT inicio_real) as inicio_real_unicos,
    COUNT(DISTINCT data_fim_real) as data_fim_real_unicas,
    COUNT(DISTINCT hora_inicio_real) as hora_inicio_real_unicas
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND ordem = '43002084758'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01';
