#!/bin/bash

# ============================================
# Script de Deploy para Produção - Hostinger
# ============================================
# Este script automatiza o processo de deploy
# do Supabase local para o servidor de produção

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis (ajuste conforme necessário)
LOCAL_DB_HOST="${LOCAL_DB_HOST:-localhost}"
LOCAL_DB_USER="${LOCAL_DB_USER:-postgres}"
LOCAL_DB_NAME="${LOCAL_DB_NAME:-postgres}"
PRODUCTION_SERVER="${PRODUCTION_SERVER:-usuario@seu-servidor-hostinger}"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Deploy para Produção - Hostinger${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""

# Função para fazer backup
backup_local() {
    echo -e "${YELLOW}📦 Fazendo backup do banco local...${NC}"
    
    mkdir -p "$BACKUP_DIR"
    
    # Verificar se está usando Docker
    if docker ps | grep -q supabase-db; then
        echo "Usando Docker para backup..."
        docker exec supabase-db pg_dump -U postgres postgres -F c -f /tmp/backup_$TIMESTAMP.dump
        docker cp supabase-db:/tmp/backup_$TIMESTAMP.dump "$BACKUP_DIR/backup_local_$TIMESTAMP.dump"
        echo -e "${GREEN}✅ Backup criado: $BACKUP_DIR/backup_local_$TIMESTAMP.dump${NC}"
    else
        echo "Usando pg_dump direto..."
        pg_dump -h "$LOCAL_DB_HOST" \
            -U "$LOCAL_DB_USER" \
            -d "$LOCAL_DB_NAME" \
            -F c \
            -f "$BACKUP_DIR/backup_local_$TIMESTAMP.dump"
        echo -e "${GREEN}✅ Backup criado: $BACKUP_DIR/backup_local_$TIMESTAMP.dump${NC}"
    fi
}

# Função para exportar apenas schema
export_schema() {
    echo -e "${YELLOW}📋 Exportando schema (estrutura)...${NC}"
    
    mkdir -p "$BACKUP_DIR"
    
    if docker ps | grep -q supabase-db; then
        docker exec supabase-db pg_dump -U postgres postgres --schema-only -f /tmp/schema_$TIMESTAMP.sql
        docker cp supabase-db:/tmp/schema_$TIMESTAMP.sql "$BACKUP_DIR/schema_$TIMESTAMP.sql"
    else
        pg_dump -h "$LOCAL_DB_HOST" \
            -U "$LOCAL_DB_USER" \
            -d "$LOCAL_DB_NAME" \
            --schema-only \
            -f "$BACKUP_DIR/schema_$TIMESTAMP.sql"
    fi
    
    echo -e "${GREEN}✅ Schema exportado: $BACKUP_DIR/schema_$TIMESTAMP.sql${NC}"
}

# Função para exportar apenas dados
export_data() {
    echo -e "${YELLOW}📊 Exportando dados...${NC}"
    
    mkdir -p "$BACKUP_DIR"
    
    if docker ps | grep -q supabase-db; then
        docker exec supabase-db pg_dump -U postgres postgres --data-only --column-inserts -f /tmp/data_$TIMESTAMP.sql
        docker cp supabase-db:/tmp/data_$TIMESTAMP.sql "$BACKUP_DIR/data_$TIMESTAMP.sql"
    else
        pg_dump -h "$LOCAL_DB_HOST" \
            -U "$LOCAL_DB_USER" \
            -d "$LOCAL_DB_NAME" \
            --data-only \
            --column-inserts \
            -f "$BACKUP_DIR/data_$TIMESTAMP.sql"
    fi
    
    echo -e "${GREEN}✅ Dados exportados: $BACKUP_DIR/data_$TIMESTAMP.sql${NC}"
}

# Função para transferir para servidor
transfer_to_server() {
    local file=$1
    echo -e "${YELLOW}📤 Transferindo $file para servidor...${NC}"
    
    if [ -z "$PRODUCTION_SERVER" ] || [ "$PRODUCTION_SERVER" = "usuario@seu-servidor-hostinger" ]; then
        echo -e "${RED}❌ Configure PRODUCTION_SERVER antes de usar!${NC}"
        echo "   export PRODUCTION_SERVER=usuario@seu-servidor-hostinger"
        return 1
    fi
    
    scp "$file" "$PRODUCTION_SERVER:/root/"
    echo -e "${GREEN}✅ Arquivo transferido${NC}"
}

# Menu principal
show_menu() {
    echo ""
    echo "Escolha uma opção:"
    echo "1) Backup completo (estrutura + dados)"
    echo "2) Exportar apenas schema (estrutura)"
    echo "3) Exportar apenas dados"
    echo "4) Transferir backup para servidor"
    echo "5) Executar todos os scripts SQL do projeto"
    echo "6) Sair"
    echo ""
    read -p "Opção: " option
    
    case $option in
        1)
            backup_local
            echo ""
            read -p "Deseja transferir para o servidor? (s/n): " transfer
            if [ "$transfer" = "s" ]; then
                transfer_to_server "$BACKUP_DIR/backup_local_$TIMESTAMP.dump"
            fi
            ;;
        2)
            export_schema
            echo ""
            read -p "Deseja transferir para o servidor? (s/n): " transfer
            if [ "$transfer" = "s" ]; then
                transfer_to_server "$BACKUP_DIR/schema_$TIMESTAMP.sql"
            fi
            ;;
        3)
            export_data
            echo ""
            read -p "Deseja transferir para o servidor? (s/n): " transfer
            if [ "$transfer" = "s" ]; then
                transfer_to_server "$BACKUP_DIR/data_$TIMESTAMP.sql"
            fi
            ;;
        4)
            echo "Backups disponíveis:"
            ls -lh "$BACKUP_DIR"/*.dump "$BACKUP_DIR"/*.sql 2>/dev/null | tail -10
            echo ""
            read -p "Nome do arquivo para transferir: " filename
            if [ -f "$BACKUP_DIR/$filename" ]; then
                transfer_to_server "$BACKUP_DIR/$filename"
            else
                echo -e "${RED}❌ Arquivo não encontrado!${NC}"
            fi
            ;;
        5)
            echo -e "${YELLOW}📝 Listando scripts SQL disponíveis...${NC}"
            echo ""
            echo "Execute estes scripts na ordem no SQL Editor do Supabase:"
            echo "https://srv750497.hstgr.cloud/project/default/sql/new"
            echo ""
            ls -1 *.sql | grep -E "^(criar_|configurar_|supabase_schema)" | head -20
            echo ""
            echo "Ou execute manualmente via psql no servidor"
            ;;
        6)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opção inválida!${NC}"
            ;;
    esac
}

# Verificar se pg_dump está disponível
if ! command -v pg_dump &> /dev/null && ! docker ps | grep -q supabase-db; then
    echo -e "${RED}❌ pg_dump não encontrado e Docker não está rodando!${NC}"
    echo "   Instale PostgreSQL client ou inicie o Docker"
    exit 1
fi

# Loop do menu
while true; do
    show_menu
done
