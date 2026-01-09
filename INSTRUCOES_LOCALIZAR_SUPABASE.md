# 🔍 Como Localizar o Supabase no Servidor VPS

Execute os comandos abaixo no terminal do servidor para encontrar onde o Supabase está instalado.

## Opção 1: Script Automático (Recomendado)

1. **Copie o conteúdo do arquivo `localizar_supabase.sh`** para o servidor
2. **Execute o script:**
```bash
chmod +x localizar_supabase.sh
./localizar_supabase.sh
```

## Opção 2: Comandos Manuais

Execute estes comandos um por um:

### 1. Verificar containers Docker
```bash
docker ps -a | grep -i supabase
```

### 2. Procurar docker-compose.yml
```bash
find /opt /home /root -name "docker-compose.yml" 2>/dev/null
```

### 3. Procurar diretórios do Supabase
```bash
ls -la /opt/ | grep -i supabase
ls -la /home/ | grep -i supabase
ls -la /root/ | grep -i supabase
```

### 4. Procurar arquivos .env
```bash
find /opt /home /root -name ".env" 2>/dev/null | head -10
```

### 5. Verificar processos em execução
```bash
ps aux | grep -i supabase
```

### 6. Verificar portas (Supabase usa 54321, 54322, etc.)
```bash
netstat -tulpn | grep -E "54321|54322|54323"
# ou
ss -tulpn | grep -E "54321|54322|54323"
```

## Opção 3: Se estiver usando Docker Compose

Se encontrar um `docker-compose.yml`, veja onde está:

```bash
# Exemplo: se estiver em /opt/supabase
cd /opt/supabase
ls -la
cat docker-compose.yml | grep -A 5 -B 5 "ENABLE_EMAIL"
```

## Opção 4: Verificar variáveis de ambiente dos containers

```bash
# Listar containers
docker ps

# Ver variáveis de ambiente de um container específico
docker exec <nome_do_container> env | grep -i auth
docker exec <nome_do_container> env | grep -i email
```

## O que procurar:

1. **Arquivo `.env`** - Geralmente na mesma pasta do `docker-compose.yml`
2. **Arquivo `config.toml`** - Se usar Supabase CLI
3. **Variáveis de ambiente no docker-compose.yml**
4. **Diretório `/opt/supabase`** ou similar

## Depois de encontrar:

1. **Se for Docker Compose:**
   - Edite o arquivo `.env` ou `docker-compose.yml`
   - Adicione: `ENABLE_EMAIL_CONFIRMATION=false`
   - Reinicie: `docker-compose restart` ou `docker-compose down && docker-compose up -d`

2. **Se for instalação direta:**
   - Edite o arquivo de configuração encontrado
   - Reinicie o serviço

Execute os comandos e me mostre o resultado!






