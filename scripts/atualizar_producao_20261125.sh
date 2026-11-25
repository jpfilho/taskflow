#!/usr/bin/env bash
# ==============================================================================
# TASKFLOW - SCRIPT SEGURO DE MIGRATIONS EM PRODUÇÃO (10.140.50.12)
#
# Garantias de segurança:
#   1. Backup completo automático (pg_dump .sql.gz) ANTES de qualquer SQL.
#      Se o backup falhar ou ficar vazio, o script aborta imediatamente.
#   2. Controle de idempotência: registra cada migration aplicada em
#      public.taskflow_applied_migrations para não duplicar execuções.
#   3. Execução transacional (-v ON_ERROR_STOP=1 --single-transaction).
#   4. Reload automático do schema cache do PostgREST + validação pós-deploy.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
MIGRATIONS_DIR="$ROOT_DIR/supabase/migrations"
BACKUP_DIR="$ROOT_DIR/backups"
LOG_DIR="$ROOT_DIR/logs"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/migracao_prod_${TIMESTAMP}.log"
BACKUP_FILE="$BACKUP_DIR/taskflow_prod_backup_${TIMESTAMP}.sql.gz"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================================================="
echo "  TASKFLOW - ATUALIZAÇÃO SEGURA DE BANCO EM PRODUÇÃO"
echo "  Data/Hora: $(date)"
echo "  Repositório: $ROOT_DIR"
echo "  Log: $LOG_FILE"
echo "======================================================================="

# 1. Detectar Docker / sudo docker e contêiner PostgreSQL
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
  if sudo -n docker ps >/dev/null 2>&1 || sudo docker ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
  fi
fi

DB_CONTAINER=""
for cname in "supabase-db" "supabase_db_taskflow" "supabase-db-taskflow" "taskflow_db"; do
  if $DOCKER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -wq "$cname"; then
    DB_CONTAINER="$cname"
    break
  fi
done
if [ -z "$DB_CONTAINER" ]; then
  DB_CONTAINER="$($DOCKER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -E "supabase.*db|postgres" | head -n 1 || true)"
fi

if [ -z "$DB_CONTAINER" ]; then
  echo "❌ ERRO: Nenhum contêiner PostgreSQL em execução foi encontrado."
  exit 1
fi

echo "✅ Contêiner PostgreSQL detectado: $DB_CONTAINER (via $DOCKER_CMD)"

psql_exec() {
  $DOCKER_CMD exec -i "$DB_CONTAINER" psql -U postgres -d postgres "$@"
}

# 2. Backup obrigatório ANTES de qualquer alteração
echo ""
echo "[1/4] Gerando backup completo do banco de produção..."
$DOCKER_CMD exec "$DB_CONTAINER" pg_dump -U postgres -d postgres --no-owner --no-privileges | gzip > "$BACKUP_FILE"

if [ ! -s "$BACKUP_FILE" ]; then
  echo "❌ ERRO CRÍTICO: Backup falhou ou arquivo está vazio ($BACKUP_FILE). Abortando sem alterar o banco!"
  exit 1
fi

BACKUP_SIZE="$(du -h "$BACKUP_FILE" | cut -f1)"
echo "✅ Backup concluído com sucesso: $BACKUP_FILE ($BACKUP_SIZE)"

# 3. Garantir tabela de controle de migrations aplicadas
echo ""
echo "[2/4] Verificando tabela de controle de migrations..."
psql_exec -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS public.taskflow_applied_migrations (
  filename text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
SQL

# 4. Lista ordenada das migrations desta release
MIGRATIONS=(
  "20261117_apoios_operacionais_fase2.sql"
  "20261117_apoios_operacionais_fase3_ajustes.sql"
  "20261117_apoios_notificacoes_fase6.sql"
  "20261118_apoios_fase7_monitoramento_indicadores.sql"
  "20261118_apoios_fase8_hardening.sql"
  "20261123_apoios_reconfirmacao_transicao.sql"
  "20261123_horas_sap_uni_trab_rea.sql"
  "20261123_conflict_acceptances.sql"
)

echo ""
echo "[3/4] Aplicando migrations em ordem cronológica..."
for fname in "${MIGRATIONS[@]}"; do
  fpath="$MIGRATIONS_DIR/$fname"
  if [ ! -f "$fpath" ]; then
    echo "❌ ERRO: Arquivo não encontrado: $fpath"
    exit 1
  fi

  ALREADY_APPLIED="$(psql_exec -t -A -c "SELECT count(*) FROM public.taskflow_applied_migrations WHERE filename = '$fname';")"
  if [ "$ALREADY_APPLIED" = "1" ]; then
    echo "  ⏭️  Já aplicada anteriormente: $fname"
    continue
  fi

  echo "  ▶ Aplicando $fname ..."
  psql_exec -v ON_ERROR_STOP=1 --single-transaction < "$fpath"
  psql_exec -v ON_ERROR_STOP=1 -c "INSERT INTO public.taskflow_applied_migrations (filename) VALUES ('$fname') ON CONFLICT (filename) DO NOTHING;"
  echo "  ✅ $fname aplicada com sucesso."
done

# 5. Reload do schema cache do PostgREST e validação final
echo ""
echo "[4/4] Recarregando schema do PostgREST e validando integridade..."
psql_exec -v ON_ERROR_STOP=1 -c "NOTIFY pgrst, 'reload schema';"
psql_exec -v ON_ERROR_STOP=1 -c "
SELECT
  (SELECT count(*) FROM public.tasks) AS total_tasks,
  (SELECT count(*) FROM public.notas_sap) AS total_notas_sap,
  (SELECT count(*) FROM public.conflict_acceptances) AS total_conflict_acceptances,
  (SELECT count(*) FROM public.apoio_tipos) AS total_apoio_tipos;
"

echo ""
echo "======================================================================="
echo "  ✅ MIGRATIONS DE PRODUÇÃO CONCLUÍDAS COM SEGURANÇA!"
echo "  Backup salvo em: $BACKUP_FILE"
echo "  Log salvo em:    $LOG_FILE"
echo "======================================================================="
