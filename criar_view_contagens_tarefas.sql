-- VIEW para contagens agregadas de itens vinculados a tarefas
-- Isso otimiza as contagens que antes eram feitas no frontend com múltiplas queries

-- VIEW para contagem de mensagens por tarefa
CREATE OR REPLACE VIEW public.contagens_mensagens_tarefas AS
SELECT 
    gc.tarefa_id as task_id,
    COUNT(m.id) as quantidade
FROM grupos_chat gc
LEFT JOIN mensagens m ON m.grupo_id = gc.id
GROUP BY gc.tarefa_id;

COMMENT ON VIEW public.contagens_mensagens_tarefas IS 'Contagem de mensagens por tarefa (otimizado)';

-- VIEW para contagem de anexos por tarefa
CREATE OR REPLACE VIEW public.contagens_anexos_tarefas AS
SELECT 
    task_id,
    COUNT(*) as quantidade
FROM anexos
GROUP BY task_id;

COMMENT ON VIEW public.contagens_anexos_tarefas IS 'Contagem de anexos por tarefa (otimizado)';

-- VIEW para contagem de notas SAP por tarefa
CREATE OR REPLACE VIEW public.contagens_notas_sap_tarefas AS
SELECT 
    task_id,
    COUNT(*) as quantidade
FROM tasks_notas_sap
GROUP BY task_id;

COMMENT ON VIEW public.contagens_notas_sap_tarefas IS 'Contagem de notas SAP por tarefa (otimizado)';

-- VIEW para contagem de ordens por tarefa
CREATE OR REPLACE VIEW public.contagens_ordens_tarefas AS
SELECT 
    task_id,
    COUNT(*) as quantidade
FROM tasks_ordens
GROUP BY task_id;

COMMENT ON VIEW public.contagens_ordens_tarefas IS 'Contagem de ordens por tarefa (otimizado)';

-- VIEW para contagem de ATs por tarefa
CREATE OR REPLACE VIEW public.contagens_ats_tarefas AS
SELECT 
    task_id,
    COUNT(*) as quantidade
FROM tasks_ats
GROUP BY task_id;

COMMENT ON VIEW public.contagens_ats_tarefas IS 'Contagem de ATs por tarefa (otimizado)';

-- VIEW para contagem de SIs por tarefa
CREATE OR REPLACE VIEW public.contagens_sis_tarefas AS
SELECT 
    task_id,
    COUNT(*) as quantidade
FROM tasks_sis
GROUP BY task_id;

COMMENT ON VIEW public.contagens_sis_tarefas IS 'Contagem de SIs por tarefa (otimizado)';

-- IMPORTANTE: VIEWs herdam as políticas RLS das tabelas base
-- Se as tabelas base (anexos, tasks_notas_sap, etc) têm RLS habilitado,
-- as VIEWs também terão. Certifique-se de que as políticas das tabelas base
-- permitem leitura para os usuários autenticados.

-- Recarregar o schema do PostgREST para que as novas VIEWs sejam reconhecidas
NOTIFY pgrst, 'reload schema';
