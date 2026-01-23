#!/usr/bin/env python3
"""
Script para executar o debug SQL de horas programadas no Supabase
Execute: python3 executar_debug_sql.py
"""

import os
import sys
from supabase import create_client, Client

# Configurações do Supabase
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://srv750497.hstgr.cloud")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY", "")

if not SUPABASE_KEY:
    print("❌ Erro: SUPABASE_ANON_KEY não configurada!")
    print("Configure a variável de ambiente ou edite este script.")
    sys.exit(1)

# Criar cliente Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def executar_consulta(consulta_sql, nome_consulta):
    """Executa uma consulta SQL e exibe os resultados"""
    print(f"\n{'='*60}")
    print(f"CONSULTA: {nome_consulta}")
    print(f"{'='*60}\n")
    
    try:
        # Executar SQL via RPC (se disponível) ou usar PostgREST
        # Nota: Supabase Python client não suporta SQL direto, então vamos usar uma abordagem alternativa
        print("⚠️  O cliente Python do Supabase não suporta SQL direto.")
        print("Por favor, execute as consultas manualmente no SQL Editor do Supabase:")
        print(f"   {SUPABASE_URL.replace('https://', 'https://app.supabase.com/project/')}")
        print("\nOu use o arquivo debug_horas_programadas_janeiro_2026.sql")
        return None
    except Exception as e:
        print(f"❌ Erro ao executar consulta: {e}")
        return None

def main():
    print("="*60)
    print("DEBUG: Horas Programadas - Janeiro 2026")
    print("="*60)
    print("\nEste script ajuda a debugar por que as horas programadas")
    print("não estão sendo calculadas corretamente.\n")
    
    # Ler o arquivo SQL
    try:
        with open('debug_horas_programadas_janeiro_2026.sql', 'r') as f:
            sql_content = f.read()
        print("✅ Arquivo SQL encontrado: debug_horas_programadas_janeiro_2026.sql")
    except FileNotFoundError:
        print("❌ Arquivo debug_horas_programadas_janeiro_2026.sql não encontrado!")
        return
    
    print("\n" + "="*60)
    print("INSTRUÇÕES PARA EXECUTAR:")
    print("="*60)
    print("\n1. Acesse o Supabase Dashboard:")
    print(f"   {SUPABASE_URL}")
    print("\n2. Vá em 'SQL Editor'")
    print("\n3. Copie e cole cada consulta do arquivo:")
    print("   debug_horas_programadas_janeiro_2026.sql")
    print("\n4. Execute cada consulta separadamente")
    print("\n5. Analise os resultados para entender:")
    print("   - Quais executores têm períodos em janeiro de 2026")
    print("   - Quantas horas estão programadas por executor")
    print("   - Se os períodos estão sendo filtrados corretamente")
    print("\n" + "="*60)
    
    # Tentar buscar dados via API (sem SQL direto)
    print("\n📊 Tentando buscar dados via API...")
    try:
        # Buscar períodos de executor
        response = supabase.table('executor_periods').select('*').limit(5).execute()
        if response.data:
            print(f"✅ Conectado ao Supabase! Encontrados {len(response.data)} períodos (limitado a 5)")
            print("\nExemplo de período encontrado:")
            if response.data:
                print(f"   Task ID: {response.data[0].get('task_id', 'N/A')[:8]}...")
                print(f"   Executor ID: {response.data[0].get('executor_id', 'N/A')[:8]}...")
                print(f"   Tipo: {response.data[0].get('tipo', 'N/A')}")
                print(f"   Data Início: {response.data[0].get('data_inicio', 'N/A')}")
                print(f"   Data Fim: {response.data[0].get('data_fim', 'N/A')}")
        else:
            print("⚠️  Nenhum período encontrado")
    except Exception as e:
        print(f"⚠️  Erro ao conectar: {e}")
        print("   Isso é normal se você não tiver as credenciais configuradas.")
    
    print("\n" + "="*60)
    print("PRÓXIMOS PASSOS:")
    print("="*60)
    print("\nExecute as consultas SQL manualmente e compartilhe os resultados")
    print("para que possamos ajustar o cálculo de horas programadas.\n")

if __name__ == "__main__":
    main()
