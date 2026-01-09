#!/usr/bin/env python3
"""
Script para criar as tabelas no Supabase usando a API REST
"""
import requests
import json

# Configurações do Supabase
SUPABASE_URL = "https://srv750497.hstgr.cloud"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw"

# Headers para requisições
headers = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

def executar_sql(sql_query):
    """Executa uma query SQL no Supabase usando RPC"""
    url = f"{SUPABASE_URL}/rest/v1/rpc/exec_sql"
    
    # Para self-hosted Supabase, pode precisar usar o endpoint SQL direto
    # Vamos tentar usar o PostgREST para executar SQL via função
    print(f"📝 Executando SQL...")
    print(f"Query: {sql_query[:100]}...")
    
    # Alternativa: usar o endpoint de migração se disponível
    # Ou criar uma função RPC que executa SQL dinâmico
    
    # Por enquanto, vamos usar requests.post para tentar executar
    # Nota: Isso pode não funcionar diretamente, mas vamos tentar
    try:
        response = requests.post(
            url,
            headers=headers,
            json={"query": sql_query},
            timeout=30
        )
        print(f"Status: {response.status_code}")
        if response.status_code == 200 or response.status_code == 201:
            print("✅ Sucesso!")
            return True
        else:
            print(f"❌ Erro: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Erro ao executar: {e}")
        return False

def verificar_tabela_existe(nome_tabela):
    """Verifica se uma tabela já existe"""
    url = f"{SUPABASE_URL}/rest/v1/{nome_tabela}"
    try:
        response = requests.get(
            url,
            headers=headers,
            params={"limit": "1"},
            timeout=10
        )
        # Se retornar 200 ou 404, a tabela existe (404 pode ser RLS)
        # Se retornar outro erro, pode não existir
        return response.status_code in [200, 404]
    except:
        return False

if __name__ == "__main__":
    print("🚀 Iniciando criação das tabelas no Supabase...")
    print(f"📍 URL: {SUPABASE_URL}\n")
    
    # Ler o schema SQL
    with open("supabase_schema.sql", "r") as f:
        schema_sql = f.read()
    
    # Verificar se as tabelas já existem
    tasks_existe = verificar_tabela_existe("tasks")
    segments_existe = verificar_tabela_existe("gantt_segments")
    
    print(f"📊 Status das tabelas:")
    print(f"   - tasks: {'✅ Existe' if tasks_existe else '❌ Não existe'}")
    print(f"   - gantt_segments: {'✅ Existe' if segments_existe else '❌ Não existe'}\n")
    
    if tasks_existe and segments_existe:
        print("✅ As tabelas já existem!")
    else:
        print("⚠️  Para criar as tabelas, você precisa:")
        print("   1. Acessar o dashboard: https://srv750497.hstgr.cloud/project/default")
        print("   2. Ir em SQL Editor")
        print("   3. Copiar o conteúdo de supabase_schema.sql")
        print("   4. Colar e executar")
        print("\n   Ou usar o MCP do Supabase se estiver configurado corretamente.")
    
    print("\n📋 Schema SQL está em: supabase_schema.sql")









