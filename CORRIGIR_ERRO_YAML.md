# 🔧 Corrigir Erro YAML no docker-compose.yml

## Erro Identificado:
- **Linha 115, coluna 7:** Esperava fim de bloco, mas encontrou escalar
- **Linha 134, coluna 38:** Contexto adicional

## Solução:

### 1. Ver as linhas problemáticas:
```bash
cd /root/supabase/docker
sed -n '110,120p' docker-compose.yml
sed -n '130,140p' docker-compose.yml
```

### 2. Abrir o arquivo e ir para a linha 115:
```bash
nano docker-compose.yml
```

No nano:
- Pressione `Ctrl + _` (ir para linha)
- Digite `115` e pressione `Enter`

### 3. Verificar problemas comuns:

#### Problema 1: Indentação incorreta
Certifique-se de que a indentação está correta (espaços, não tabs).

#### Problema 2: Dois pontos faltando ou extras
Verifique se há `:` após as chaves e se não há `:` extras.

#### Problema 3: Aspas não fechadas
Se você adicionou aspas, certifique-se de que todas estão fechadas.

#### Problema 4: Lista mal formatada
Se for uma lista (com `-`), certifique-se de que está formatada corretamente.

### 4. Exemplo de estrutura correta:

```yaml
environment:
  - GOTRUE_MAILER_AUTOCONFIRM: "true"
  - OUTRA_VAR: "valor"
```

ou

```yaml
environment:
  GOTRUE_MAILER_AUTOCONFIRM: "true"
  OUTRA_VAR: "valor"
```

### 5. Se não conseguir identificar, restaure o backup:

```bash
cd /root/supabase/docker
ls -la docker-compose.yml.backup*
# Use o backup mais recente
cp docker-compose.yml.backup.* docker-compose.yml
```

Depois edite apenas a linha do `GOTRUE_MAILER_AUTOCONFIRM` manualmente.

### 6. Validar após corrigir:
```bash
docker-compose config
```

**Execute os comandos para ver as linhas problemáticas e me mostre o resultado!**






