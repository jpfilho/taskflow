# 🔧 Corrigir Tipo Boolean no docker-compose.yml

## Problema:
O Docker Compose está reclamando que `true` (boolean) não é válido. Precisa ser uma **string** `"true"`.

## Solução:

### 1. Editar docker-compose.yml:
```bash
cd /root/supabase/docker
nano docker-compose.yml
```

### 2. Localizar a linha:
```yaml
GOTRUE_MAILER_AUTOCONFIRM: true
```

### 3. Alterar para (com aspas):
```yaml
GOTRUE_MAILER_AUTOCONFIRM: "true"
```

**Importante:** Use aspas duplas `"true"` ao invés de `true` sem aspas.

### 4. Verificar outras variáveis booleanas:
Procure por outras linhas com `: true` (sem aspas) e altere para `: "true"`:
- `NEXT_PUBLIC_ENABLE_LOGS: true` → `NEXT_PUBLIC_ENABLE_LOGS: "true"`
- `LOGFLARE_SINGLE_TENANT: true` → `LOGFLARE_SINGLE_TENANT: "true"`
- `SEED_SELF_HOST: true` → `SEED_SELF_HOST: "true"`
- `CLUSTER_POSTGRES: true` → `CLUSTER_POSTGRES: "true"`

### 5. Salvar:
- `Ctrl + O` (salvar)
- `Enter` (confirmar)
- `Ctrl + X` (sair)

### 6. Recriar o container:
```bash
docker-compose up -d supabase-auth
```

### 7. Verificar:
```bash
docker exec supabase-auth env | grep -i "MAILER_AUTOCONFIRM"
```

**Deve mostrar:** `GOTRUE_MAILER_AUTOCONFIRM=true` (o Docker converte a string "true" para true internamente)

## Resumo:
**Mude de:** `GOTRUE_MAILER_AUTOCONFIRM: true`  
**Para:** `GOTRUE_MAILER_AUTOCONFIRM: "true"`






