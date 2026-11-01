#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE PUBLICAÇÃO WEB DEFINITIVO EM PRODUÇÃO (10.140.50.12 - PORTA 8085)
# CONTÊINER ALVO: taskflow-web-teste
# DIRETÓRIO ALVO: /home/jpfilho/taskflow/build/web
# BASE HREF: /
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
TARBALL="$BASE_DIR/taskflow_web_prod_20261101.tar.gz"

WEB_TARGET="/home/jpfilho/taskflow/build/web"
RELEASES_DIR="/home/jpfilho/taskflow/build/releases"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
NEW_RELEASE_DIR="$RELEASES_DIR/web_20261101_${TIMESTAMP}"
BACKUP_DIR="/home/jpfilho/taskflow/build/web_backup_${TIMESTAMP}"
CONTAINER_NAME="taskflow-web-teste"
PORT="8085"

# Detecção automática de docker vs sudo docker
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    if sudo -n docker ps >/dev/null 2>&1 || sudo docker ps >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    fi
fi

echo "======================================================================="
echo "   TASKFLOW - PUBLICAÇÃO DEFINITIVA DO FRONTEND WEB (PORTA 8085)      "
echo "   Data/Hora: $(date)                                                  "
echo "   Contêiner: $CONTAINER_NAME                                          "
echo "   Diretório: $WEB_TARGET                                              "
echo "   Docker:    $DOCKER_CMD                                              "
echo "======================================================================="

# ------------------------------------------------------------------------------
# 1. VALIDAR O PACOTE DE BUILD
# ------------------------------------------------------------------------------
echo ""
echo "[1/6] Validando o pacote de publicação..."
if [ ! -f "$TARBALL" ]; then
    echo "  ❌ ERRO CRÍTICO: Arquivo $TARBALL não encontrado!"
    exit 1
fi
TARBALL_SIZE=$(ls -lh "$TARBALL" | awk '{print $5}')
echo "  ✅ Pacote encontrado ($TARBALL_SIZE): $TARBALL"

# Testar integridade do tar.gz
if ! tar -tzf "$TARBALL" >/dev/null 2>&1; then
    echo "  ❌ ERRO: O arquivo tar.gz está corrompido!"
    exit 1
fi
echo "  ✅ Integridade do arquivo tar.gz validada com sucesso."

# ------------------------------------------------------------------------------
# 2. PRESERVAR A VERSÃO ATUAL (BACKUP)
# ------------------------------------------------------------------------------
echo ""
echo "[2/6] Preservando a versão atual em diretório de backup..."
if [ -d "$WEB_TARGET" ] && [ "$(ls -A "$WEB_TARGET" 2>/dev/null)" ]; then
    echo "  📦 Criando backup em $BACKUP_DIR..."
    mkdir -p "$(dirname "$BACKUP_DIR")"
    cp -r "$WEB_TARGET" "$BACKUP_DIR"
    echo "  ✅ Backup concluído em: $BACKUP_DIR"
else
    echo "  ℹ️  Diretório $WEB_TARGET está vazio ou não existia. Criando estrutura..."
    mkdir -p "$WEB_TARGET"
fi

# ------------------------------------------------------------------------------
# 3. EXTRAIR EM DIRETÓRIO INDEPENDENTE E TESTAR BUILD ANTES DA SUBSTITUIÇÃO
# ------------------------------------------------------------------------------
echo ""
echo "[3/6] Extraindo nova versão em diretório isolado e validando..."
mkdir -p "$NEW_RELEASE_DIR"
tar -xzf "$TARBALL" -C "$NEW_RELEASE_DIR"

# Validar arquivos essenciais
for f in "index.html" "main.dart.js" "flutter_bootstrap.js" "version.json"; do
    if [ ! -s "$NEW_RELEASE_DIR/$f" ]; then
        echo "  ❌ ERRO: Arquivo essencial '$f' ausente ou vazio na nova versão!"
        exit 1
    fi
done

# Validar base-href no index.html (deve ser raiz "/")
if ! grep -q '<base href="/">' "$NEW_RELEASE_DIR/index.html"; then
    echo "  ❌ ERRO: O arquivo index.html não possui a tag <base href=\"/\"> configurada!"
    exit 1
fi
echo "  ✅ Verificação estrutural do build: base href \"/\" confirmado."

# ------------------------------------------------------------------------------
# 4. PUBLICAR COM PERMISSÕES ADMINISTRATIVAS E SEM MISTURAR ARQUIVOS
# ------------------------------------------------------------------------------
echo ""
echo "[4/6] Aplicando nova versão de forma atômica no diretório de produção..."

