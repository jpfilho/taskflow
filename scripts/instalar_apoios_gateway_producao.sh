#!/usr/bin/env bash
# ==============================================================================
# TASKFLOW - INSTALAÇÃO AUTOMATIZADA DO GATEWAY DE APOIOS (PORTA 3001)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$ROOT_DIR/backend"
ENV_FILE="$BACKEND_DIR/.env"
ENV_EXAMPLE="$BACKEND_DIR/.env.example"
SERVICE_FILE="/etc/systemd/system/taskflow-apoios.service"
RUN_USER="${SUDO_USER:-$(whoami)}"

echo "======================================================================="
echo "  TASKFLOW - CONFIGURAÇÃO DO SERVIÇO DE APOIOS (PORTA 3001)"
echo "  Diretório: $BACKEND_DIR"
echo "  Usuário:   $RUN_USER"
echo "======================================================================="

# 1. Validar Node.js / npm
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "❌ ERRO: Node.js e npm são obrigatórios. Instale antes de prosseguir."
  exit 1
fi
NODE_BIN="$(command -v node)"
echo "✅ Node detectado: $NODE_BIN ($(node -v))"

# 2. Preparar backend/.env sem sobrescrever se já existir
if [ ! -f "$ENV_FILE" ]; then
  echo ""
  echo "[1/4] Criando $ENV_FILE..."
  if [ -f "$ENV_EXAMPLE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
  else
    cat <<'EOF' > "$ENV_FILE"
NODE_ENV=production
PORT=3001
SUPABASE_URL=http://127.0.0.1:8000
SUPABASE_SERVICE_KEY=<PREENCHER_SERVICE_ROLE_KEY_DO_AMBIENTE>
DB_HOST=127.0.0.1
DB_PORT=5433
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=<PREENCHER_DB_PASSWORD>
APOIOS_GATEWAY_SECRET=<PREENCHER>
APOIOS_ENTRA_TENANT_ID=8a0ffb54-9716-4a93-9158-9e3a7206f18e
APOIOS_ENTRA_API_AUDIENCE=
TELEGRAM_BOT_TOKEN=
TELEGRAM_WEBHOOK_SECRET=
CORS_ALLOWED_ORIGINS=http://10.140.50.12:8085,http://10.140.50.12:8080
EOF
  fi

  # Ajustar DB_PORT=5433 (supabase-db direto para LISTEN/NOTIFY)
  sed -i 's/^DB_PORT=.*/DB_PORT=5433/' "$ENV_FILE"
  sed -i 's|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=http://10.140.50.12:8085,http://10.140.50.12:8080|' "$ENV_FILE"

  # Gerar APOIOS_GATEWAY_SECRET automaticamente
  GATEWAY_SECRET="$(openssl rand -hex 32)"
  sed -i "s|^APOIOS_GATEWAY_SECRET=.*|APOIOS_GATEWAY_SECRET=${GATEWAY_SECRET}|" "$ENV_FILE"

  # Tentar capturar SERVICE_ROLE_KEY e POSTGRES_PASSWORD dos contêineres locais (se disponível)
  AUTO_SERVICE_KEY=""
  for c in "supabase-studio" "supabase-storage" "supabase-edge-functions" "supabase-auth"; do
    AUTO_SERVICE_KEY="$(sudo docker inspect "$c" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | awk -F= '/^(SUPABASE_SERVICE_KEY|SERVICE_ROLE_KEY|SUPABASE_SERVICE_ROLE_KEY)=/{print $2; exit}' || true)"
    [ -n "$AUTO_SERVICE_KEY" ] && break
  done
  AUTO_DB_PASS="$(sudo docker inspect supabase-db --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | awk -F= '/^POSTGRES_PASSWORD=/{print $2; exit}' || true)"

  if [ -n "$AUTO_DB_PASS" ]; then
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${AUTO_DB_PASS}|" "$ENV_FILE"
    echo "✅ DB_PASSWORD preenchido automaticamente a partir do contêiner supabase-db."
  else
    read -rsp "Informe a senha do PostgreSQL (DB_PASSWORD): " INPUT_DB_PASS
    echo ""
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${INPUT_DB_PASS}|" "$ENV_FILE"
  fi

  if [ -n "$AUTO_SERVICE_KEY" ]; then
    sed -i "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=${AUTO_SERVICE_KEY}|" "$ENV_FILE"
    echo "✅ SUPABASE_SERVICE_KEY preenchido automaticamente a partir do contêiner local."
  else
    CURRENT_SVC="$(grep '^SUPABASE_SERVICE_KEY=' "$ENV_FILE" | cut -d= -f2-)"
    if [[ "$CURRENT_SVC" == *"<PREENCHER"* ]] || [ -z "$CURRENT_SVC" ]; then
      read -rp "Cole a SUPABASE_SERVICE_KEY (service_role) de produção: " INPUT_SVC_KEY
      sed -i "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=${INPUT_SVC_KEY}|" "$ENV_FILE"
    fi
  fi

  read -rp "Cole o TELEGRAM_BOT_TOKEN (ou deixe em branco se não usar): " INPUT_TG_TOKEN
  if [ -n "$INPUT_TG_TOKEN" ]; then
    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=${INPUT_TG_TOKEN}|" "$ENV_FILE"
  fi

  chmod 600 "$ENV_FILE"
  echo "✅ Arquivo .env criado e protegido (chmod 600)."
else
  echo ""
  echo "[1/4] Arquivo $ENV_FILE já existe — preservando configurações atuais."
fi

# 3. Instalar dependências Node
echo ""
echo "[2/4] Instalando dependências Node.js em $BACKEND_DIR..."
cd "$BACKEND_DIR"
if [ ! -f "package.json" ]; then
  npm init -y >/dev/null 2>&1
fi
npm install --omit=dev axios >/dev/null 2>&1 || npm install axios
echo "✅ Dependências instaladas."

# 4. Criar/atualizar serviço systemd
echo ""
echo "[3/4] Configurando serviço systemd (taskflow-apoios.service)..."
sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=TaskFlow Apoios Gateway e Worker de Notificacoes
After=network.target

[Service]
Type=simple
User=${RUN_USER}
WorkingDirectory=${BACKEND_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=${NODE_BIN} ${BACKEND_DIR}/apoios_gateway.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable taskflow-apoios
sudo systemctl restart taskflow-apoios
sleep 2

echo ""
echo "[4/4] Verificando status do serviço..."
sudo systemctl --no-pager status taskflow-apoios | head -n 15

echo ""
echo "======================================================================="
echo "  ✅ SERVIÇO taskflow-apoios ATIVO NA PORTA 3001!"
echo "  Para ver logs em tempo real: sudo journalctl -u taskflow-apoios -f"
echo "======================================================================="

