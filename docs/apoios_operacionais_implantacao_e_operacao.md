# TaskFlow — Apoios Operacionais: Implantação, Segurança, Backup, Rollback e Operação

## 1. Separação DEV vs Produção
- **DEV**: VPS externa (`212.85.0.249`), banco próprio, dados sintéticos/homologação.
- **Produção**: Servidor corporativo (`10.140.50.12`), porta Web **8085** (`--base-href "/"`), banco próprio.
- **Regra**: Nunca transportar dump completo do DEV para produção. Transportar apenas código via Git, migrations SQL versionadas e variáveis de ambiente parametrizadas (`backend/.env.example`).

---

## 2. Migrations (Ordem Obrigatória de Execução)
1. `supabase/migrations/20261117_apoios_operacionais_fase2.sql`
2. `supabase/migrations/20261117_apoios_operacionais_fase3_ajustes.sql`
3. `supabase/migrations/20261117_apoios_notificacoes_fase6.sql`
4. `supabase/migrations/20261118_apoios_fase7_monitoramento_indicadores.sql`
5. `supabase/migrations/20261118_apoios_fase8_hardening.sql`

> Todas usam `IF NOT EXISTS` / `CREATE OR REPLACE` ou blocos `DO $$` idempotentes. Não colocar scripts destrutivos de rollback na pasta `supabase/migrations/`.

---

## 3. Comunicação Segura (HTTPS) & Microsoft Entra ID

### 3.1 HTTPS / Nginx
- Em DEV (`212.85.0.249`), o certificado Let's Encrypt de `api.taskflowv3.com.br` expirou em `24/04/2026` e a porta `3001` está exposta diretamente.
- **Providência obrigatória antes da liberação externa**:
  1. Renovar certificado TLS válido (Certbot/ACME ou CA corporativa em produção).
  2. Adicionar no Nginx (`server` 443) os blocos `location /api/apoios/` e `location /auth/` fazendo `proxy_pass http://127.0.0.1:3001;`.
  3. Bloquear acesso externo direto à porta `3001` no firewall (`ufw`/`iptables`), mantendo apenas `127.0.0.1:3001`.
  4. Rotacionar `APOIOS_GATEWAY_SECRET`, `TELEGRAM_BOT_TOKEN` e `SUPABASE_SERVICE_KEY` caso tenham trafegado em HTTP não confiável.

### 3.2 Procedimento Corporativo — Microsoft Entra ID
- **Local**: Portal Azure (`entra.microsoft.com`) -> *App Registrations* -> registro `taskflow` (`clientId: 90414d95-ac9b-4b95-9fc2-ebf677253e99`, `tenantId: 8a0ffb54-9716-4a93-9158-9e3a7206f18e`).
- **Configuração pela equipe corporativa**:
  1. Em *Expose an API*, definir *Application ID URI* (ex.: `api://90414d95-ac9b-4b95-9fc2-ebf677253e99`).
  2. Criar escopo `access_as_user` (*Admins and users*).
  3. Em *API permissions*, conceder ao próprio app a permissão delegada `access_as_user`.
  4. Conferir *Redirect URIs*: `com.taskflow.app://auth` (Mobile/Desktop) e URL raiz de produção Web (porta `8085`).
  5. Configurar `APOIOS_ENTRA_API_AUDIENCE=api://90414d95-ac9b-4b95-9fc2-ebf677253e99` no `.env` do backend.
- **No aplicativo Flutter**: atualizar `scopes` em `AzureAuthService` para incluir `api://90414d95-ac9b-4b95-9fc2-ebf677253e99/access_as_user` e enviar o `accessToken` para `POST /auth/apoios-entra-exchange`.
- Enquanto `APOIOS_ENTRA_API_AUDIENCE` não estiver definido, `/auth/apoios-entra-exchange` responde `503 ENTRA_NOT_CONFIGURED` (fail-closed) e rejeita tokens do Microsoft Graph (`00000003-...`).

---

## 4. Procedimento de Backup e Implantação em Produção (8 Etapas)

### Etapa 1 — Diagnóstico (somente leitura no servidor corporativo)
```bash
git status && git log -n 3 --oneline
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
systemctl status telegram-webhook --no-pager || true
ss -tlnp | grep -E '80|443|3001|8000|8085'
df -h
```

