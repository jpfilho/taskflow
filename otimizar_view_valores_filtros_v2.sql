-- ============================================
-- SQL PARA OTIMIZAR FUNÇÃO DE VALORES DE FILTROS (VERSÃO ULTRA SIMPLIFICADA)
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
--
-- Esta versão é MUITO mais simples e rápida, usando queries diretas
-- sem CTEs complexas aninhadas

-- Primeiro, garantir que os índices existam
CREATE INDEX IF NOT EXISTS idx_tasks_regional_id ON tasks(regional_id);
CREATE INDEX IF NOT EXISTS idx_tasks_divisao_id ON tasks(divisao_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status_id ON tasks(status_id);
CREATE INDEX IF NOT EXISTS idx_tasks_data_inicio_fim ON tasks(data_inicio, data_fim);
CREATE INDEX IF NOT EXISTS idx_gantt_segments_task_id ON gantt_segments(task_id);
CREATE INDEX IF NOT EXISTS idx_gantt_segments_periodo ON gantt_segments(data_inicio, data_fim);
CREATE INDEX IF NOT EXISTS idx_tasks_locais_task_id ON tasks_locais(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_executores_task_id ON tasks_executores(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_frotas_task_id ON tasks_frotas(task_id);

-- Função ULTRA SIMPLIFICADA e RÁPIDA
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
STABLE
AS $$
DECLARE
  v_data_inicio_min DATE;
  v_data_fim_max DATE;
BEGIN
  -- Converter timestamps para dates
  v_data_inicio_min := COALESCE(p_data_inicio_min::DATE, CURRENT_DATE - INTERVAL '1 year');
  v_data_fim_max := COALESCE(p_data_fim_max::DATE, CURRENT_DATE + INTERVAL '1 year');

  -- Query MUITO SIMPLES: buscar valores únicos diretamente das tabelas
  -- sem CTEs complexas, apenas com WHERE simples
  
  RETURN QUERY
  -- Regionais
  SELECT 'regionais'::TEXT, r.regional::TEXT
  FROM tasks t
  JOIN regionais r ON r.id = t.regional_id
  WHERE r.regional IS NOT NULL AND r.regional != ''
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR EXISTS (SELECT 1 FROM status s WHERE s.id = t.status_id AND (s.status = p_status OR s.codigo = p_status)))
    AND (p_regional IS NULL OR r.regional = p_regional)
    AND (p_divisao IS NULL OR EXISTS (SELECT 1 FROM divisoes d WHERE d.id = t.divisao_id AND d.divisao = p_divisao))
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR EXISTS (SELECT 1 FROM tasks_locais tl JOIN locais l ON l.id = tl.local_id WHERE tl.task_id = t.id AND l.local = p_local))
    AND (p_executor IS NULL OR EXISTS (SELECT 1 FROM tasks_executores te JOIN executores e ON e.id = te.executor_id WHERE te.task_id = t.id AND (e.nome = p_executor OR e.nome_completo = p_executor)))
    AND (p_frota IS NULL OR t.frota = p_frota OR EXISTS (SELECT 1 FROM tasks_frotas tf JOIN frota f ON f.id = tf.frota_id WHERE tf.task_id = t.id AND (f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)))
  GROUP BY r.regional
  
  UNION ALL
  
  -- Divisões
  SELECT 'divisoes'::TEXT, d.divisao::TEXT
  FROM tasks t
  JOIN divisoes d ON d.id = t.divisao_id
  WHERE d.divisao IS NOT NULL AND d.divisao != ''
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR EXISTS (SELECT 1 FROM status s WHERE s.id = t.status_id AND (s.status = p_status OR s.codigo = p_status)))
    AND (p_regional IS NULL OR EXISTS (SELECT 1 FROM regionais r WHERE r.id = t.regional_id AND r.regional = p_regional))
    AND (p_divisao IS NULL OR d.divisao = p_divisao)
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR EXISTS (SELECT 1 FROM tasks_locais tl JOIN locais l ON l.id = tl.local_id WHERE tl.task_id = t.id AND l.local = p_local))
    AND (p_executor IS NULL OR EXISTS (SELECT 1 FROM tasks_executores te JOIN executores e ON e.id = te.executor_id WHERE te.task_id = t.id AND (e.nome = p_executor OR e.nome_completo = p_executor)))
    AND (p_frota IS NULL OR t.frota = p_frota OR EXISTS (SELECT 1 FROM tasks_frotas tf JOIN frota f ON f.id = tf.frota_id WHERE tf.task_id = t.id AND (f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)))
  GROUP BY d.divisao
  
  UNION ALL
  
  -- Status
  SELECT 'status'::TEXT, s.status::TEXT
  FROM tasks t
  JOIN status s ON s.id = t.status_id
  WHERE s.status IS NOT NULL AND s.status != ''
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR s.status = p_status OR s.codigo = p_status)
    AND (p_regional IS NULL OR EXISTS (SELECT 1 FROM regionais r WHERE r.id = t.regional_id AND r.regional = p_regional))
    AND (p_divisao IS NULL OR EXISTS (SELECT 1 FROM divisoes d WHERE d.id = t.divisao_id AND d.divisao = p_divisao))
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR EXISTS (SELECT 1 FROM tasks_locais tl JOIN locais l ON l.id = tl.local_id WHERE tl.task_id = t.id AND l.local = p_local))
    AND (p_executor IS NULL OR EXISTS (SELECT 1 FROM tasks_executores te JOIN executores e ON e.id = te.executor_id WHERE te.task_id = t.id AND (e.nome = p_executor OR e.nome_completo = p_executor)))
    AND (p_frota IS NULL OR t.frota = p_frota OR EXISTS (SELECT 1 FROM tasks_frotas tf JOIN frota f ON f.id = tf.frota_id WHERE tf.task_id = t.id AND (f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)))
  GROUP BY s.status
  
  UNION ALL
  
  -- Locais
  SELECT 'locais'::TEXT, l.local::TEXT
  FROM tasks t
  JOIN tasks_locais tl ON tl.task_id = t.id
  JOIN locais l ON l.id = tl.local_id
  WHERE l.local IS NOT NULL AND l.local != ''
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR EXISTS (SELECT 1 FROM status s WHERE s.id = t.status_id AND (s.status = p_status OR s.codigo = p_status)))
    AND (p_regional IS NULL OR EXISTS (SELECT 1 FROM regionais r WHERE r.id = t.regional_id AND r.regional = p_regional))
    AND (p_divisao IS NULL OR EXISTS (SELECT 1 FROM divisoes d WHERE d.id = t.divisao_id AND d.divisao = p_divisao))
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR l.local = p_local)
    AND (p_executor IS NULL OR EXISTS (SELECT 1 FROM tasks_executores te JOIN executores e ON e.id = te.executor_id WHERE te.task_id = t.id AND (e.nome = p_executor OR e.nome_completo = p_executor)))
    AND (p_frota IS NULL OR t.frota = p_frota OR EXISTS (SELECT 1 FROM tasks_frotas tf JOIN frota f ON f.id = tf.frota_id WHERE tf.task_id = t.id AND (f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)))
  GROUP BY l.local
  
  UNION ALL
  
  -- Tipos
  SELECT 'tipos'::TEXT, t.tipo::TEXT
  FROM tasks t
  WHERE t.tipo IS NOT NULL AND t.tipo != ''
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR EXISTS (SELECT 1 FROM status s WHERE s.id = t.status_id AND (s.status = p_status OR s.codigo = p_status)))
    AND (p_regional IS NULL OR EXISTS (SELECT 1 FROM regionais r WHERE r.id = t.regional_id AND r.regional = p_regional))
    AND (p_divisao IS NULL OR EXISTS (SELECT 1 FROM divisoes d WHERE d.id = t.divisao_id AND d.divisao = p_divisao))
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR EXISTS (SELECT 1 FROM tasks_locais tl JOIN locais l ON l.id = tl.local_id WHERE tl.task_id = t.id AND l.local = p_local))
    AND (p_executor IS NULL OR EXISTS (SELECT 1 FROM tasks_executores te JOIN executores e ON e.id = te.executor_id WHERE te.task_id = t.id AND (e.nome = p_executor OR e.nome_completo = p_executor)))
    AND (p_frota IS NULL OR t.frota = p_frota OR EXISTS (SELECT 1 FROM tasks_frotas tf JOIN frota f ON f.id = tf.frota_id WHERE tf.task_id = t.id AND (f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)))
  GROUP BY t.tipo
  
  UNION ALL
  
  -- Executores
  SELECT 'executores'::TEXT, COALESCE(e.nome_completo, e.nome)::TEXT
  FROM tasks t
  JOIN tasks_executores te ON te.task_id = t.id
  JOIN executores e ON e.id = te.executor_id
  WHERE COALESCE(e.nome_completo, e.nome) IS NOT NULL AND COALESCE(e.nome_completo, e.nome) != ''
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR EXISTS (SELECT 1 FROM status s WHERE s.id = t.status_id AND (s.status = p_status OR s.codigo = p_status)))
    AND (p_regional IS NULL OR EXISTS (SELECT 1 FROM regionais r WHERE r.id = t.regional_id AND r.regional = p_regional))
    AND (p_divisao IS NULL OR EXISTS (SELECT 1 FROM divisoes d WHERE d.id = t.divisao_id AND d.divisao = p_divisao))
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR EXISTS (SELECT 1 FROM tasks_locais tl JOIN locais l ON l.id = tl.local_id WHERE tl.task_id = t.id AND l.local = p_local))
    AND (p_executor IS NULL OR e.nome = p_executor OR e.nome_completo = p_executor)
    AND (p_frota IS NULL OR t.frota = p_frota OR EXISTS (SELECT 1 FROM tasks_frotas tf JOIN frota f ON f.id = tf.frota_id WHERE tf.task_id = t.id AND (f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)))
  GROUP BY COALESCE(e.nome_completo, e.nome)
  
  UNION ALL
  
  -- Frotas (da tabela tasks_frotas)
  SELECT 'frotas'::TEXT, 
    CASE 
      WHEN f.placa IS NOT NULL AND f.placa != '' 
      THEN (f.nome || ' - ' || f.placa)::TEXT
      ELSE f.nome::TEXT
    END
  FROM tasks t
  JOIN tasks_frotas tf ON tf.task_id = t.id
  JOIN frota f ON f.id = tf.frota_id
  WHERE f.nome IS NOT NULL AND f.nome != ''
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR EXISTS (SELECT 1 FROM status s WHERE s.id = t.status_id AND (s.status = p_status OR s.codigo = p_status)))
    AND (p_regional IS NULL OR EXISTS (SELECT 1 FROM regionais r WHERE r.id = t.regional_id AND r.regional = p_regional))
    AND (p_divisao IS NULL OR EXISTS (SELECT 1 FROM divisoes d WHERE d.id = t.divisao_id AND d.divisao = p_divisao))
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR EXISTS (SELECT 1 FROM tasks_locais tl JOIN locais l ON l.id = tl.local_id WHERE tl.task_id = t.id AND l.local = p_local))
    AND (p_executor IS NULL OR EXISTS (SELECT 1 FROM tasks_executores te2 JOIN executores e2 ON e2.id = te2.executor_id WHERE te2.task_id = t.id AND (e2.nome = p_executor OR e2.nome_completo = p_executor)))
    AND (p_frota IS NULL OR f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)
  GROUP BY 
    CASE 
      WHEN f.placa IS NOT NULL AND f.placa != '' 
      THEN f.nome || ' - ' || f.placa
      ELSE f.nome
    END
  
  UNION ALL
  
  -- Frotas (campo antigo da tabela tasks)
  SELECT 'frotas'::TEXT, t.frota::TEXT
  FROM tasks t
  WHERE t.frota IS NOT NULL 
    AND t.frota != '' 
    AND t.frota != '-N/A-'
    AND NOT EXISTS (SELECT 1 FROM tasks_frotas tf2 WHERE tf2.task_id = t.id)
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR EXISTS (SELECT 1 FROM status s WHERE s.id = t.status_id AND (s.status = p_status OR s.codigo = p_status)))
    AND (p_regional IS NULL OR EXISTS (SELECT 1 FROM regionais r WHERE r.id = t.regional_id AND r.regional = p_regional))
    AND (p_divisao IS NULL OR EXISTS (SELECT 1 FROM divisoes d WHERE d.id = t.divisao_id AND d.divisao = p_divisao))
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR EXISTS (SELECT 1 FROM tasks_locais tl JOIN locais l ON l.id = tl.local_id WHERE tl.task_id = t.id AND l.local = p_local))
    AND (p_executor IS NULL OR EXISTS (SELECT 1 FROM tasks_executores te2 JOIN executores e2 ON e2.id = te2.executor_id WHERE te2.task_id = t.id AND (e2.nome = p_executor OR e2.nome_completo = p_executor)))
    AND (p_frota IS NULL OR t.frota = p_frota)
  GROUP BY t.frota
  
  UNION ALL
  
  -- Coordenadores
  SELECT 'coordenadores'::TEXT, t.coordenador::TEXT
  FROM tasks t
  WHERE t.coordenador IS NOT NULL AND t.coordenador != ''
    AND (
      EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id AND gs.data_inicio <= v_data_fim_max AND gs.data_fim >= v_data_inicio_min)
      OR (t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL AND t.data_inicio <= v_data_fim_max AND t.data_fim >= v_data_inicio_min)
    )
    AND (p_status IS NULL OR EXISTS (SELECT 1 FROM status s WHERE s.id = t.status_id AND (s.status = p_status OR s.codigo = p_status)))
    AND (p_regional IS NULL OR EXISTS (SELECT 1 FROM regionais r WHERE r.id = t.regional_id AND r.regional = p_regional))
    AND (p_divisao IS NULL OR EXISTS (SELECT 1 FROM divisoes d WHERE d.id = t.divisao_id AND d.divisao = p_divisao))
    AND (p_tipo IS NULL OR t.tipo = p_tipo)
    AND (p_coordenador IS NULL OR t.coordenador = p_coordenador)
    AND (p_local IS NULL OR EXISTS (SELECT 1 FROM tasks_locais tl JOIN locais l ON l.id = tl.local_id WHERE tl.task_id = t.id AND l.local = p_local))
    AND (p_executor IS NULL OR EXISTS (SELECT 1 FROM tasks_executores te JOIN executores e ON e.id = te.executor_id WHERE te.task_id = t.id AND (e.nome = p_executor OR e.nome_completo = p_executor)))
    AND (p_frota IS NULL OR t.frota = p_frota OR EXISTS (SELECT 1 FROM tasks_frotas tf JOIN frota f ON f.id = tf.frota_id WHERE tf.task_id = t.id AND (f.nome || ' - ' || f.placa = p_frota OR f.nome = p_frota)))
  GROUP BY t.coordenador
  
  ORDER BY tipo_filtro, valor;
END;
$$;

COMMENT ON FUNCTION public.get_valores_filtros IS 'Retorna valores únicos de filtros (versão ultra simplificada e rápida)';

-- Recarregar o schema do PostgREST
NOTIFY pgrst, 'reload schema';
