# 🚀 Configuração Rápida do MCP Supabase no Cursor

## Método 1: Script Automatizado (Recomendado)

```bash
cd /Users/josepereiradasilvafilho/aplicativos/task/task2026
bash configurar_mcp_supabase.sh
```

O script irá guiá-lo através de todo o processo!

---

## Método 2: Configuração Manual

### Passo 1: Obter Credenciais do Supabase

1. Acesse: https://srv750497.hstgr.cloud/project/default
2. Vá em **Settings** > **API**
3. Copie:
   - **anon public key**
   - **service_role key** (opcional)

### Passo 2: Editar o Arquivo mcp.json do Cursor

1. Abra o arquivo: `~/Library/Application Support/Cursor/mcp.json`
2. Adicione a seguinte configuração:

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": [
        "-y",
        "@supabase/mcp-server-supabase"
      ],
      "env": {
        "SUPABASE_URL": "https://srv750497.hstgr.cloud",
        "SUPABASE_ANON_KEY": "COLE_SUA_CHAVE_ANON_AQUI",
        "SUPABASE_SERVICE_ROLE_KEY": "COLE_SUA_SERVICE_ROLE_KEY_AQUI"
      }
    }
  }
}
```

### Passo 3: Reiniciar o Cursor

Após salvar o arquivo, reinicie o Cursor completamente.

### Passo 4: Verificar

1. Pressione `Cmd + Shift + P`
2. Digite "MCP: List Servers"
3. Você deve ver "supabase" na lista

---

## 📁 Arquivos Criados

- `mcp_supabase_config.json` - Template de configuração
- `configurar_mcp_supabase.sh` - Script de configuração automatizada
- `CURSOR_MCP_SUPABASE.md` - Documentação completa

---

## ✅ Pronto!

Agora você pode usar o Supabase diretamente pelo Cursor através do MCP!











