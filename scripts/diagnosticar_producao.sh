#!/usr/bin/env bash
# ==============================================================================
# TASKFLOW - DIAGNÓSTICO COMPLETO DE PRODUÇÃO (WEB + API APOIOS + BANCO)
# Seguro: NÃO imprime chaves, tokens ou senhas do .env.
# ==============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$ROOT_DIR/backend/.env"

echo "======================================================================="
echo "  TASKFLOW - DIAGNÓSTICO DO AMBIENTE DE PRODUÇÃO"
echo "  Data/Hora: $(date)"
echo "======================================================================="

echo ""
echo "[1/5] Serviço systemd taskflow-apoios:"
if systemctl list-unit-files | grep -q "^taskflow-apoios.service"; then
  echo "  Status: $(systemctl is-active taskflow-apoios 2>/dev/null || true)"
  sudo systemctl --no-pager status taskflow-apoios | head -n 12 || true
else
  echo "  ❌ taskflow-apoios.service NÃO está instalado."
fi

echo ""
echo "[2/5] Últimos 25 logs do taskflow-apoios:"
sudo journalctl -u taskflow-apoios -n 25 --no-pager 2>/dev/null || echo "  (sem logs)"

echo ""
echo "[3/5] Porta 3001, HTTP local e CORS:"
sudo ss -tulpn | grep -E ":3001|:8085" || echo "  ⚠️  Nenhuma escuta encontrada na 3001/8085"
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3001/api/apoios/me || echo "000")"
echo "  GET http://127.0.0.1:3001/api/apoios/me -> HTTP $HTTP_CODE (esperado: 401)"
CORS_TEST="$(curl -s -I -X OPTIONS -H "Origin: http://10.140.50.12:8085" -H "Access-Control-Request-Method: POST" http://127.0.0.1:3001/auth/apoios-login 2>/dev/null | grep -i "access-control" || true)"
echo "  CORS headers: ${CORS_TEST:-nenhum retornado}"

echo ""
echo "[4/5] Verificação de variáveis em $ENV_FILE (sem expor segredos):"
if [ -f "$ENV_FILE" ]; then
  for key in NODE_ENV PORT SUPABASE_URL SUPABASE_SERVICE_KEY DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD APOIOS_GATEWAY_SECRET CORS_ALLOWED_ORIGINS; do
    val="$(grep "^${key}=" "$ENV_FILE" | head -n 1 | cut -d= -f2- || true)"
    if [ -z "$val" ] || [[ "$val" == *"<PREENCHER"* ]]; then
      echo "  ❌ $key: AUSENTE ou não preenchido"
    elif [[ "$key" == *KEY* ]] || [[ "$key" == *PASSWORD* ]] || [[ "$key" == *SECRET* ]]; then
      echo "  ✅ $key: OK (${#val} caracteres)"
    else
      echo "  ✅ $key: $val"
    fi
  done
else
  echo "  ❌ Arquivo $ENV_FILE NÃO encontrado!"
fi

echo ""
echo "[5/5] Firewall (ufw) e Web publicado:"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw status | head -n 20 || true
else
  echo "  ufw não instalado."
fi
if [ -f "/home/jpfilho/taskflow/build/web/version.json" ]; then
  echo "  Web version.json: $(cat /home/jpfilho/taskflow/build/web/version.json)"
else
  echo "  ⚠️  /home/jpfilho/taskflow/build/web/version.json não encontrado."
fi
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAMES|taskflow-web|supabase-db|supabase-kong" || true

echo ""
echo "======================================================================="
echo "  Fim do diagnóstico."
echo "======================================================================="
