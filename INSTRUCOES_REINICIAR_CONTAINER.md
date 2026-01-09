# ⚠️ IMPORTANTE: Reiniciar Container do Supabase

## Problema Atual:
O arquivo `.env` foi atualizado com `ENABLE_EMAIL_AUTOCONFIRM=true`, mas o container `supabase-auth` **NÃO FOI REINICIADO**, então a configuração antiga ainda está ativa.

## Solução: Reiniciar o Container

Execute estes comandos **NO SERVIDOR VPS**:

### Opção 1: Docker Compose (sem hífen - versão nova)
```bash
cd /root/supabase/docker
docker compose restart supabase-auth
```

### Opção 2: Docker restart direto
```bash
docker restart supabase-auth
```

### Opção 3: Parar e iniciar
```bash
docker stop supabase-auth
sleep 3
docker start supabase-auth
```

## Verificar se Funcionou:

```bash
# Ver status
docker ps | grep supabase-auth

# Ver logs (deve mostrar a nova configuração)
docker logs supabase-auth --tail 30

# Verificar variáveis de ambiente do container
docker exec supabase-auth env | grep -i "EMAIL_AUTOCONFIRM\|MAILER_AUTOCONFIRM"
```

## Resultado Esperado:

Após reiniciar, os logs devem mostrar:
- ✅ Container iniciado com sucesso
- ✅ Configuração `ENABLE_EMAIL_AUTOCONFIRM=true` ativa
- ❌ Não deve mais tentar enviar emails de confirmação

## Teste no App:

1. Tente criar um novo usuário
2. O erro 500 não deve mais aparecer
3. O usuário deve ser criado e logado automaticamente

## Se Ainda Não Funcionar:

Se após reiniciar ainda der erro, verifique:

```bash
# Ver todas as variáveis de email do container
docker exec supabase-auth env | grep -i mail

# Ver logs completos
docker logs supabase-auth 2>&1 | grep -i "autoconfirm\|email"
```

**Execute o comando de reiniciar e me mostre o resultado!**






