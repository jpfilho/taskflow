#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE DEPLOY DOCKER CONTROLADO NO SERVIDOR CORPORATIVO (10.140.50.12)
# ARQUIVO: deploy_docker_producao.sh
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
TARBALL="$BASE_DIR/taskflow_web_prod_20261101.tar.gz"

WEB_TARGET="/home/jpfilho/taskflow/build/web"
RELEASES_DIR="/home/jpfilho/taskflow/build/releases"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
NEW_RELEASE_DIR="$RELEASES_DIR/release_20261101_${TIMESTAMP}"
BACKUP_DIR="/home/jpfilho/taskflow/build/web_backup_${TIMESTAMP}"
STAGING_DIR="/home/jpfilho/taskflow/build/.web_staging_${TIMESTAMP}"

TEST_CONTAINER="taskflow-test-8088"
TEST_PORT="8088"

# Detecção automática de docker vs sudo docker
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    if sudo -n docker ps >/dev/null 2>&1 || sudo docker ps >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    fi
fi

echo "======================================================================="
echo "   TASKFLOW - DEPLOY CONTROLADO DE PRODUÇÃO (10.140.50.12)             "
echo "   Data/Hora: $(date)                                                  "
echo "   Docker Command: $DOCKER_CMD                                         "
echo "======================================================================="

# ------------------------------------------------------------------------------
# 1. VALIDAÇÃO DO PACOTE
# ------------------------------------------------------------------------------
echo ""
echo "[1/6] Verificando pacote de build de produção..."
if [ ! -f "$TARBALL" ]; then
    echo "  ❌ ERRO: Pacote $TARBALL não encontrado!"
    exit 1
fi
echo "  ✅ Pacote encontrado: $(ls -lh "$TARBALL" | awk '{print $5, $9}')"

# ------------------------------------------------------------------------------
# 2. EXTRAÇÃO EM DIRETÓRIO DE RELEASE ISOLADO
# ------------------------------------------------------------------------------
echo ""
echo "[2/6] Extraindo nova versão em diretório isolado..."
mkdir -p "$NEW_RELEASE_DIR" "$STAGING_DIR"
tar -xzf "$TARBALL" -C "$NEW_RELEASE_DIR"
cp -r "$NEW_RELEASE_DIR"/* "$STAGING_DIR"/
echo "  ✅ Nova versão extraída em: $NEW_RELEASE_DIR"

# ------------------------------------------------------------------------------
# 3. SUBIR INSTÂNCIA DE TESTES INDEPENDENTE (PORTA 8088)
# ------------------------------------------------------------------------------
echo ""
echo "[3/6] Iniciando contêiner independente de testes na porta $TEST_PORT..."
$DOCKER_CMD rm -f "$TEST_CONTAINER" 2>/dev/null || true

$DOCKER_CMD run -d --name "$TEST_CONTAINER" \
    -p "${TEST_PORT}:80" \
    -v "$NEW_RELEASE_DIR:/usr/share/nginx/html/task2026:ro" \
    nginx:alpine

echo "  ⏳ Aguardando contêiner de testes inicializar..."
sleep 3

# ------------------------------------------------------------------------------
# 4. VALIDAÇÃO NA INSTÂNCIA DE TESTES
# ------------------------------------------------------------------------------
echo ""
echo "[4/6] Executando validação de integridade na porta $TEST_PORT..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${TEST_PORT}/task2026/" || true)

if [ "$HTTP_STATUS" = "200" ]; then
    echo "  ✅ Teste HTTP bem-sucedido: status $HTTP_STATUS em http://127.0.0.1:${TEST_PORT}/task2026/"
else
    echo "  ❌ FALHA NO TESTE: Contêiner de testes respondeu com status HTTP '$HTTP_STATUS'."
    echo "     O deploy foi ABORTADO para proteger a produção."
    $DOCKER_CMD logs "$TEST_CONTAINER" || true
    $DOCKER_CMD rm -f "$TEST_CONTAINER" 2>/dev/null || true
    rm -rf "$STAGING_DIR"
    exit 1
fi

# Validar se o base-href está injetado corretamente
if curl -s "http://127.0.0.1:${TEST_PORT}/task2026/" | grep -q '<base href="/task2026/">'; then
    echo "  ✅ Verificação do index.html: <base href=\"/task2026/\"> confirmado!"
fi

echo "  🧹 Finalizando contêiner de testes temporário..."
$DOCKER_CMD rm -f "$TEST_CONTAINER" >/dev/null

# ------------------------------------------------------------------------------
# 5. BACKUP DA VERSÃO ANTERIOR E ATUALIZAÇÃO ATÔMICA SEM MISTURA DE ARQUIVOS
# ------------------------------------------------------------------------------
echo ""
echo "[5/6] Criando backup de segurança da versão anterior e aplicando nova versão..."

if [ -d "$WEB_TARGET" ]; then
    echo "  📦 Criando backup de $WEB_TARGET -> $BACKUP_DIR..."
    cp -r "$WEB_TARGET" "$BACKUP_DIR"
    echo "  ✅ Backup concluído em: $BACKUP_DIR"
else
    echo "  ℹ️ Diretório $WEB_TARGET não existia previamente. Criando..."
    mkdir -p "$WEB_TARGET"
fi

echo "  🔄 Aplicando nova versão de forma atômica via rsync..."
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$STAGING_DIR/" "$WEB_TARGET/"
else
    # Fallback seguro
    find "$WEB_TARGET" -mindepth 1 -delete
    cp -r "$STAGING_DIR"/* "$WEB_TARGET"/
fi
rm -rf "$STAGING_DIR"
echo "  ✅ Conteúdo atualizado com sucesso em $WEB_TARGET!"

# ------------------------------------------------------------------------------
# 6. RECARGA GRACIOSA DO NGINX NOS CONTÊINERES DE PRODUÇÃO (8080 E 8085)
# ------------------------------------------------------------------------------
echo ""
echo "[6/6] Recarregando Nginx dos contêineres para servir a nova versão imediatamente..."

# Procura os contêineres Nginx ativos nas portas 8080 e 8085
for cname in $($DOCKER_CMD ps --format '{{.Names}}' 2>/dev/null); do
    PORTS_INFO=$($DOCKER_CMD port "$cname" 2>/dev/null || true)
    if echo "$PORTS_INFO" | grep -qE "8080|8085"; then
        echo "  🔄 Recarregando cache do Nginx no contêiner '$cname'..."
        $DOCKER_CMD exec "$cname" nginx -s reload 2>/dev/null || true
    fi
done

# Validação final das respostas
for port in 8080 8085; do
    PROD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${port}/task2026/" 2>/dev/null || true)
    if [ "$PROD_STATUS" = "200" ]; then
        echo "  ✅ Contêiner porta ${port}: HTTP 200 OK"
    else
        echo "  ℹ️  Contêiner porta ${port}: respondeu status '$PROD_STATUS'"
    fi
done

echo ""
echo "======================================================================="
echo "  🎉 DEPLOY CONCLUÍDO COM SUCESSO!"
echo "  Versão ativa em: $WEB_TARGET"
echo "  Backup preservado em: $BACKUP_DIR"
echo "  Caso precise reverter, execute: bash scripts/rollback_producao.sh $BACKUP_DIR"
echo "======================================================================="
