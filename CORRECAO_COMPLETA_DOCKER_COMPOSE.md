# 🔧 Correção Completa do docker-compose.yml

## Problemas Identificados:

1. **Valores booleanos precisam ser strings** - `true` → `"true"`
2. **Campo `name` inválido** - precisa começar com `x-` ou ser removido

## Solução Rápida:

### Opção 1: Script Automático

Execute no servidor:

```bash
cd /root/supabase/docker
nano corrigir_docker_compose.sh
```

Cole o conteúdo do arquivo `corrigir_docker_compose.sh`, depois:

```bash
chmod +x corrigir_docker_compose.sh
./corrigir_docker_compose.sh
```

### Opção 2: Correção Manual

#### 1. Editar docker-compose.yml:
```bash
cd /root/supabase/docker
nano docker-compose.yml
```

#### 2. Procurar e substituir TODAS as ocorrências:

**Use a busca no nano:** `Ctrl + W` para buscar

Procure por `: true` (sem aspas) e substitua por `: "true"` (com aspas)

**Variáveis que precisam ser corrigidas:**
- `GOTRUE_MAILER_AUTOCONFIRM: true` → `GOTRUE_MAILER_AUTOCONFIRM: "true"`
- `NEXT_PUBLIC_ENABLE_LOGS: true` → `NEXT_PUBLIC_ENABLE_LOGS: "true"`
- `LOGFLARE_SINGLE_TENANT: true` → `LOGFLARE_SINGLE_TENANT: "true"`
- `SEED_SELF_HOST: true` → `SEED_SELF_HOST: "true"`
- `CLUSTER_POSTGRES: true` → `CLUSTER_POSTGRES: "true"`

#### 3. Verificar campo `name`:

Se houver uma linha `name:` no topo do arquivo (fora da seção de serviços), comente ou remova:

```yaml
# name: algo  # Comentar esta linha
```

ou simplesmente remova a linha.

#### 4. Salvar:
- `Ctrl + O` (salvar)
- `Enter` (confirmar)
- `Ctrl + X` (sair)

#### 5. Validar:
```bash
docker-compose config
```

Se não mostrar erros, está correto!

#### 6. Recriar o container:
```bash
docker-compose up -d supabase-auth
```

#### 7. Verificar:
```bash
docker exec supabase-auth env | grep -i "MAILER_AUTOCONFIRM"
```

**Deve mostrar:** `GOTRUE_MAILER_AUTOCONFIRM=true`

## Dica:

No nano, você pode usar substituição global:
1. `Ctrl + \` (substituir)
2. Digite `: true` e pressione Enter
3. Digite `: "true"` e pressione Enter
4. Digite `A` (substituir todas)

**Execute e me mostre o resultado!**