### Etapa 2 — Backup Prévio
```bash
mkdir -p /root/backups/taskflow_pre_apoios_$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/root/backups/taskflow_pre_apoios_$(date +%Y%m%d_%H%M%S)
# Ajustar nome do container PostgreSQL conforme Etapa 1:
docker exec -t <CONTAINER_POSTGRES> pg_dump -U postgres -d postgres -Fc > "$BACKUP_DIR/postgres.dump"
pg_restore --list "$BACKUP_DIR/postgres.dump" | head -n 20
cp -a /var/www/html/task2026 "$BACKUP_DIR/web_atual" 2>/dev/null || true
cp -a /etc/nginx/sites-available "$BACKUP_DIR/nginx_sites"
cp -a /root/telegram-webhook "$BACKUP_DIR/backend_atual" 2>/dev/null || true
```

### Etapa 3 — Atualização via Git
```bash
git fetch origin
git checkout <BRANCH_OU_TAG_RELEASE>
git pull --ff-only
```

### Etapa 4 — Aplicação Controlada das Migrations
Aplicar na ordem da Seção 2 no container PostgreSQL de produção e validar tabelas/views/triggers:
```bash
for f in \
  supabase/migrations/20261117_apoios_operacionais_fase2.sql \
  supabase/migrations/20261117_apoios_operacionais_fase3_ajustes.sql \
  supabase/migrations/20261117_apoios_notificacoes_fase6.sql \
  supabase/migrations/20261118_apoios_fase7_monitoramento_indicadores.sql \
  supabase/migrations/20261118_apoios_fase8_hardening.sql; do
  docker exec -i <CONTAINER_POSTGRES> psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$f"
done
```

### Etapa 5 — Backend Node.js + Variáveis
1. Copiar `backend/apoios_gateway.js` e `backend/apoios_notificacoes_worker.js` para o diretório do serviço Node.js.
2. Configurar variáveis de `backend/.env.example` (especialmente `APOIOS_GATEWAY_SECRET` gerado com `openssl rand -hex 32`).
3. Validar sintaxe (`node -c apoios_gateway.js`), reiniciar o serviço e checar `GET /api/apoios/me` sem token (deve retornar `401 AUTH_REQUIRED`).

### Etapa 6 — Build e Publicação Flutter Web (Porta 8085, Raiz `/`)
```bash
flutter build web --release --base-href "/" --dart-define=ENVIRONMENT=prod
```
Publicar o conteúdo de `build/web/` no diretório servido pela porta **8085** no Nginx, preservando as configurações existentes.

### Etapa 7 e 8 — Validação e Liberação
Validar login, criação de atividade sem apoio, fluxo completo de apoio entre duas divisões, notificações, Gantt Integrado, painel gerencial, exportação `.xlsx` e isolamento de terceira divisão.

---

## 5. Estratégia de Rollback
- **Antes de uso operacional**: restaurar `web_atual`, `backend_atual` e `nginx_sites` do `$BACKUP_DIR`; as tabelas `tasks_apoios_*` podem permanecer vazias sem afetar o módulo de Atividades. **Nunca** executar `DROP TABLE ... CASCADE` em produção.
- **Após uso operacional**: restaurar apenas código Web/Node anterior (preservando os registros de `tasks_apoios_*` e `tasks_apoios_historico`); pausar o worker de notificações para não disparar alertas duplicados enquanto a UI estiver desativada.

---

## 6. Guia Rápido de Operação
- **Unidade Solicitante**: Na atividade principal, abra a seção *Apoios Operacionais* -> *Solicitar apoio* -> escolha tipo, unidade prestadora, criticidade e período necessário -> acompanhe na *Central de Apoios* (aba *Enviadas*).
- **Unidade Prestadora**: Na *Central de Apoios* (aba *Recebidas*), clique em *Iniciar análise*, *Aceitar* ou *Contrapropor*; após aceitar, crie a atividade de apoio ou vincule uma existente e confirme o vínculo.
- **Gestores**: Utilize a aba *Gestão & Reunião* e o *Gantt Integrado* para identificar lacunas, apoios essenciais em risco e exportar o relatório `.xlsx`. **Importante**: *Aceite*, *Programação* e *Atendimento efetivo* são estágios distintos e não substituem os procedimentos de segurança operacional.

