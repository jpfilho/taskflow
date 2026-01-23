-- ============================================
-- SQL PARA CRIAR FUNÇÃO DE VALORES DE FILTROS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
--
-- Esta função retorna valores únicos de cada campo de filtro,
-- considerando o período de datas e os filtros aplicados.
-- Isso otimiza o carregamento dos dropdowns de filtros.

-- Função para buscar valores únicos de filtros baseado em parâmetros
-- IMPORTANTE: Esta função usa SECURITY INVOKER para respeitar as políticas RLS
-- As políticas RLS da tabela tasks serão aplicadas automaticamente
CREATE OR REPLACE FUNCTION public.get_valores_filtros(
  p_data_inicio_min TIMESTAMP DEFAULT NULL,
  p_data_fim_max TIMESTAMP DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_regional TEXT DEFAULT NULL,
  p_divisao TEXT DEFAULT NULL,
  p_local TEXT DEFAULT NULL,
  p_tipo TEXT DEFAULT NULL,
  p_executor TEXT DEFAULT NULL,
  p_coordenador TEXT DEFAULT NULL,
  p_frota TEXT DEFAULT NULL
)
RETURNS TABLE (
  tipo_filtro TEXT,
  valor TEXT
) 
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_data_inicio_min DATE;
  v_data_fim_max DATE;
BEGIN
  -- Converter timestamps para dates se fornecidos
  v_data_inicio_min := COALESCE(p_data_inicio_min::DATE, CURRENT_DATE - INTERVAL '1 year');
  v_data_fim_max := COALESCE(p_data_fim_max::DATE, CURRENT_DATE + INTERVAL '1 year');

  RETURN QUERY
  WITH tarefas_filtradas AS (
    -- Tarefas que passam pelos filtros e estão no período
    SELECT DISTINCT t.id
    FROM tasks t
    LEFT JOIN regionais r ON r.id = t.regional_id
    LEFT JOIN divisoes d ON d.id = t.divisao_id
    LEFT JOIN status s ON s.id = t.status_id
    WHERE 
      -- Filtro de período: verificar se há segmentos no período OU se a tarefa está no período
      (
        EXISTS (
          SELECT 1 
          FROM gantt_segments gs 
          WHERE gs.task_id = t.id
            AND gs.data_inicio <= v_data_fim_max
            AND gs.data_fim >= v_data_inicio_min
        )
        OR (
          t.data_inicio IS NOT NULL 
          AND t.data_fim IS NOT NULL
          AND t.data_inicio <= v_data_fim_max
          AND t.data_fim >= v_data_inicio_min
        )
      )
      -- Filtros adicionais
      AND (p_status IS NULL OR s.status = p_status OR s.codigo = p_status)
      AND (p_regional IS NULL OR r.regional = p_regional)
      AND (p_divisao IS NULL OR d.divisao = p_divisao)
      AND (p_tipo IS NULL OR t.tipo = p_tipo)
      AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
      AND (
        p_local IS NULL 
        OR EXISTS (
          SELECT 1 
          FROM tasks_locais tl 
          JOIN locais l ON l.id = tl.local_id 
          WHERE tl.task_id = t.id AND l.local = p_local
        )
      )
      AND (
        p_executor IS NULL 
        OR EXISTS (
          SELECT 1 
          FROM tasks_executores te 
          JOIN executores e ON e.id = te.executor_id 
          WHERE te.task_id = t.id AND e.nome = p_executor
        )
      )
      AND (
        p_frota IS NULL 
        OR t.frota = p_frota
        OR EXISTS (
          SELECT 1 
          FROM tasks_frotas tf 
          JOIN frota f ON f.id = tf.frota_id 
          WHERE tf.task_id = t.id 
            AND (f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)
        )
      )
  ),
  -- Valores únicos de regionais
  regionais_unicos AS (
    SELECT DISTINCT r.regional as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    JOIN regionais r ON r.id = t.regional_id
    WHERE r.regional IS NOT NULL AND r.regional != ''
  ),
  -- Valores únicos de divisões
  divisoes_unicos AS (
    SELECT DISTINCT d.divisao as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    JOIN divisoes d ON d.id = t.divisao_id
    WHERE d.divisao IS NOT NULL AND d.divisao != ''
  ),
  -- Valores únicos de status
  status_unicos AS (
    SELECT DISTINCT s.status as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    JOIN status s ON s.id = t.status_id
    WHERE s.status IS NOT NULL AND s.status != ''
  ),
  -- Valores únicos de locais
  locais_unicos AS (
    SELECT DISTINCT l.local as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    JOIN tasks_locais tl ON tl.task_id = t.id
    JOIN locais l ON l.id = tl.local_id
    WHERE l.local IS NOT NULL AND l.local != ''
  ),
  -- Valores únicos de tipos
  tipos_unicos AS (
    SELECT DISTINCT t.tipo as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    WHERE t.tipo IS NOT NULL AND t.tipo != ''
  ),
  -- Valores únicos de executores
  executores_unicos AS (
    SELECT DISTINCT e.nome as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    JOIN tasks_executores te ON te.task_id = t.id
    JOIN executores e ON e.id = te.executor_id
    WHERE e.nome IS NOT NULL AND e.nome != ''
  ),
  -- Valores únicos de frotas
  frotas_unicos AS (
    SELECT DISTINCT 
      CASE 
        WHEN f.placa IS NOT NULL AND f.placa != '' 
        THEN f.nome || ' - ' || f.placa
        ELSE f.nome
      END as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    JOIN tasks_frotas tf2 ON tf2.task_id = t.id
    JOIN frota f ON f.id = tf2.frota_id
    WHERE f.nome IS NOT NULL AND f.nome != ''
    UNION
    SELECT DISTINCT t.frota as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    WHERE t.frota IS NOT NULL 
      AND t.frota != '' 
      AND t.frota != '-N/A-'
      AND NOT EXISTS (
        SELECT 1 FROM tasks_frotas tf2 WHERE tf2.task_id = t.id
      )
  ),
  -- Valores únicos de coordenadores
  coordenadores_unicos AS (
    SELECT DISTINCT e.nome as valor
    FROM tarefas_filtradas tf
    JOIN tasks t ON t.id = tf.id
    JOIN executores e ON e.nome = t.coordenador
    WHERE t.coordenador IS NOT NULL 
      AND t.coordenador != ''
      AND e.papel IN ('COORDENADOR', 'GERENTE DIVISÃO')
  )
  SELECT 'regional'::TEXT, valor FROM regionais_unicos
  UNION ALL
  SELECT 'divisao'::TEXT, valor FROM divisoes_unicos
  UNION ALL
  SELECT 'status'::TEXT, valor FROM status_unicos
  UNION ALL
  SELECT 'local'::TEXT, valor FROM locais_unicos
  UNION ALL
  SELECT 'tipo'::TEXT, valor FROM tipos_unicos
  UNION ALL
  SELECT 'executor'::TEXT, valor FROM executores_unicos
  UNION ALL
  SELECT 'frota'::TEXT, valor FROM frotas_unicos
  UNION ALL
  SELECT 'coordenador'::TEXT, valor FROM coordenadores_unicos
  ORDER BY tipo_filtro, valor;
END;
$$;

COMMENT ON FUNCTION public.get_valores_filtros IS 'Retorna valores únicos de filtros baseados em tarefas no período e filtros aplicados (otimizado para dropdowns)';

-- Recarregar o schema do PostgREST para que a nova função seja reconhecida
NOTIFY pgrst, 'reload schema';
