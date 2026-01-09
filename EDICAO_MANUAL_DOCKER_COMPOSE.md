# 📝 Editar docker-compose.yml Manualmente

## Passo a Passo:

### 1. Acessar o diretório:
```bash
cd /root/supabase/docker
```

### 2. Fazer backup:
```bash
cp docker-compose.yml docker-compose.yml.backup
```

### 3. Editar o arquivo:
```bash
nano docker-compose.yml
```

### 4. Localizar a seção `supabase-auth`:
Procure por:
```yaml
  supabase-auth:
    container_name: supabase-auth
    image: supabase/gotrue:v2.180.0
    ...
    environment:
      - GOTRUE_API_HOST=0.0.0.0
      - GOTRUE_API_PORT=9999
      - API_EXTERNAL_URL=${API_EXTERNAL_URL}
      - GOTRUE_DB_DRIVER=postgres
      - GOTRUE_DB_DATABASE_URL=postgres://...
      - GOTRUE_SITE_URL=${SITE_URL}
```

### 5. Adicionar estas duas linhas DEPOIS de `GOTRUE_SITE_URL`:
```yaml
      - GOTRUE_SITE_URL=${SITE_URL}
      - GOTRUE_MAILER_AUTOCONFIRM=true
      - ENABLE_EMAIL_AUTOCONFIRM=true
```

**Importante:** Mantenha a indentação (6 espaços antes do `-`)

### 6. Salvar:
- **Nano:** `Ctrl + O`, `Enter`, `Ctrl + X`
- **Vi:** `:wq`

### 7. Reiniciar o container:
```bash
docker restart supabase-auth
```

### 8. Verificar logs:
```bash
docker logs supabase-auth --tail 20
```

## Ou use o script automático:

```bash
cd /root/supabase/docker
chmod +x adicionar_email_docker_compose.sh
./adicionar_email_docker_compose.sh
```

## Resultado Esperado:

Após reiniciar, ao criar um novo usuário:
- ✅ Não deve mais aparecer erro 500
- ✅ Usuário será criado e logado automaticamente
- ✅ Não precisará confirmar email






