#!/bin/bash
# ============================================
# CONFIGURAR GRUPOS SEPARADOS POR COMUNIDADE
# ============================================

echo "==========================================="
echo "CONFIGURAR GRUPOS SEPARADOS POR COMUNIDADE"
echo "==========================================="
echo ""
echo "Este script vai ajudar você a configurar um grupo Telegram separado"
echo "para cada comunidade do Flutter."
echo ""
echo "IMPORTANTE:"
echo "1. Você precisa criar um grupo no Telegram para cada comunidade"
echo "2. Adicionar o bot @TaskFlow_chat_bot em cada grupo"
echo "3. Tornar o bot administrador com permissão 'Manage Topics'"
echo "4. Converter cada grupo para Fórum (Topics habilitado)"
echo "5. Obter o Chat ID de cada grupo"
echo ""

echo "Listando comunidades que precisam de grupo:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  CASE 
    WHEN tc.id IS NOT NULL THEN 'SIM'
    ELSE 'NAO'
  END as tem_grupo,
  tc.telegram_chat_id
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
ORDER BY c.divisao_nome, c.segmento_nome;
" 2>/dev/null

echo ""
echo "==========================================="
echo "INSTRUCOES"
echo "==========================================="
echo ""
echo "Para cada comunidade que ainda não tem grupo:"
echo "1. Crie um grupo no Telegram"
echo "2. Adicione o bot @TaskFlow_chat_bot"
echo "3. Torne o bot administrador com 'Manage Topics'"
echo "4. Converta para Fórum (Topics)"
echo "5. Obtenha o Chat ID do grupo"
echo ""
echo "Depois, use o script:"
echo "  .\cadastrar_grupo_comunidade.ps1"
echo ""
echo "Ou atualize manualmente na tabela telegram_communities"
echo ""