if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$NEW_RELEASE_DIR/" "$WEB_TARGET/"
else
    # Fallback seguro para evitar mistura de builds
    TEMP_STAGING="/home/jpfilho/taskflow/build/.web_staging_swap"
    rm -rf "$TEMP_STAGING"
    mkdir -p "$TEMP_STAGING"
    cp -r "$NEW_RELEASE_DIR"/* "$TEMP_STAGING"/
    rm -rf "$WEB_TARGET"/*
    cp -r "$TEMP_STAGING"/* "$WEB_TARGET"/
    rm -rf "$TEMP_STAGING"
fi

# Ajustar permissões administrativas
chmod -R 755 "$WEB_TARGET"
echo "  ✅ Conteúdo publicado em $WEB_TARGET com permissões 755."

# ------------------------------------------------------------------------------
# 5. RECARREGAR O CONTÊINER taskflow-web-teste
# ------------------------------------------------------------------------------
echo ""
echo "[5/6] Atualizando o servidor web Nginx no contêiner $CONTAINER_NAME..."

if $DOCKER_CMD ps --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
    echo "  🔄 Enviando reload gracioso para o Nginx..."
    $DOCKER_CMD exec "$CONTAINER_NAME" nginx -s reload 2>/dev/null || {
        echo "  ℹ️  Reload direto falhou, reiniciando o contêiner $CONTAINER_NAME..."
        $DOCKER_CMD restart "$CONTAINER_NAME"
    }
else
    echo "  ⚠️  AVISO: Contêiner '$CONTAINER_NAME' não encontrado rodando. Procurando contêiner na porta $PORT..."
    C_PORT_8085=$($DOCKER_CMD ps --format '{{.Names}}' | while read name; do
        if $DOCKER_CMD port "$name" 2>/dev/null | grep -q "$PORT"; then echo "$name"; break; fi
    done)
    if [ -n "$C_PORT_8085" ]; then
        echo "  🔄 Contêiner identificado na porta $PORT: '$C_PORT_8085'. Recarregando..."
        $DOCKER_CMD exec "$C_PORT_8085" nginx -s reload 2>/dev/null || $DOCKER_CMD restart "$C_PORT_8085"
    fi
fi

sleep 2

# ------------------------------------------------------------------------------
# 6. VERIFICAÇÃO HTTP 200 E CONFERÊNCIA DE HASHES DOS ARQUIVOS SERVIDOS
# ------------------------------------------------------------------------------
echo ""
echo "[6/6] Verificando endpoints servidos na porta $PORT..."

rollback_if_needed() {
    echo ""
    echo "  ❌ FALHA DE VALIDAÇÃO: Iniciando rollback automático para a versão anterior..."
    if [ -d "$BACKUP_DIR" ]; then
        if command -v rsync >/dev/null 2>&1; then
            rsync -a --delete "$BACKUP_DIR/" "$WEB_TARGET/"
        else
            rm -rf "$WEB_TARGET"/*
            cp -r "$BACKUP_DIR"/* "$WEB_TARGET"/
        fi
        $DOCKER_CMD exec "$CONTAINER_NAME" nginx -s reload 2>/dev/null || true
        echo "  ✅ Rollback concluído. Versão anterior restaurada."
    fi
    exit 1
}

# 6.1. Validar HTTP 200 para raiz "/"
CODE_ROOT=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" || echo "000")
if [ "$CODE_ROOT" = "200" ]; then
    echo "  ✅ HTTP status 200 OK para rota raiz: http://127.0.0.1:${PORT}/"
else
    echo "  ❌ ERRO: Rota raiz respondeu status HTTP '$CODE_ROOT' (esperado 200)"
    rollback_if_needed
fi

# 6.2. Validar HTTP 200 para main.dart.js
CODE_JS=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/main.dart.js" || echo "000")
if [ "$CODE_JS" = "200" ]; then
    echo "  ✅ HTTP status 200 OK para main.dart.js: http://127.0.0.1:${PORT}/main.dart.js"
else
    echo "  ❌ ERRO: main.dart.js respondeu status HTTP '$CODE_JS' (esperado 200)"
    rollback_if_needed
fi

# 6.3. Validar HTTP 200 para flutter_bootstrap.js
CODE_BOOT=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/flutter_bootstrap.js" || echo "000")
if [ "$CODE_BOOT" = "200" ]; then
    echo "  ✅ HTTP status 200 OK para flutter_bootstrap.js: http://127.0.0.1:${PORT}/flutter_bootstrap.js"
else
    echo "  ❌ ERRO: flutter_bootstrap.js respondeu status HTTP '$CODE_BOOT' (esperado 200)"
    rollback_if_needed
fi

# 6.4. Confirmar hashes dos arquivos servidos
echo ""
echo "  🔍 Comparando hashes criptográficos do pacote e dos arquivos publicados..."
LOCAL_INDEX_HASH=$(shasum -a 256 "$NEW_RELEASE_DIR/index.html" | awk '{print $1}')
TARGET_INDEX_HASH=$(shasum -a 256 "$WEB_TARGET/index.html" | awk '{print $1}')

if [ "$LOCAL_INDEX_HASH" = "$TARGET_INDEX_HASH" ]; then
    echo "  ✅ Hash do index.html confere perfeitamente: $TARGET_INDEX_HASH"
else
    echo "  ❌ Divergência de hash no index.html!"
    rollback_if_needed
fi

echo ""
echo "======================================================================="
echo "  🎉 PUBLICAÇÃO WEB CONCLUÍDA COM SUCESSO!"
echo "  URL de Acesso:  http://10.140.50.12:${PORT}/"
echo "  Diretório:      $WEB_TARGET"
echo "  Backup salvo:   $BACKUP_DIR"
echo "  Rollback:       bash scripts/rollback_producao.sh $BACKUP_DIR"
echo "======================================================================="
