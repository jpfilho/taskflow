#!/bin/bash

# ============================================
# Deploy SQL para Produção - Hostinger
# ============================================
# Este script executa os scripts SQL diretamente
# no Supabase de produção via SQL Editor

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SUPABASE_URL="https://srv750497.hstgr.cloud"
SQL_EDITOR_URL="$SUPABASE_URL/project/default/sql/new"

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Deploy SQL para Produção - Hostinger${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""

# Ordem de execução dos scripts SQL
declare -a SCRIPTS=(
    "supabase_schema.sql"
    "criar_tabela_usuarios.sql"
    "criar_tabela_executores.sql"
    "criar_tabela_status.sql"
    "criar_tabela_tipos_atividade.sql"
    "criar_tabela_regionais.sql"
    "criar_tabela_divisoes.sql"
    "criar_tabela_segmentos.sql"
    "criar_tabela_locais.sql"
    "criar_tabela_equipes.sql"
    "criar_tabela_empresas.sql"
    "criar_tabela_funcoes.sql"
    "criar_tabela_divisoes_segmentos.sql"
    "criar_tabela_executores_segmentos.sql"
    "criar_tabelas_juncao_tasks.sql"
    "criar_tabela_feriados.sql"
    "criar_tabela_anexos.sql"
    "criar_tabela_curtidas.sql"
    "criar_tabela_executor_periods.sql"
    "criar_tabelas_chat.sql"
    "criar_tabela_notas_sap.sql"
    "configurar_auth_supabase_sql.sql"
    "configurar_storage_policies.sql"
    "adicionar_cor_tipo_atividade.sql"
    "adicionar_coluna_cor_status.sql"
    "adicionar_tipo_periodo_gantt_segments.sql"
)

echo -e "${YELLOW}📋 Scripts SQL encontrados:${NC}"
for i in "${!SCRIPTS[@]}"; do
    if [ -f "${SCRIPTS[$i]}" ]; then
        echo -e "  ${GREEN}✅${NC} $((i+1)). ${SCRIPTS[$i]}"
    else
        echo -e "  ${RED}❌${NC} $((i+1)). ${SCRIPTS[$i]} (não encontrado)"
    fi
done
echo ""

# Função para criar arquivo consolidado
create_consolidated_sql() {
    local output_file="deploy_completo_$(date +%Y%m%d_%H%M%S).sql"
    
    echo -e "${YELLOW}📝 Criando arquivo SQL consolidado...${NC}"
    
    cat > "$output_file" << EOF
-- ============================================
-- DEPLOY COMPLETO PARA PRODUÇÃO
-- Gerado em: $(date)
-- Supabase: $SUPABASE_URL
-- ============================================

-- IMPORTANTE: Execute este script no SQL Editor do Supabase
-- URL: $SQL_EDITOR_URL

EOF

    local executed=0
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            echo "" >> "$output_file"
            echo "-- ============================================" >> "$output_file"
            echo "-- Arquivo: $script" >> "$output_file"
            echo "-- ============================================" >> "$output_file"
            echo "" >> "$output_file"
            cat "$script" >> "$output_file"
            echo "" >> "$output_file"
            ((executed++))
        fi
    done
    
    echo "" >> "$output_file"
    echo "-- ============================================" >> "$output_file"
    echo "-- FIM DO DEPLOY" >> "$output_file"
    echo "-- ============================================" >> "$output_file"
    
    echo -e "${GREEN}✅ Arquivo criado: $output_file${NC}"
    echo -e "${BLUE}   Total de scripts incluídos: $executed${NC}"
    echo ""
    
    # Mostrar tamanho do arquivo
    local size=$(du -h "$output_file" | cut -f1)
    echo -e "${YELLOW}   Tamanho: $size${NC}"
    echo ""
    
    return 0
}

# Função para listar scripts individuais
list_scripts() {
    echo -e "${YELLOW}📋 Scripts SQL disponíveis:${NC}"
    echo ""
    for i in "${!SCRIPTS[@]}"; do
        if [ -f "${SCRIPTS[$i]}" ]; then
            local size=$(du -h "${SCRIPTS[$i]}" | cut -f1)
            printf "  %2d. ${GREEN}✅${NC} %-50s ${BLUE}(%s)${NC}\n" $((i+1)) "${SCRIPTS[$i]}" "$size"
        else
            printf "  %2d. ${RED}❌${NC} %-50s ${RED}(não encontrado)${NC}\n" $((i+1)) "${SCRIPTS[$i]}"
        fi
    done
    echo ""
}

# Função para abrir SQL Editor no navegador
open_sql_editor() {
    echo -e "${YELLOW}🌐 Abrindo SQL Editor no navegador...${NC}"
    
    if command -v open &> /dev/null; then
        # macOS
        open "$SQL_EDITOR_URL"
    elif command -v xdg-open &> /dev/null; then
        # Linux
        xdg-open "$SQL_EDITOR_URL"
    elif command -v start &> /dev/null; then
        # Windows
        start "$SQL_EDITOR_URL"
    else
        echo -e "${YELLOW}⚠️  Não foi possível abrir o navegador automaticamente.${NC}"
        echo -e "${BLUE}   Acesse manualmente: $SQL_EDITOR_URL${NC}"
    fi
}

# Menu
show_menu() {
    echo ""
    echo "Escolha uma opção:"
    echo "1) Criar arquivo SQL consolidado (todos os scripts)"
    echo "2) Listar scripts SQL disponíveis"
    echo "3) Abrir SQL Editor no navegador"
    echo "4) Ver conteúdo de um script específico"
    echo "5) Sair"
    echo ""
    read -p "Opção: " option
    
    case $option in
        1)
            create_consolidated_sql
            echo ""
            read -p "Deseja abrir o SQL Editor no navegador? (s/n): " open
            if [ "$open" = "s" ]; then
                open_sql_editor
            fi
            ;;
        2)
            list_scripts
            ;;
        3)
            open_sql_editor
            ;;
        4)
            list_scripts
            read -p "Digite o número do script para ver: " num
            if [ "$num" -ge 1 ] && [ "$num" -le "${#SCRIPTS[@]}" ]; then
                script="${SCRIPTS[$((num-1))]}"
                if [ -f "$script" ]; then
                    echo ""
                    echo -e "${GREEN}Conteúdo de: $script${NC}"
                    echo "=========================================="
                    cat "$script"
                    echo "=========================================="
                else
                    echo -e "${RED}❌ Arquivo não encontrado!${NC}"
                fi
            else
                echo -e "${RED}❌ Número inválido!${NC}"
            fi
            ;;
        5)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opção inválida!${NC}"
            ;;
    esac
}

# Verificar se há scripts SQL
if [ ! -f "supabase_schema.sql" ] && [ ! -f "criar_tabela_usuarios.sql" ]; then
    echo -e "${RED}❌ Nenhum script SQL encontrado no diretório atual!${NC}"
    echo "   Execute este script no diretório do projeto."
    exit 1
fi

# Loop do menu
while true; do
    show_menu
done
