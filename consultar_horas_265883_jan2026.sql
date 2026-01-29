-- Consulta de horas apontadas do empregado 265883 em janeiro de 2026
-- Baseado no campo trabalho_real da tabela horas_sap
-- Inclui as ordens de trabalho

-- 1. Detalhamento completo de todas as horas apontadas com ordens
SELECT 
    id,
    data_lancamento,
    numero_pessoa,
    nome_empregado,
    ordem,
    tipo_ordem,
    operacao,
    tipo_atividade_real,
    trabalho_real,
    centro_trabalho_real,
    status_sistema,
    inicio_real,
    data_fim_real,
    hora_inicio_real,
    data_importacao,
    created_at,
    updated_at
FROM horas_sap
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
ORDER BY data_lancamento, ordem, created_at DESC;

-- 2. Resumo geral: Total de horas apontadas em janeiro de 2026
SELECT 
    numero_pessoa,
    nome_empregado,
    COUNT(*) as total_registros,
    SUM(trabalho_real) as total_horas_apontadas,
    MIN(data_lancamento) as primeira_data,
    MAX(data_lancamento) as ultima_data
FROM horas_sap
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY numero_pessoa, nome_empregado;

-- 3. Lista de ORDENS únicas com resumo de horas por ordem
SELECT 
    ordem,
    tipo_ordem,
    COUNT(*) as total_registros,
    SUM(trabalho_real) as total_horas_na_ordem,
    MIN(data_lancamento) as primeira_data,
    MAX(data_lancamento) as ultima_data,
    STRING_AGG(DISTINCT operacao, ', ' ORDER BY operacao) as operacoes,
    STRING_AGG(DISTINCT tipo_atividade_real, ', ' ORDER BY tipo_atividade_real) as tipos_atividade,
    STRING_AGG(DISTINCT centro_trabalho_real, ', ' ORDER BY centro_trabalho_real) as centros_trabalho
FROM horas_sap
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
  AND ordem IS NOT NULL
GROUP BY ordem, tipo_ordem
ORDER BY total_horas_na_ordem DESC, ordem;

-- 4. Detalhamento por ordem (agrupado por ordem e operação)
SELECT 
    ordem,
    tipo_ordem,
    operacao,
    tipo_atividade_real,
    COUNT(*) as quantidade_registros,
    SUM(trabalho_real) as horas_por_operacao,
    MIN(data_lancamento) as primeira_data,
    MAX(data_lancamento) as ultima_data
FROM horas_sap
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY ordem, tipo_ordem, operacao, tipo_atividade_real
ORDER BY ordem, horas_por_operacao DESC;

-- 5. Resumo separando horas normais e horas extras (HHE)
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
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY numero_pessoa, nome_empregado;

-- 6. Agrupamento por tipo de atividade (incluindo horas extras HHE)
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
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY numero_pessoa, nome_empregado, tipo_atividade_real
ORDER BY horas_por_tipo DESC;

-- 7. Lista simples de ORDENS únicas
SELECT DISTINCT
    ordem,
    tipo_ordem
FROM horas_sap
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
  AND ordem IS NOT NULL
ORDER BY ordem;

-- 8. Horas por ordem com detalhamento completo
SELECT 
    ordem,
    tipo_ordem,
    operacao,
    tipo_atividade_real,
    centro_trabalho_real,
    COUNT(*) as quantidade_registros,
    SUM(trabalho_real) as horas_totais,
    MIN(data_lancamento) as primeira_data,
    MAX(data_lancamento) as ultima_data,
    MIN(inicio_real) as inicio_mais_antigo,
    MAX(data_fim_real) as fim_mais_recente
FROM horas_sap
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY ordem, tipo_ordem, operacao, tipo_atividade_real, centro_trabalho_real
ORDER BY ordem, horas_totais DESC;

-- 9. Resumo diário de horas (agrupado por data)
SELECT 
    data_lancamento,
    COUNT(DISTINCT ordem) as total_ordens_dia,
    COUNT(*) as total_registros_dia,
    SUM(trabalho_real) as horas_apontadas_dia,
    STRING_AGG(DISTINCT ordem, ', ' ORDER BY ordem) as ordens_do_dia
FROM horas_sap
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
GROUP BY data_lancamento
ORDER BY data_lancamento;

-- 10. Verificar se há registros duplicados (usando registro mais novo)
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
WHERE numero_pessoa = '265883'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01'
ORDER BY data_lancamento, ordem, numero_duplicata;
