#!/bin/bash
# ============================================
# CORRIGIR TODOS OS TÓPICOS APONTANDO PARA GRUPO ERRADO
# ============================================

echo "==========================================="
echo "CORRIGIR TÓPICOS COM GRUPO ERRADO"
echo "==========================================="
echo ""

echo "1. Listando tópicos que podem estar no grupo errado:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  ttt.task_id,
  ttt.telegram_chat_id as grupo_telegram_atual,
  gc.comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  tc.telegram_chat_id as grupo_telegram_correto,
  CASE 
    WHEN ttt.telegram_chat_id = tc.telegram_chat_id THEN '✅ CORRETO'
    ELSE '❌ ERRADO'
  END as status
FROM telegram_task_topics ttt
JOIN grupos_chat gc ON gc.tarefa_id = ttt.task_id
JOIN comunidades c ON c.id = gc.comunidade_id
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
WHERE tc.telegram_chat_id IS NOT NULL
ORDER BY status, c.divisao_nome;
" 2>/dev/null

echo ""
echo "2. Para corrigir um tópico específico:"
echo "-------------------------------------------"
echo "  .\corrigir_topico_grupo_errado.ps1 -TaskId <TASK_ID>"
echo ""

echo "3. Para deletar todos os tópicos errados de uma vez:"
echo "-------------------------------------------"
read -p "Deseja deletar todos os tópicos que estão no grupo errado? (s/N): " CONFIRM

if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
  echo "Operação cancelada."
  exit 0
fi

echo ""
echo "Deletando tópicos errados..."
docker exec supabase-db psql -U postgres -d postgres -c "
DELETE FROM telegram_task_topics ttt
WHERE EXISTS (
  SELECT 1
  FROM grupos_chat gc
  JOIN comunidades c ON c.id = gc.comunidade_id
  JOIN telegram_communities tc ON tc.comunidade_id = c.id
  WHERE gc.tarefa_id = ttt.task_id
    AND ttt.telegram_chat_id != tc.telegram_chat_id
);
" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "✅ Tópicos errados deletados!"
  echo ""
  echo "Na próxima mensagem de cada tarefa, um novo tópico será criado no grupo correto."
else
  echo "❌ Erro ao deletar tópicos"
  exit 1
fi
