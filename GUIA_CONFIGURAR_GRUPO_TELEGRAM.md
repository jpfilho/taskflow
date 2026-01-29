# 📋 GUIA: CONFIGURAR GRUPO TELEGRAM PARA TASKFLOW

## ✅ Passo a Passo

### 1. Criar o Grupo
- Crie um grupo no Telegram
- Dê um nome que corresponda à comunidade (ex: "NEPTRFMT - Linhas de Transmissão")

### 2. Adicionar o Bot
- Adicione o bot **@TaskFlow_chat_bot** ao grupo
- O bot enviará uma mensagem de boas-vindas

### 3. Converter para Supergrupo
- Vá em **Configurações do Grupo**
- Clique em **Converter para Supergrupo**
- Confirme a conversão

### 4. Habilitar Tópicos (Fórum)
- Vá em **Configurações do Grupo**
- Clique em **Tipo**
- Selecione **Fórum** (Tópicos)
- Confirme a ativação

### 5. Tornar o Bot Administrador
- Vá em **Membros** ou **Administradores**
- Encontre o bot **@TaskFlow_chat_bot**
- Torne-o **Administrador**
- Dê a permissão **"Manage Topics"** (Gerenciar Tópicos)

### 6. Enviar Mensagem no Grupo
- Envie qualquer mensagem no grupo
- O bot detectará automaticamente e tentará associar à comunidade correspondente

### 7. Se Não Identificar Automaticamente
- Use o comando: `/associar`
- Isso listará todas as comunidades disponíveis
- Use: `/associar <ID_DA_COMUNIDADE>` para associar manualmente

## 🔍 Verificar Configuração

Execute o script:
```powershell
.\verificar_configuracao_grupo.ps1
```

Isso mostrará:
- Se o grupo está cadastrado
- Chat ID do grupo
- Status da configuração

## ⚠️ Problemas Comuns

### "Grupo não é supergrupo"
- Converta o grupo para supergrupo (passo 3)

### "Supergrupo não tem tópicos habilitados"
- Habilite os tópicos (passo 4)

### "Bot não é administrador"
- Torne o bot administrador (passo 5)

### "Não identificou a comunidade"
- Use o comando `/associar` no grupo (passo 7)
