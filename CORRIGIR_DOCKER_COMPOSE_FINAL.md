# 🔧 Correções Finais no docker-compose.yml

## Erros Identificados:

1. **Imagem do auth incorreta:** `supabase/go"true":v2.180.0` → deve ser `supabase/gotrue:v2.180.0`
2. **Comentários com erro:** `GO"true"` → deve ser `GOTRUE`
3. **Campo `name` no topo:** Pode causar erro de YAML

## Correções Necessárias:

### 1. Editar o arquivo:
```bash
cd /root/supabase/docker
nano docker-compose.yml
```

### 2. Correção 1: Imagem do auth (linha ~115)
**DE:**
```yaml
    image: supabase/go"true":v2.180.0
```

**PARA:**
```yaml
    image: supabase/gotrue:v2.180.0
```

### 3. Correção 2: Comentários (várias linhas)
Procure e substitua todas as ocorrências de `GO"true"` por `GOTRUE`:

**DE:**
```yaml
      # GO"true"_EXTERNAL_SKIP_NONCE_CHECK: "true"
      # GO"true"_MAILER_SECURE_EMAIL_CHANGE_ENABLED: "true"
      # GO"true"_SMTP_MAX_FREQUENCY: 1s
      # GO"true"_HOOK_CUSTOM_ACCESS_TOKEN_ENABLED: "true"
```

**PARA:**
```yaml
      # GOTRUE_EXTERNAL_SKIP_NONCE_CHECK: "true"
      # GOTRUE_MAILER_SECURE_EMAIL_CHANGE_ENABLED: "true"
      # GOTRUE_SMTP_MAX_FREQUENCY: 1s
      # GOTRUE_HOOK_CUSTOM_ACCESS_TOKEN_ENABLED: "true"
```

### 4. Correção 3: Campo `name` (linha 7)
**DE:**
```yaml
name: supabase
```

**PARA:**
```yaml
# name: supabase  # Comentar ou remover
```

Ou simplesmente **remover a linha**.

### 5. Salvar:
- `Ctrl + O`, `Enter`, `Ctrl + X`

### 6. Validar:
```bash
docker-compose config > /dev/null 2>&1 && echo "✅ Válido!" || echo "❌ Ainda há erros"
```

### 7. Recriar o container:
```bash
docker-compose up -d supabase-auth
```

### 8. Verificar:
```bash
docker ps | grep supabase-auth
docker exec supabase-auth env | grep -i "MAILER_AUTOCONFIRM"
```

**Execute as correções e me mostre o resultado!**






