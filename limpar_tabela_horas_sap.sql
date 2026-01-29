-- ============================================================
-- COMANDOS PARA LIMPAR A TABELA horas_sap
-- ATENÇÃO: Estes comandos são DESTRUTIVOS e não podem ser revertidos!
-- ============================================================

-- OPÇÃO 1: TRUNCATE (MAIS RÁPIDO - Remove todos os dados e reseta contadores)
-- Use este comando se você tem certeza que quer limpar TUDO
-- Vantagem: Muito rápido, reseta auto-incremento
-- Desvantagem: Não pode ser revertido, não funciona se houver foreign keys
TRUNCATE TABLE horas_sap RESTART IDENTITY CASCADE;

-- OPÇÃO 2: DELETE (MAIS SEGURO - Remove dados mas mantém estrutura)
-- Use este comando se quiser mais controle ou se houver foreign keys
-- Vantagem: Pode usar WHERE para filtrar, pode ser revertido com transação
-- Desvantagem: Mais lento em tabelas grandes
-- DELETE FROM horas_sap;

-- OPÇÃO 3: DELETE COM WHERE (LIMPAR APENAS REGISTROS ESPECÍFICOS)
-- Use este se quiser limpar apenas registros de um período específico
-- Exemplo: Limpar apenas janeiro de 2026
-- DELETE FROM horas_sap 
-- WHERE data_lancamento >= '2026-01-01' 
--   AND data_lancamento < '2026-02-01';

-- OPÇÃO 4: DELETE COM WHERE (LIMPAR APENAS DO EMPREGADO 264259)
-- DELETE FROM horas_sap 
-- WHERE numero_pessoa = '264259';

-- ============================================================
-- COMANDOS DE VERIFICAÇÃO (Execute ANTES de limpar)
-- ============================================================

-- Verificar total de registros antes de limpar
SELECT COUNT(*) as total_registros_antes FROM horas_sap;

-- Verificar registros por ano/mês
SELECT 
    EXTRACT(YEAR FROM data_lancamento) as ano,
    EXTRACT(MONTH FROM data_lancamento) as mes,
    COUNT(*) as quantidade
FROM horas_sap
WHERE data_lancamento IS NOT NULL
GROUP BY EXTRACT(YEAR FROM data_lancamento), EXTRACT(MONTH FROM data_lancamento)
ORDER BY ano DESC, mes DESC;

-- Verificar registros do empregado 264259 em janeiro de 2026
SELECT COUNT(*) as total_registros_264259_jan2026
FROM horas_sap
WHERE numero_pessoa = '264259'
  AND data_lancamento >= '2026-01-01'
  AND data_lancamento < '2026-02-01';

-- ============================================================
-- COMANDO RECOMENDADO: TRUNCATE (Execute este para limpar tudo)
-- ============================================================
-- Descomente a linha abaixo quando estiver pronto para limpar:
-- TRUNCATE TABLE horas_sap RESTART IDENTITY CASCADE;

-- ============================================================
-- VERIFICAÇÃO APÓS LIMPEZA
-- ============================================================
-- Execute este comando DEPOIS de limpar para confirmar:
-- SELECT COUNT(*) as total_registros_depois FROM horas_sap;
-- Resultado esperado: 0
