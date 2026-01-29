-- Deletar mensagem manualmente (usando valor permitido pela constraint)
-- A constraint permite apenas: 'flutter', 'telegram', ou UUID

UPDATE mensagens
SET 
    deleted_at = NOW(),
    deleted_by = 'flutter'  -- Usar 'flutter' ao invés de 'manual'
WHERE id = '6d9af518-bdcf-4cd5-91ed-03ea01baf413';

-- Verificar se foi deletada
SELECT
    id,
    conteudo,
    deleted_at,
    deleted_by,
    source
FROM mensagens
WHERE id = '6d9af518-bdcf-4cd5-91ed-03ea01baf413';
