# 🔍 Verificar Configuração do Supabase Auth

## Problema:
Mesmo com `ENABLE_EMAIL_AUTOCONFIRM=true`, o erro persiste. Precisamos verificar se a variável está sendo lida corretamente.

## Comandos para Executar no Servidor:

### 1. Verificar variáveis de ambiente do container:
```bash
docker exec supabase-auth env | grep -i "EMAIL\|AUTOCONFIRM\|MAILER"
```

### 2. Verificar o arquivo .env novamente:
```bash
cd /root/supabase/docker
grep -i "EMAIL_AUTOCONFIRM\|MAILER_AUTOCONFIRM" .env
```

### 3. Verificar docker-compose.yml:
```bash
cd /root/supabase/docker
grep -A 10 "supabase-auth" docker-compose.yml | grep -i "EMAIL\|AUTOCONFIRM\|MAILER"
```

### 4. Verificar se há variáveis sendo sobrescritas:
```bash
cd /root/supabase/docker
cat docker-compose.yml | grep -B 5 -A 15 "supabase-auth"
```

## Possíveis Problemas:

1. **Variável errada:** O GoTrue pode usar `GOTRUE_MAILER_AUTOCONFIRM` ao invés de `ENABLE_EMAIL_AUTOCONFIRM`
2. **Variável no docker-compose.yml:** Pode estar sendo definida diretamente no docker-compose.yml, sobrescrevendo o .env
3. **Container não está lendo o .env:** Pode precisar recriar o container ao invés de apenas reiniciar

## Solução Alternativa:

Se não conseguir configurar via .env, podemos:
1. Editar diretamente no docker-compose.yml
2. Ou usar a API Admin para confirmar emails automaticamente

**Execute os comandos acima e me mostre o resultado!**






