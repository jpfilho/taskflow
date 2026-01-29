# Instalação do N8N no Servidor

Este guia explica como instalar o N8N (ferramenta de automação de workflows) no servidor `212.85.0.249`.

## Pré-requisitos

- Acesso SSH ao servidor (212.85.0.249)
- Permissões de root ou sudo
- Docker instalado (o script instala automaticamente se não estiver)

## Opção 1: Instalação via Script PowerShell (Windows)

Execute o script PowerShell:

```powershell
.\instalar_n8n.ps1
```

## Opção 2: Instalação via Script Bash (Linux/Mac ou direto no servidor)

1. Copie o script para o servidor:
```bash
scp instalar_n8n.sh root@212.85.0.249:/tmp/
```

2. Execute no servidor:
```bash
ssh root@212.85.0.249
chmod +x /tmp/instalar_n8n.sh
/tmp/instalar_n8n.sh
```

## O que o script faz

1. ✅ Verifica e instala Docker (se necessário)
2. ✅ Cria diretório para dados do N8N (`/opt/n8n`)
3. ✅ Remove containers antigos (se existirem)
4. ✅ Instala N8N via Docker na porta 5678
5. ✅ Configura autenticação básica
6. ✅ Verifica se o serviço está rodando

## Acesso ao N8N

Após a instalação, acesse:

- **URL**: http://212.85.0.249:5678
- **Usuário**: `admin`
- **Senha**: `n8n_admin_2026`

⚠️ **IMPORTANTE**: Altere a senha padrão após o primeiro acesso!

## Configuração Opcional: Nginx como Proxy Reverso

Para acessar o N8N via Nginx (recomendado para produção):

```powershell
.\configurar_nginx_n8n.ps1
```

Isso configurará o Nginx para fazer proxy reverso do N8N.

## Comandos Úteis

### Ver logs do N8N
```bash
ssh root@212.85.0.249 'docker logs n8n'
```

### Parar o N8N
```bash
ssh root@212.85.0.249 'docker stop n8n'
```

### Iniciar o N8N
```bash
ssh root@212.85.0.249 'docker start n8n'
```

### Reiniciar o N8N
```bash
ssh root@212.85.0.249 'docker restart n8n'
```

### Ver status
```bash
ssh root@212.85.0.249 'docker ps | grep n8n'
```

### Acessar shell do container
```bash
ssh root@212.85.0.249 'docker exec -it n8n sh'
```

## Localização dos Dados

Os dados do N8N (workflows, credenciais, etc.) são salvos em:
- **Diretório**: `/opt/n8n`
- **Backup**: Faça backup regular deste diretório

## Backup

Para fazer backup dos dados:

```bash
ssh root@212.85.0.249 'tar -czf n8n_backup_$(date +%Y%m%d).tar.gz /opt/n8n'
```

## Restauração

Para restaurar de um backup:

```bash
# Parar o N8N
ssh root@212.85.0.249 'docker stop n8n'

# Restaurar dados
scp n8n_backup_YYYYMMDD.tar.gz root@212.85.0.249:/tmp/
ssh root@212.85.0.249 'cd /opt && tar -xzf /tmp/n8n_backup_YYYYMMDD.tar.gz'

# Reiniciar o N8N
ssh root@212.85.0.249 'docker start n8n'
```

## Atualização

Para atualizar o N8N para a versão mais recente:

```bash
ssh root@212.85.0.249 @"
    docker stop n8n
    docker rm n8n
    docker pull n8nio/n8n:latest
    docker run -d \
        --name n8n \
        --restart unless-stopped \
        -p 5678:5678 \
        -v /opt/n8n:/home/node/.n8n \
        -e N8N_BASIC_AUTH_ACTIVE=true \
        -e N8N_BASIC_AUTH_USER=admin \
        -e N8N_BASIC_AUTH_PASSWORD=n8n_admin_2026 \
        -e N8N_HOST=212.85.0.249 \
        -e N8N_PORT=5678 \
        -e N8N_PROTOCOL=http \
        -e WEBHOOK_URL=http://212.85.0.249:5678/ \
        n8nio/n8n:latest
"@
```

## Segurança

1. **Altere a senha padrão** após o primeiro acesso
2. **Configure HTTPS** usando Let's Encrypt (recomendado)
3. **Restrinja o acesso** via firewall se necessário
4. **Faça backups regulares** dos dados

## Troubleshooting

### N8N não inicia
```bash
# Ver logs detalhados
ssh root@212.85.0.249 'docker logs n8n --tail 100'

# Verificar se a porta está em uso
ssh root@212.85.0.249 'netstat -tulpn | grep 5678'
```

### Erro de permissão
```bash
# Ajustar permissões do diretório
ssh root@212.85.0.249 'chown -R 1000:1000 /opt/n8n'
```

### Container para de funcionar
```bash
# Verificar status
ssh root@212.85.0.249 'docker ps -a | grep n8n'

# Reiniciar
ssh root@212.85.0.249 'docker restart n8n'
```

## Recursos

- [Documentação oficial do N8N](https://docs.n8n.io/)
- [Docker Hub - N8N](https://hub.docker.com/r/n8nio/n8n)
- [Comunidade N8N](https://community.n8n.io/)
