# Edição Manual - Mapear Porta Postgres

## Problema
O arquivo `docker-compose.yml` está corrompido e precisa ser restaurado e editado manualmente.

## Passo a Passo

### 1. Acessar o servidor
```bash
ssh root@212.85.0.249
```

### 2. Restaurar backup mais recente
```bash
cd /root/supabase/docker
ls -t docker-compose.yml.backup_* | head -1
# Copie o nome do backup mais recente e execute:
cp docker-compose.yml.backup_20260125_112228 docker-compose.yml
# (substitua pela data do backup mais recente)
```

### 3. Fazer novo backup
```bash
cp docker-compose.yml docker-compose.yml.backup_manual_$(date +%Y%m%d_%H%M%S)
```

### 4. Editar o arquivo
```bash
nano docker-compose.yml
```

### 5. Encontrar a seção `db:`
Procure por:
```yaml
  db:
    container_name: supabase-db
    image: supabase/postgres:15.8.1.085
    restart: unless-stopped
```

### 6. Adicionar `ports:` logo após `restart:`
Adicione estas duas linhas **logo após** `restart: unless-stopped`:
```yaml
  db:
    container_name: supabase-db
    image: supabase/postgres:15.8.1.085
    restart: unless-stopped
    ports:
      - "5433:5432"
    volumes:
      # ... resto continua igual
```

**IMPORTANTE:** 
- Mantenha a indentação de 2 espaços para `ports:`
- Mantenha a indentação de 6 espaços para `- "5433:5432"`

### 7. Salvar
- Pressione `Ctrl+O` (salvar)
- Pressione `Enter` (confirmar)
- Pressione `Ctrl+X` (sair)

### 8. Validar o arquivo
```bash
docker-compose config -q
```
Se não mostrar erros, está válido!

### 9. Resolver conflito de containers (se necessário)
Se aparecer erro sobre `supabase-vector` já existir, você tem duas opções:

**⚠️ É SEGURO remover o `supabase-vector`:** Não afeta dados (estão em volumes), não desconfigura o Supabase, e não afeta o N8N. Veja `SEGURANCA_REMOCAO_VECTOR.md` para detalhes.

**Opção A - Script Automático (Recomendado):**
Execute no PowerShell local:
```powershell
.\resolver_conflito_e_reiniciar_db.ps1
```

**Opção B - Manual:**
Execute no servidor:
```bash
# Parar e remover o container conflitante
docker stop supabase-vector 2>/dev/null
docker rm supabase-vector 2>/dev/null
```

### 10. Reiniciar o container
```bash
# Parar o serviço
docker-compose stop db

# Remover o container para evitar conflito de nome
docker stop supabase-db 2>/dev/null
docker rm supabase-db 2>/dev/null

# Reiniciar (recria automaticamente com a nova configuração)
docker-compose up -d db
```
**IMPORTANTE:** 
- Use `db` (nome do serviço), não `supabase-db` (nome do container)!
- Remover o container é seguro - os dados estão em volumes persistentes
- O `docker-compose up -d` recria o container com a nova configuração de porta

### 11. Verificar se funcionou
```bash
docker port supabase-db 5432
```
Deve mostrar: `0.0.0.0:5433`

## Configuração no N8N

Após mapear a porta, configure no N8N:

- **Host:** `212.85.0.249`
- **Port:** `5433`
- **Database:** `postgres`
- **User:** `postgres`
- **Password:** `KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA`
- **SSL:** Desabilitado (Ignore SSL Issues)

## Exemplo Visual

A seção `db:` deve ficar assim:

```yaml
  db:
    container_name: supabase-db
    image: supabase/postgres:15.8.1.085
    restart: unless-stopped
    ports:
      - "5433:5432"
    volumes:
      - ./volumes/db/realtime.sql:/docker-entrypoint-initdb.d/migrations/99-realtime.sql:Z
      # ... resto das volumes
```
