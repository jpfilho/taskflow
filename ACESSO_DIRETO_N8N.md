# 🔓 Acesso Direto ao N8N via IP

## 🚨 Situação Atual

Após configurar HTTPS, o N8N está configurado para escutar apenas em `127.0.0.1:5678` (localhost), o que significa:

- ✅ **Funciona**: `https://api.taskflowv3.com.br/n8n` (via Nginx HTTPS)
- ❌ **Não funciona**: `http://212.85.0.249:5678` (acesso direto via IP)

---

## ✅ Habilitar Acesso Direto (Opcional)

Se você precisa do acesso direto via IP (para desenvolvimento/testes), execute:

```bash
ssh root@212.85.0.249
bash habilitar_acesso_direto_n8n.sh
```

Este script irá:
1. Parar o container atual
2. Recriar com `-p 5678:5678` (expõe em todas as interfaces)
3. Manter todas as configurações HTTPS

**Após executar**, o N8N estará acessível em:
- ✅ `https://api.taskflowv3.com.br/n8n` (HTTPS via Nginx)
- ✅ `http://212.85.0.249:5678` (HTTP direto)

---

## ⚠️ Considerações de Segurança

### Acesso Direto Exposto

- **Risco**: O N8N fica acessível diretamente na rede sem HTTPS
- **Recomendação**: Use apenas para desenvolvimento/testes
- **Produção**: Mantenha apenas o acesso via HTTPS (`127.0.0.1:5678`)

### Configuração Atual (Segura)

A configuração atual (`127.0.0.1:5678`) é **mais segura** porque:
- ✅ N8N só aceita conexões do próprio servidor
- ✅ Acesso externo só via HTTPS através do Nginx
- ✅ Nginx pode adicionar autenticação, rate limiting, etc.

---

## 🔧 Verificar Configuração Atual

Para verificar como está configurado:

```bash
ssh root@212.85.0.249
bash verificar_porta_n8n.sh
```

Ou manualmente:

```bash
# Ver mapeamento de porta do container
docker inspect n8n | grep -A 10 "PortBindings"

# Testar acesso local
curl http://127.0.0.1:5678/

# Testar acesso externo
curl http://212.85.0.249:5678/
```

---

## 📝 Resumo

| Configuração | Acesso HTTPS | Acesso HTTP Direto | Segurança |
|--------------|--------------|-------------------|-----------|
| `127.0.0.1:5678` (atual) | ✅ Sim | ❌ Não | 🔒 Alta |
| `5678:5678` (exposto) | ✅ Sim | ✅ Sim | ⚠️ Média |

**Recomendação**: Mantenha `127.0.0.1:5678` e use apenas `https://api.taskflowv3.com.br/n8n` para acesso.

---

**Nota**: O acesso direto via IP não é necessário para o webhook do Telegram funcionar. O webhook usa HTTPS através do Nginx, que está funcionando corretamente.
