#!/bin/bash

# ============================================
# Script de Restore no Servidor de Produção
# ============================================
# Execute este script NO SERVIDOR DE PRODUÇÃO
# após transferir o backup

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Restore no Servidor de Produção${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""

# Verificar se está como root ou tem sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}⚠️  Executando sem root. Alguns comandos podem precisar de sudo.${NC}"
fi

# Localizar container do PostgreSQL
echo -e "${YELLOW}🔍 Localizando container do PostgreSQL...${NC}"
DB_CONTAINER=$(docker ps | grep -E "postgres|supabase-db" | awk '{print $1}' | head -1)

if [ -z "$DB_CONTAINER" ]; then
    echo -e "${RED}❌ Container do PostgreSQL não encontrado!${NC}"
    echo "Containers disponíveis:"
    docker ps
    exit 1
fi

echo -e "${GREEN}✅ Container encontrado: $DB_CONTAINER${NC}"
echo ""

# Listar backups disponíveis
echo -e "${YELLOW}📦 Backups disponíveis:${NC}"
ls -lh /root/*.dump /root/*.sql 2>/dev/null | tail -10
echo ""

# Solicitar arquivo de backup
read -p "Nome do arquivo de backup (ou caminho completo): " BACKUP_FILE

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Arquivo não encontrado: $BACKUP_FILE${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}⚠️  ATENÇÃO: Isso vai substituir TODOS os dados do banco de produção!${NC}"
read -p "Tem certeza que deseja continuar? (digite 'SIM' para confirmar): " CONFIRM

if [ "$CONFIRM" != "SIM" ]; then
    echo "Operação cancelada."
    exit 0
fi

# Fazer backup do banco atual antes de restaurar
echo ""
echo -e "${YELLOW}📦 Fazendo backup do banco atual antes de restaurar...${NC}"
CURRENT_BACKUP="/root/backup_producao_antes_restore_$(date +%Y%m%d_%H%M%S).dump"
docker exec "$DB_CONTAINER" pg_dump -U postgres postgres -F c -f /tmp/backup_atual.dump
docker cp "$DB_CONTAINER:/tmp/backup_atual.dump" "$CURRENT_BACKUP"
echo -e "${GREEN}✅ Backup de segurança criado: $CURRENT_BACKUP${NC}"
echo ""

# Verificar tipo de arquivo
if [[ "$BACKUP_FILE" == *.dump ]]; then
    echo -e "${YELLOW}🔄 Restaurando backup binário (.dump)...${NC}"
    
    # Copiar arquivo para dentro do container
    docker cp "$BACKUP_FILE" "$DB_CONTAINER:/tmp/restore.dump"
    
    # Restaurar
    docker exec -i "$DB_CONTAINER" pg_restore \
        -U postgres \
        -d postgres \
        --clean \
        --if-exists \
        --verbose \
        /tmp/restore.dump
    
    # Limpar arquivo temporário
    docker exec "$DB_CONTAINER" rm /tmp/restore.dump
    
elif [[ "$BACKUP_FILE" == *.sql ]]; then
    echo -e "${YELLOW}🔄 Restaurando backup SQL (.sql)...${NC}"
    
    # Copiar arquivo para dentro do container
    docker cp "$BACKUP_FILE" "$DB_CONTAINER:/tmp/restore.sql"
    
    # Executar SQL
    docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -f /tmp/restore.sql
    
    # Limpar arquivo temporário
    docker exec "$DB_CONTAINER" rm /tmp/restore.sql
    
else
    echo -e "${RED}❌ Formato de arquivo não suportado! Use .dump ou .sql${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Restore concluído!${NC}"
echo ""

# Verificar tabelas
echo -e "${YELLOW}🔍 Verificando tabelas...${NC}"
docker exec "$DB_CONTAINER" psql -U postgres -d postgres -c "\dt" | head -20
echo ""

# Verificar contagem de registros em algumas tabelas principais
echo -e "${YELLOW}📊 Contagem de registros em tabelas principais:${NC}"
for table in tasks executores status tipos_atividade regionais divisoes; do
    count=$(docker exec "$DB_CONTAINER" psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM $table;" 2>/dev/null | tr -d ' ')
    if [ ! -z "$count" ] && [ "$count" != "0" ]; then
        echo "  $table: $count registros"
    fi
done
echo ""

echo -e "${GREEN}✅ Restore finalizado com sucesso!${NC}"
echo ""
echo -e "${YELLOW}📝 Próximos passos:${NC}"
echo "  1. Verificar se a aplicação está funcionando"
echo "  2. Testar login/logout"
echo "  3. Verificar se os dados estão corretos"
echo "  4. Se houver problemas, restaurar o backup de segurança:"
echo "     $CURRENT_BACKUP"
