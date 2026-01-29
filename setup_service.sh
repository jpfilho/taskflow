#!/bin/bash
# ============================================
# CONFIGURAR SERVICO SYSTEMD
# ============================================

cat > /etc/systemd/system/telegram-webhook.service << 'EOF'
[Unit]
Description=TaskFlow Telegram Webhook Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/telegram-webhook
ExecStart=/usr/bin/node /root/telegram-webhook/telegram-webhook-server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3001
Environment=TELEGRAM_BOT_TOKEN=8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec
Environment=TELEGRAM_WEBHOOK_SECRET=TgWebhook2026Taskflow_Secret
Environment=SUPABASE_URL=http://127.0.0.1:8000
Environment=SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable telegram-webhook
systemctl restart telegram-webhook

sleep 2
systemctl status telegram-webhook --no-pager

echo "Servico configurado!"
