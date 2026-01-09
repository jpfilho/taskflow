-- ============================================
-- SQL PARA CORRIGIR ENCODING DOS DADOS JÁ SALVOS NA TABELA NOTAS_SAP
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Este script corrige caracteres que foram salvos incorretamente
-- assumindo que foram salvos como Latin-1 mas precisam ser UTF-8

-- Função para corrigir encoding de uma string
-- Converte de Latin-1 (ISO-8859-1) para UTF-8
CREATE OR REPLACE FUNCTION corrigir_encoding_latin1_para_utf8(texto TEXT)
RETURNS TEXT AS $$
BEGIN
  -- Se o texto for NULL ou vazio, retornar como está
  IF texto IS NULL OR texto = '' THEN
    RETURN texto;
  END IF;
  
  -- Tentar converter usando convert() do PostgreSQL
  -- Primeiro, tentar decodificar como Latin-1 e re-encodar como UTF-8
  BEGIN
    -- Converter de LATIN1 para UTF8
    RETURN convert_from(convert_to(texto, 'LATIN1'), 'UTF8');
  EXCEPTION
    WHEN OTHERS THEN
      -- Se falhar, retornar original
      RETURN texto;
  END;
END;
$$ LANGUAGE plpgsql;

-- Corrigir campo descricao
UPDATE notas_sap
SET descricao = corrigir_encoding_latin1_para_utf8(descricao)
WHERE descricao IS NOT NULL
  AND (descricao LIKE '%operao%' 
    OR descricao LIKE '%PSSARO%'R
    OR descricao LIKE '%LEO%'
    OR descricao LIKE '%ALIMENTAO%'
    OR descricao LIKE '%SEGURAN%'
    OR descricao LIKE '%RELE%'
    OR descricao LIKE '%PRESSO%'
    OR descricao ~ '[^\x00-\x7F]'); -- Contém caracteres não-ASCII

-- Corrigir campo text_prioridade
UPDATE notas_sap
SET text_prioridade = corrigir_encoding_latin1_para_utf8(text_prioridade)
WHERE text_prioridade IS NOT NULL
  AND (text_prioridade LIKE '%edia%' 
    OR text_prioridade ~ '[^\x00-\x7F]');

-- Corrigir campo denominacao_executor
UPDATE notas_sap
SET denominacao_executor = corrigir_encoding_latin1_para_utf8(denominacao_executor)
WHERE denominacao_executor IS NOT NULL
  AND denominacao_executor ~ '[^\x00-\x7F]';

-- Corrigir campo local_instalacao
UPDATE notas_sap
SET local_instalacao = corrigir_encoding_latin1_para_utf8(local_instalacao)
WHERE local_instalacao IS NOT NULL
  AND local_instalacao ~ '[^\x00-\x7F]';

-- Corrigir campo equipamento
UPDATE notas_sap
SET equipamento = corrigir_encoding_latin1_para_utf8(equipamento)
WHERE equipamento IS NOT NULL
  AND equipamento ~ '[^\x00-\x7F]';

-- Corrigir campo centro_trabalho_responsavel
UPDATE notas_sap
SET centro_trabalho_responsavel = corrigir_encoding_latin1_para_utf8(centro_trabalho_responsavel)
WHERE centro_trabalho_responsavel IS NOT NULL
  AND centro_trabalho_responsavel ~ '[^\x00-\x7F]';

-- Corrigir campo ordem
UPDATE notas_sap
SET ordem = corrigir_encoding_latin1_para_utf8(ordem)
WHERE ordem IS NOT NULL
  AND ordem ~ '[^\x00-\x7F]';

-- Corrigir campo sala
UPDATE notas_sap
SET sala = corrigir_encoding_latin1_para_utf8(sala)
WHERE sala IS NOT NULL
  AND sala ~ '[^\x00-\x7F]';

-- Corrigir campo status_sistema
UPDATE notas_sap
SET status_sistema = corrigir_encoding_latin1_para_utf8(status_sistema)
WHERE status_sistema IS NOT NULL
  AND status_sistema ~ '[^\x00-\x7F]';

-- Corrigir campo status_usuario
UPDATE notas_sap
SET status_usuario = corrigir_encoding_latin1_para_utf8(status_usuario)
WHERE status_usuario IS NOT NULL
  AND status_usuario ~ '[^\x00-\x7F]';

-- Corrigir campo notificacao
UPDATE notas_sap
SET notificacao = corrigir_encoding_latin1_para_utf8(notificacao)
WHERE notificacao IS NOT NULL
  AND notificacao ~ '[^\x00-\x7F]';

-- Corrigir campo centro
UPDATE notas_sap
SET centro = corrigir_encoding_latin1_para_utf8(centro)
WHERE centro IS NOT NULL
  AND centro ~ '[^\x00-\x7F]';

-- Corrigir campo de
UPDATE notas_sap
SET de = corrigir_encoding_latin1_para_utf8(de)
WHERE de IS NOT NULL
  AND de ~ '[^\x00-\x7F]';

-- Corrigir campo gpm
UPDATE notas_sap
SET gpm = corrigir_encoding_latin1_para_utf8(gpm)
WHERE gpm IS NOT NULL
  AND gpm ~ '[^\x00-\x7F]';

-- Corrigir campo campo_ordenacao
UPDATE notas_sap
SET campo_ordenacao = corrigir_encoding_latin1_para_utf8(campo_ordenacao)
WHERE campo_ordenacao IS NOT NULL
  AND campo_ordenacao ~ '[^\x00-\x7F]';

-- Verificar resultados
SELECT 
    nota,
    descricao,
    text_prioridade,
    CASE 
        WHEN descricao ~ '[^\x00-\x7F]' THEN 'Contém caracteres não-ASCII'
        ELSE 'Apenas ASCII'
    END as encoding_status
FROM notas_sap
WHERE descricao LIKE '%opera%' 
   OR descricao LIKE '%PSSARO%'
   OR descricao LIKE '%LEO%'
   OR text_prioridade LIKE '%edia%'
LIMIT 20;

-- Remover a função auxiliar após uso (opcional)
-- DROP FUNCTION IF EXISTS corrigir_encoding_latin1_para_utf8(TEXT);

