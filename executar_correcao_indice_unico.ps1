# Script para executar correcao do indice unico

$SERVER = "root@212.85.0.249"
$PROJECT_DIR = "/root/telegram-webhook"

Write-Host "Corrigindo indice unico..." -ForegroundColor Cyan
Write-Host ""

# Comando SQL para remover duplicatas e criar indice
$sqlFix = @"
-- Remover duplicatas mantendo apenas o mais recente
DELETE FROM telegram_delivery_logs
WHERE id IN (
  SELECT id
  FROM (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY telegram_chat_id, telegram_message_id 
             ORDER BY created_at DESC, id DESC
           ) as rn
    FROM telegram_delivery_logs
    WHERE telegram_chat_id IS NOT NULL 
      AND telegram_message_id IS NOT NULL 
      AND status = 'sent'
  ) ranked
  WHERE rn > 1
);

-- Criar indice unico
CREATE UNIQUE INDEX IF NOT EXISTS idx_telegram_delivery_logs_unique_lookup
  ON telegram_delivery_logs(telegram_chat_id, telegram_message_id)
  WHERE telegram_chat_id IS NOT NULL AND telegram_message_id IS NOT NULL AND status = 'sent';
"@

# Salvar SQL em arquivo temporario
$tempFile = "temp_fix_index.sql"
$sqlFix | Out-File -FilePath $tempFile -Encoding UTF8

# Enviar para servidor
scp $tempFile "${SERVER}:${PROJECT_DIR}/temp_fix_index.sql"

# Executar
$containerId = ssh $SERVER "docker ps -q -f name=supabase-db"
$execCmd = "cat " + $PROJECT_DIR + "/temp_fix_index.sql | docker exec -i " + $containerId + " psql -U postgres -d postgres"
ssh $SERVER $execCmd

# Limpar
Remove-Item $tempFile
ssh $SERVER "rm $PROJECT_DIR/temp_fix_index.sql"

Write-Host ""
Write-Host "OK: Correcao aplicada!" -ForegroundColor Green
