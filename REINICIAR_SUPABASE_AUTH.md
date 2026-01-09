# 🔄 Reiniciar Container supabase-auth

## Problema:
O comando `docker-compose` não foi encontrado. Vamos usar o comando `docker compose` (sem hífen) ou `docker restart` diretamente.

## Opção 1: Docker Compose (versão nova - sem hífen)

Execute no servidor:

```bash
cd /root/supabase/docker
docker compose restart supabase-auth
```

## Opção 2: Docker restart direto

Se a opção 1 não funcionar:

```bash
docker restart supabase-auth
```

## Opção 3: Parar e iniciar novamente

```bash
docker stop supabase-auth
docker start supabase-auth
```

## Verificar se funcionou:

```bash
# Ver status do container
docker ps | grep supabase-auth

# Ver logs recentes
docker logs supabase-auth --tail 20

# Verificar se a configuração foi aplicada
docker exec supabase-auth env | grep -i "EMAIL_AUTOCONFIRM\|MAILER_AUTOCONFIRM"
```

## Resultado esperado:

Após reiniciar, os logs não devem mais mostrar:
- ❌ "Error sending confirmation email"
- ❌ "dial tcp: lookup supabase-mail"

E devem mostrar:
- ✅ Configurações de auto-confirmação ativas
- ✅ Usuários sendo criados sem necessidade de confirmação de email






