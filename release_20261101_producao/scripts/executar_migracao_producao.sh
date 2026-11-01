#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE EXECUÇÃO DE MIGRATIONS NO SERVIDOR CORPORATIVO (10.140.50.12)
# ARQUIVO: executar_migracao_producao.sh
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SQL_DIR="$BASE_DIR/sql"
LOG_DIR="$BASE_DIR/logs"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/migracao_prod_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================================================="
echo "   TASKFLOW - EXECUÇÃO SEGURA DE MIGRATIONS DE PRODUÇÃO (10.140.50.12) "
echo "   Data/Hora: $(date)"
echo "   Log gravado em: $LOG_FILE"
echo "======================================================================="

# ------------------------------------------------------------------------------
# 1. VERIFICAÇÃO OBRIGATÓRIA DE BACKUP PRÉVIO
# ------------------------------------------------------------------------------
BACKUP_VALIDADO="/home/jpfilho/backups_taskflow/20261101_153023/postgres.dump"

echo ""
echo "[1/4] Verificando integridade do backup de segurança..."
if [ -f "$BACKUP_VALIDADO" ] && [ -s "$BACKUP_VALIDADO" ]; then
    BACKUP_SIZE=$(ls -lh "$BACKUP_VALIDADO" | awk '{print $5}')
    echo "  ✅ Backup de segurança confirmado:"
    echo "     Arquivo: $BACKUP_VALIDADO"
    echo "     Tamanho: $BACKUP_SIZE"
else
    echo "  ❌ ERRO CRÍTICO: Backup obrigatório não encontrado ou vazio!"
    echo "     Caminho esperado: $BACKUP_VALIDADO"
    echo "     Por política de segurança, a migração NÃO pode prosseguir sem backup."
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. DETECÇÃO DO DOCKER / SUDO DOCKER E CONEXÃO POSTGRESQL
# ------------------------------------------------------------------------------
echo ""
echo "[2/4] Detectando forma de acesso ao PostgreSQL de produção..."

DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    if sudo -n docker ps >/dev/null 2>&1 || sudo docker ps >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    fi
fi

DB_CONTAINER=""
if command -v docker >/dev/null 2>&1 || [ "$DOCKER_CMD" = "sudo docker" ]; then
    for cname in "supabase-db" "supabase_db_taskflow" "supabase-db-taskflow" "taskflow_db"; do
        if $DOCKER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -wq "$cname"; then
            DB_CONTAINER="$cname"
            break
        fi
    done
    if [ -z "$DB_CONTAINER" ]; then
        DB_CONTAINER=$($DOCKER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -E "supabase.*db|postgres" | head -n 1 || true)
    fi
fi

query_sql() {
    local sql_query="$1"
    if [ -n "$DB_CONTAINER" ]; then
        $DOCKER_CMD exec -i "$DB_CONTAINER" psql -U postgres -d postgres -t -A -c "$sql_query" 2>/dev/null || echo "0"
    elif command -v psql >/dev/null 2>&1; then
        PGDATABASE="${PGDATABASE:-postgres}"
        PGUSER="${PGUSER:-postgres}"
        PGHOST="${PGHOST:-localhost}"
        PGPORT="${PGPORT:-5432}"
        psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -A -c "$sql_query" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

run_sql_file() {
    local file_path="$1"
    local desc="$2"
    echo ""
    echo "  ▶ Executando: $desc ($(basename "$file_path"))..."

    if [ -n "$DB_CONTAINER" ]; then
        $DOCKER_CMD exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$file_path"
    elif command -v psql >/dev/null 2>&1; then
        PGDATABASE="${PGDATABASE:-postgres}"
        PGUSER="${PGUSER:-postgres}"
        PGHOST="${PGHOST:-localhost}"
        PGPORT="${PGPORT:-5432}"
        psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 < "$file_path"
    else
        echo "  ❌ ERRO: Nem o contêiner Docker do PostgreSQL nem o comando 'psql' foram encontrados."
        exit 1
    fi
    echo "  ✅ Concluído com sucesso."
}

if [ -n "$DB_CONTAINER" ]; then
    echo "  ✅ Utilizando contêiner Docker: $DB_CONTAINER (via $DOCKER_CMD)"
else
    echo "  ℹ️  Utilizando cliente psql nativo na porta ${PGPORT:-5432}"
fi

# ------------------------------------------------------------------------------
# 3. EXECUÇÃO CONTROLADA DAS ETAPAS COM PROTEÇÃO CONTRA DUPLICAÇÃO
# ------------------------------------------------------------------------------
echo ""
echo "[3/4] Iniciando verificação e aplicação das migrations..."

# ETAPA 1
HAS_ANALISES=$(query_sql "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='notas_sap_analises';")
if [ "$HAS_ANALISES" = "1" ]; then
    echo "  ℹ️  Etapa 1 (notas_sap_analises) já existe. Aplicando reforço idempotente de colunas/permissões..."
fi
run_sql_file "$SQL_DIR/01_pre_requisitos_e_analise_base.sql" "Etapa 1: Pré-requisitos e Análise Prévia"

# ETAPA 2
HAS_GRUPOS=$(query_sql "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='notas_sap_grupos';")
if [ "$HAS_GRUPOS" = "1" ]; then
    echo "  ℹ️  Etapa 2 (notas_sap_grupos) já existe. Aplicando reforço idempotente..."
fi
run_sql_file "$SQL_DIR/02_grupos_previsao.sql" "Etapa 2: Grupos de Notas SAP e Previsão Macro"

# ETAPA 3
HAS_ANEXOS_EVO=$(query_sql "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='notas_sap_anexos' AND column_name='sha256';")
if [ "$HAS_ANEXOS_EVO" = "1" ]; then
    echo "  ℹ️  Etapa 3 (anexos evoluídos) já possui colunas integradas. Aplicando reforço..."
fi
run_sql_file "$SQL_DIR/03_anexos_storage_e_anotacoes.sql" "Etapa 3: Anexos SAP, Storage e Anotações"

# ETAPA 4
HAS_EVIDENCIAS=$(query_sql "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='notas_sap_analise_evidencias' AND column_name='tipo_fonte';")
if [ "$HAS_EVIDENCIAS" = "1" ]; then
    echo "  ℹ️  Etapa 4 (evidências polimórficas) já existe. Aplicando validação..."
fi
run_sql_file "$SQL_DIR/04_analise_evidencias_polimorficas.sql" "Etapa 4: Evidências Técnicas Polimórficas"

# ETAPA 5
HAS_TAGS=$(query_sql "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='notas_sap_tags';")
if [ "$HAS_TAGS" = "1" ]; then
    echo "  ℹ️  Etapa 5 (tags hierárquicas) já existe. Aplicando reforço..."
fi
run_sql_file "$SQL_DIR/05_tags_hierarquicas.sql" "Etapa 5: Catálogo de Tags e Vínculos"

# ETAPA 6
run_sql_file "$SQL_DIR/06_recarregar_schema_postgrest.sql" "Etapa 6: Recarregar Schema do PostgREST"

# ------------------------------------------------------------------------------
# 4. VALIDAÇÃO PÓS-MIGRAÇÃO AUTOMATIZADA
# ------------------------------------------------------------------------------
echo ""
echo "[4/4] Executando validação de integridade pós-migração..."
run_sql_file "$SQL_DIR/validar_pos_migracao.sql" "Validação Pós-Migração"

echo ""
echo "======================================================================="
echo "  🎉 SUCESSO! Migração concluída com êxito no banco de produção!"
echo "  Consulte os detalhes no log: $LOG_FILE"
echo "======================================================================="
