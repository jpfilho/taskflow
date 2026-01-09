# 🚀 Comandos para Deploy Manual

Como o acesso SSH requer senha, execute estes comandos manualmente:

## Passo 1: Criar o diretório no servidor

```bash
ssh root@212.85.0.249
# Digite a senha quando solicitado

# Depois de conectar, execute:
mkdir -p /var/www/html/task2026
chmod 755 /var/www/html/task2026
exit
```

## Passo 2: Fazer upload dos arquivos

```bash
# Do seu computador local, execute:
scp -r build/web/* root@212.85.0.249:/var/www/html/task2026/
# Digite a senha quando solicitado
```

## Passo 3: Ajustar permissões (se necessário)

```bash
ssh root@212.85.0.249
chown -R www-data:www-data /var/www/html/task2026
chmod -R 755 /var/www/html/task2026
exit
```

## Alternativa: Usar rsync (mais eficiente)

```bash
rsync -avz --progress --delete \
    build/web/ \
    root@212.85.0.249:/var/www/html/task2026/
```

## Verificar se funcionou

Acesse no navegador:
- `http://212.85.0.249/task2026/`
- Ou seu domínio configurado

## Dica: Configurar chave SSH (para não precisar digitar senha)

```bash
# Gerar chave (se ainda não tiver)
ssh-keygen -t ed25519

# Copiar chave para o servidor
ssh-copy-id root@212.85.0.249
```

Depois disso, você não precisará mais digitar a senha!
