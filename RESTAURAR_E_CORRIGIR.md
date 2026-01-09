# 🔄 Restaurar Backup e Corrigir

## Situação:
O container `supabase-auth` foi removido quando tentamos recriá-lo com o docker-compose.yml quebrado.

## Solução:

### 1. Restaurar o backup do docker-compose.yml:
```bash
cd /root/supabase/docker
ls -lt docker-compose.yml.backup* | head -1
```

Isso mostra o backup mais recente. Depois:

```bash
# Substitua BACKUP_FILE pelo nome do arquivo mais recente
cp docker-compose.yml.backup.* docker-compose.yml
```

Ou se souber o nome exato:
```bash
cp docker-compose.yml.backup docker-compose.yml
```

### 2. Editar APENAS a linha necessária:
```bash
nano docker-compose.yml
```

### 3. Procurar a linha do GOTRUE_MAILER_AUTOCONFIRM:
- Pressione `Ctrl + W` (buscar)
- Digite `GOTRUE_MAILER_AUTOCONFIRM`
- Pressione `Enter`

### 4. Alterar de:
```yaml
GOTRUE_MAILER_AUTOCONFIRM: ${ENABLE_EMAIL_AUTOCONFIRM}
```

### 5. Para:
```yaml
GOTRUE_MAILER_AUTOCONFIRM: "true"
```

**Importante:** Use aspas duplas `"true"` e mantenha a indentação correta!

### 6. Salvar:
- `Ctrl + O` (salvar)
- `Enter` (confirmar)
- `Ctrl + X` (sair)

### 7. Validar:
```bash
docker-compose config > /dev/null 2>&1 && echo "✅ Válido!" || echo "❌ Ainda há erros"
```

### 8. Recriar o container:
```bash
docker-compose up -d supabase-auth
```

### 9. Verificar:
```bash
docker ps | grep supabase-auth
docker exec supabase-auth env | grep -i "MAILER_AUTOCONFIRM"
```

**Execute os passos e me mostre o resultado!**






