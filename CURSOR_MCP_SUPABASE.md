# Configuração do MCP Supabase no Cursor

## 📋 Passos para Configurar

### 1. Instalar o Servidor MCP do Supabase

Execute no terminal:
```bash
npm install -g @supabase/mcp-server-supabase
```

Ou usando npx (sem instalação global):
```bash
npx -y @supabase/mcp-server-supabase
```

### 2. Obter Credenciais do Supabase

1. Acesse: https://srv750497.hstgr.cloud/project/default
2. Vá em **Settings** > **API**
3. Copie:
   - **Project URL**: `https://srv750497.hstgr.cloud`
   - **anon public key**: (sua chave anon)
   - **service_role key**: (opcional, para operações administrativas)

### 3. Configurar no Cursor

1. Abra o Cursor
2. Pressione `Cmd + Shift + P` (Mac) ou `Ctrl + Shift + P` (Windows/Linux)
3. Digite "MCP" e selecione "MCP: Configure Servers"
4. Ou edite diretamente o arquivo: `~/Library/Application Support/Cursor/mcp.json`

### 4. Adicionar Configuração do Supabase

Adicione a seguinte configuração ao arquivo `mcp.json`:

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
        "SUPABASE_ANON_KEY": "SUA_CHAVE_ANON_AQUI",
        "SUPABASE_SERVICE_ROLE_KEY": "SUA_SERVICE_ROLE_KEY_AQUI"
      }
    }
  }
}
```

**Substitua:**
- `SUA_CHAVE_ANON_AQUI` pela sua chave anon do Supabase
- `SUA_SERVICE_ROLE_KEY_AQUI` pela sua service role key (opcional, mas recomendado)

### 5. Reiniciar o Cursor

Após adicionar a configuração, reinicie o Cursor para que as mudanças tenham efeito.

### 6. Verificar a Conexão

1. No Cursor, pressione `Cmd + Shift + P`
2. Digite "MCP" e selecione "MCP: List Servers"
3. Você deve ver o servidor "supabase" listado
4. Verifique se as ferramentas estão disponíveis

## 🔧 Exemplo de Arquivo mcp.json Completo

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
        "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        "SUPABASE_SERVICE_ROLE_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
      }
    }
  }
}
```

## 🎯 Funcionalidades Disponíveis

Com o MCP do Supabase configurado, você poderá:

- ✅ Consultar tabelas do banco de dados
- ✅ Executar queries SQL
- ✅ Criar/atualizar/deletar registros
- ✅ Gerenciar schema do banco
- ✅ Visualizar dados em tempo real
- ✅ Interagir com o Supabase diretamente pelo Cursor

## 🐛 Troubleshooting

### Erro: "No tools found"
- Verifique se as credenciais estão corretas
- Certifique-se de que o Node.js está instalado
- Tente reinstalar o pacote: `npm install -g @supabase/mcp-server-supabase`

### Erro: "Connection refused"
- Verifique se a URL do Supabase está correta
- Certifique-se de que o projeto Supabase está ativo

### Erro: "Invalid API key"
- Verifique se a chave anon está correta
- Certifique-se de copiar a chave completa (sem espaços)

## 📝 Notas Importantes

1. **Segurança**: Nunca commite o arquivo `mcp.json` com suas chaves no Git
2. **Service Role Key**: Use com cuidado, pois tem permissões administrativas
3. **Anon Key**: É segura para uso público, mas ainda assim, não compartilhe

## 🔗 Links Úteis

- [Documentação do Supabase MCP](https://github.com/supabase/mcp-server-supabase)
- [Dashboard do Supabase](https://srv750497.hstgr.cloud/project/default)
- [Documentação do Cursor MCP](https://docs.cursor.com/mcp)











