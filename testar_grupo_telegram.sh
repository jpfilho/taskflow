#!/bin/bash
# ============================================
# TESTAR GRUPO TELEGRAM - ENVIAR MENSAGEM DE TESTE
# ============================================

echo "==========================================="
echo "TESTAR GRUPO TELEGRAM"
echo "==========================================="
echo ""

echo "Para testar se o grupo está configurado corretamente:"
echo ""
echo "1. Envie uma mensagem no grupo 'NEPTRFMT - Linhas de Transmissão'"
echo "2. O bot deve:"
echo "   - Detectar o grupo"
echo "   - Verificar se é supergrupo com tópicos"
echo "   - Tentar associar à comunidade correspondente"
echo ""
echo "3. Se não identificar automaticamente, use no grupo:"
echo "   /associar"
echo "   (Isso listará as comunidades disponíveis)"
echo ""
echo "4. Depois use:"
echo "   /associar <ID_DA_COMUNIDADE>"
echo ""
echo "5. Para ver os logs em tempo real:"
echo "   journalctl -u telegram-webhook -f"
echo ""
