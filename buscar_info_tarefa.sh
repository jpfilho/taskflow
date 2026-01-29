#!/bin/bash
# ============================================
# BUSCAR INFORMAÇÕES DA TAREFA
# ============================================

GRUPO_ID="369377cf-3678-43e2-8314-f4accf58575f"

echo "Buscando informações do grupo: $GRUPO_ID"
echo ""

# Buscar informações do grupo_chat
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    id,
    tarefa_id,
    tarefa_nome,
    comunidade_id,
    descricao,
    created_at
FROM grupos_chat
WHERE id = '$GRUPO_ID';
"

echo ""
echo "Buscando informações da tarefa relacionada..."
TAREFA_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT tarefa_id FROM grupos_chat WHERE id = '$GRUPO_ID';" | xargs)

if [ ! -z "$TAREFA_ID" ]; then
  docker exec supabase-db psql -U postgres -d postgres -c "
  SELECT 
      id,
      tarefa as descricao_tarefa,
      status,
      regional,
      divisao,
      local,
      executor,
      coordenador,
      data_inicio,
      data_fim
  FROM tasks
  WHERE id = '$TAREFA_ID';
  "
fi

echo ""
echo "Verificando mensagens recentes deste grupo..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    id,
    grupo_id,
    usuario_nome,
    conteudo,
    created_at
FROM mensagens
WHERE grupo_id = '$GRUPO_ID'
ORDER BY created_at DESC
LIMIT 5;
"
