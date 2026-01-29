# Troubleshooting - Conexão N8N com Postgres

## 🔴 Erro: "Couldn't connect with these settings"

Este documento ajuda a resolver problemas de conexão do N8N com o banco de dados Postgres do Supabase.

## 📋 Configuração Atual (da Imagem)

- **Host**: `212.85.0.249`
- **Database**: `postgres`
- **User**: `supabase`
- **Password**: (preenchida)
- **Port**: (não visível na imagem, mas deve ser `5432`)

## 🔍 Checklist de Diagnóstico

### 1. Verificar Porta

A porta padrão do Postgres é `5432`. Certifique-se de que está configurada no N8N:

1. No N8N, abra a configuração da credencial Postgres
2. Verifique se a **Port** está definida como `5432`
3. Se não estiver, adicione: `5432`

### 2. Verificar Credenciais

O usuário `supabase` pode não ser o correto. Tente:

**Opção A: Usuário `postgres` (padrão)**
- **User**: `postgres`
- **Password**: (senha do Supabase)

**Opção B: Verificar usuário correto no servidor**

Execute no servidor:
```bash
ssh root@212.85.0.249
sudo -u postgres psql -c "\du"
```

Isso listará todos os usuários do Postgres.

### 3. Verificar Acesso Externo

O Postgres pode estar configurado para aceitar apenas conexões locais. Verifique:

**No servidor (212.85.0.249):**

```bash
ssh root@212.85.0.249

# Verificar configuração do Postgres
sudo cat /etc/postgresql/*/main/postgresql.conf | grep listen_addresses

# Verificar se está escutando em todas as interfaces
# Deve mostrar: listen_addresses = '*'
```

**Se não estiver configurado:**

```bash
# Editar postgresql.conf
sudo nano /etc/postgresql/*/main/postgresql.conf

# Alterar:
# listen_addresses = '*'

# Editar pg_hba.conf para permitir conexões externas
sudo nano /etc/postgresql/*/main/pg_hba.conf

# Adicionar linha:
# host    all             all             0.0.0.0/0               md5

# Reiniciar Postgres
sudo systemctl restart postgresql
```

### 4. Verificar Firewall

O firewall pode estar bloqueando a porta 5432:

```bash
ssh root@212.85.0.249

# Verificar se a porta está aberta
sudo ufw status | grep 5432
# ou
sudo firewall-cmd --list-ports | grep 5432

# Se não estiver, liberar:
sudo ufw allow 5432/tcp
# ou
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --reload
```

### 5. Verificar SSL/TLS

Alguns Supabase self-hosted requerem SSL. No N8N:

1. Abra a configuração da credencial Postgres
2. Procure por **SSL** ou **TLS**
3. Tente as opções:
   - **SSL**: `Required` ou `Prefer`
   - **Reject Unauthorized**: `false` (para certificados auto-assinados)

### 6. Testar Conexão Direta

Teste a conexão diretamente do servidor onde o N8N está rodando:

```bash
# Se o N8N está no mesmo servidor (212.85.0.249)
psql -h 212.85.0.249 -U supabase -d postgres

# Ou de outro servidor
psql -h 212.85.0.249 -p 5432 -U supabase -d postgres
```

Se funcionar, o problema é na configuração do N8N. Se não funcionar, o problema é no Postgres.

## 🔧 Soluções Comuns

### Solução 1: Usar Usuário `postgres`

Muitas vezes o usuário correto é `postgres`, não `supabase`:

1. No N8N, edite a credencial Postgres
2. Altere **User** de `supabase` para `postgres`
3. Mantenha a mesma senha
4. Clique em **Test** ou **Save**

### Solução 2: Adicionar Porta Explicitamente

1. No N8N, edite a credencial Postgres
2. Certifique-se de que **Port** está definida como `5432`
3. Salve e teste

### Solução 3: Configurar SSL

1. No N8N, edite a credencial Postgres
2. Procure **SSL Mode** ou **SSL**
3. Selecione `require` ou `prefer`
4. Se houver erro de certificado, marque **Reject Unauthorized** como `false`
5. Salve e teste

### Solução 4: Verificar Host Correto

Se o Supabase está rodando em Docker, o host pode ser diferente:

```bash
ssh root@212.85.0.249

# Verificar containers Docker
docker ps | grep postgres

# Verificar portas mapeadas
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep postgres
```

Se o Postgres estiver em Docker, pode estar mapeado para outra porta (ex: `5433:5432`).

## 📝 Configuração Recomendada no N8N

Após verificar os itens acima, use esta configuração:

```
Host: 212.85.0.249
Port: 5432
Database: postgres
User: postgres (ou supabase, conforme verificado)
Password: [senha do Supabase]
SSL: Prefer (ou Required, conforme necessário)
Reject Unauthorized: false (se usar SSL com certificado auto-assinado)
Maximum Number of Connections: 100
```

## 🧪 Teste Rápido

Execute este comando no servidor para verificar se o Postgres está acessível:

```bash
ssh root@212.85.0.249 "netstat -tuln | grep 5432"
```

Deve mostrar algo como:
```
tcp        0      0 0.0.0.0:5432            0.0.0.0:*               LISTEN
```

Se não mostrar nada, o Postgres não está escutando na porta 5432 ou está bloqueado.

## 🔗 Próximos Passos

1. Verifique cada item do checklist acima
2. Teste a conexão usando `psql` diretamente
3. Ajuste a configuração no N8N conforme necessário
4. Se ainda não funcionar, verifique os logs do Postgres:

```bash
ssh root@212.85.0.249
sudo tail -f /var/log/postgresql/postgresql-*-main.log
```

Enquanto tenta conectar pelo N8N, observe os logs para ver mensagens de erro específicas.
