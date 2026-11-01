#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE ROLLBACK DE PRODUÇÃO (10.140.50.12)
# ARQUIVO: rollback_producao.sh
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SQL_DIR="$BASE_DIR/sql"

WEB_TARGET="/home/jpfilho/taskflow/build/web"
BACKUP_DIR="$1"

# Detecção de docker vs sudo docker
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    if sudo -n docker ps >/dev/null 2>&1 || sudo docker ps >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    fi
fi

echo "======================================================================="
echo "   TASKFLOW - PROCEDIMENTO DE ROLLBACK DE PRODUÇÃO (10.140.50.12)      "
echo "   Data/Hora: $(date)                                                  "
echo "   Docker Command: $DOCKER_CMD                                         "
echo "======================================================================="

# Se o diretório de backup não for informado, busca o mais recente
if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR=$(ls -dt /home/jpfilho/taskflow/build/web_backup_* 2>/dev/null | head -n 1 || true)
fi

echo ""
echo "[1/3] Verificando diretório de backup anterior..."
if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo "  ✅ Backup identificado: $BACKUP_DIR"
else
    echo "  ❌ ERRO: Nenhum diretório de backup válido encontrado!"
    echo "     Uso: bash scripts/rollback_producao.sh /caminho/para/web_backup_YYYYMMDD_HHMMSS"
    exit 1
fi

echo ""
echo "[2/3] Restaurando versão anterior em $WEB_TARGET..."
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$BACKUP_DIR/" "$WEB_TARGET/"
else
    find "$WEB_TARGET" -mindepth 1 -delete
    cp -r "$BACKUP_DIR"/* "$WEB_TARGET"/
fi

# Recarregar Nginx nos contêineres 8080 e 8085
for cname in $($DOCKER_CMD ps --format '{{.Names}}' 2>/dev/null); do
    PORTS_INFO=$($DOCKER_CMD port "$cname" 2>/dev/null || true)
    if echo "$PORTS_INFO" | grep -qE "8080|8085"; then
        $DOCKER_CMD exec "$cname" nginx -s reload 2>/dev/null || true
    fi
done

echo "  ✅ Restauração do frontend web concluída com sucesso!"

echo ""
echo "[3/3] Validando resposta dos contêineres nas portas 8080 e 8085..."
for port in 8080 8085; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${port}/task2026/" 2>/dev/null || true)
    echo "  ℹ️  Contêiner porta ${port}: HTTP status $STATUS"
done

echo ""
echo "======================================================================="
echo "  REVERSÃO DO FRONTEND CONCLUÍDA COM SUCESSO!"
echo "======================================================================="
echo ""
echo "  SE FOR NECESSÁRIO REVERTER O BANCO DE DADOS:"
echo "  ⚠️  REGRA DE SEGURANÇA: NUNCA execute 'pg_restore --clean' sobre o banco ativo,"
echo "      pois isso apagaria todas as notas, tarefas e alterações produzidas pelos usuários"
echo "      após as 15:30:23."
echo ""
echo "  Opção Recomendada (Cirúrgica e Segura):"
echo "  Reverter apenas as novas estruturas de Notas SAP, mantendo as tabelas operacionais:"
echo "  $DOCKER_CMD exec -i supabase-db psql -U postgres -d postgres < $SQL_DIR/rollback_migracao_notas_sap.sql"
echo "======================================================================="
