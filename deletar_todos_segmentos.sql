-- Script para deletar TODOS os segmentos do Gantt
-- ATENÇÃO: Esta operação é IRREVERSÍVEL!

-- Deletar todos os segmentos da tabela gantt_segments
DELETE FROM gantt_segments;

-- Verificar quantos segmentos restam (deve retornar 0)
SELECT COUNT(*) as total_segmentos FROM gantt_segments;

-- Opcional: Se quiser resetar o contador de sequência (se houver)
-- ALTER SEQUENCE gantt_segments_id_seq RESTART WITH 1;

