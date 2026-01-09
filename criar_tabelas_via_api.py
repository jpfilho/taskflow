#!/usr/bin/env python3
"""
Script para criar tabelas no Supabase usando a API REST
Como a API REST não executa SQL diretamente, este script verifica e fornece instruções
"""
import requests
import json

SUPABASE_URL = "https://srv750497.hstgr.cloud"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw"

headers_anon = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

headers_service = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

def verificar_tabela(nome):
    """Verifica se uma tabela existe tentando fazer uma query"""
    url = f"{SUPABASE_URL}/rest/v1/{nome}"
    try:
        response = requests.get(url, headers=headers_service, params={"limit": "0"}, timeout=5)
        if response.status_code == 200:
            return True
        elif response.status_code == 404:
            error_data = response.json() if response.text else {}
            if "PGRST205" in str(error_data) or "not found" in str(error_data).lower():
                return False
        return response.status_code in [200, 206]
    except Exception as e:
        print(f"   Erro ao verificar: {e}")
        return False

def criar_tabela_via_rpc():
    """Tenta criar tabelas via função RPC (se existir)"""
    # Isso só funcionaria se houver uma função RPC configurada no Supabase
    # Por enquanto, vamos apenas verificar
    pass

print("🔍 Verificando status das tabelas no Supabase...")
print(f"📍 URL: {SUPABASE_URL}\n")

tasks_existe = verificar_tabela("tasks")
segments_existe = verificar_tabela("gantt_segments")

print("📊 Status:")
print(f"   ✅ Tabela 'tasks': {'EXISTE' if tasks_existe else '❌ NÃO EXISTE'}")
print(f"   ✅ Tabela 'gantt_segments': {'EXISTE' if segments_existe else '❌ NÃO EXISTE'}\n")

if not tasks_existe or not segments_existe:
    print("⚠️  As tabelas precisam ser criadas!")
    print("\n📋 Para criar as tabelas, execute o SQL manualmente:")
    print("   1. Acesse: https://srv750497.hstgr.cloud/project/default")
    print("   2. Vá em 'SQL Editor'")
    print("   3. Clique em 'New Query'")
    print("   4. Copie o conteúdo de 'supabase_schema.sql'")
    print("   5. Cole e execute (Cmd+Enter ou Run)\n")
    print("📄 Ou use o comando abaixo se tiver acesso ao psql:")
    print("   psql -h [HOST] -U [USER] -d [DATABASE] -f supabase_schema.sql\n")
else:
    print("✅ Todas as tabelas existem!")
    print("\n🧪 Testando conexão...")
    
    # Tentar fazer uma query simples
    try:
        response = requests.get(
            f"{SUPABASE_URL}/rest/v1/tasks",
            headers=headers_service,
            params={"limit": "1"},
            timeout=5
        )
        if response.status_code == 200:
            print("✅ Conexão funcionando perfeitamente!")
            data = response.json()
            print(f"   Total de tarefas: {len(data) if isinstance(data, list) else 'N/A'}")
        else:
            print(f"⚠️  Resposta inesperada: {response.status_code}")
    except Exception as e:
        print(f"❌ Erro ao testar: {e}")

print("\n" + "="*60)
print("📝 Próximos passos:")
print("   1. Se as tabelas não existem, execute o SQL manualmente")
print("   2. O código Flutter já está configurado e funcionará automaticamente")
print("   3. Teste criando uma tarefa no app após criar as tabelas")
print("="*60)









