## Geoeventos (Queimadas / Raios) – Guia Rápido

### Variáveis de ambiente (Node)
- `QUEIMADAS_URL` (opcional, default INPE API focos BR)
- `RAIOS_URL` (opcional; se vazio, só ingestão manual via upload)
- `GEO_JOB_TOKEN` (token Bearer para `/jobs/run`, `/trechos/:id/refresh-alertas`, `/trechos/:id/notify`, `/eventos/raios/upload`)
- `GEO_CRON_EXPR` (default `15 * * * *` – hora em +15min)
- `GEO_BUFFER_M` (default 50m para ST_DWithin)
- `GEO_WINDOW_DAYS` (default 7)
- `GEO_RAIOS_WINDOW_DAYS` (default 1)
- `APP_TRECHO_DEEPLINK` (ex: `https://app.taskflow.com/trechos/{id}`)
- `SUPABASE_URL_INTERNAL`, `SUPABASE_SERVICE_KEY`, `DB_HOST/PORT/NAME/USER/PASSWORD` (já usados pelo webhook)

### Tabelas/funcões criadas (migration `20260131_geoeventos_inpe.sql`)
- `eventos_queimadas`, `eventos_raios` (geom geography, hash dedup, índices GIST + data_hora)
- `trechos_geoms` (LineString 4326 com buffer_m; ref_type/ref_id para mapear tasks/trechos)
- `eventos_agregados_trecho` (agregados por trecho+tipo+janela)
- Funções: `upsert_evento_queimada`, `upsert_evento_raio`, `refresh_eventos_agregados_trecho`

### Endpoints novos (servidor generalized)
- `POST /jobs/run` (Bearer `GEO_JOB_TOKEN`) – roda ingestão (queimadas/raios), refresh agregados (1/7/30d) e notifica Telegram.
- `GET /eventos/queimadas?bbox=&start=&end=&limit=&offset=`
- `GET /eventos/raios?bbox=&start=&end=&limit=&offset=`
- `GET /trechos/:id/alertas?refId=` – retorna agregados de um trecho (aceita refId=taskId).
- `POST /trechos/:id/refresh-alertas` (token) – recalcula agregados.
- `POST /trechos/:id/notify` (token) – força notificação Telegram com anti-spam (usa last_notified_at).
- `POST /eventos/raios/upload` (token) – ingestão manual a partir de JSON `{items:[{lat,lon,data_hora,...}]}`.

### Cron
- Definido em `telegram-webhook-server-generalized.js` com `GEO_CRON_EXPR`; executa ingestão, refresh e notificações pendentes.

### Uso no Flutter
- Mapa (`linhas_transmissao_view.dart`): toggles “🔥 Queimadas” e “⚡ Raios” consomem os GETs acima e exibem markers.
- Cards de tarefas (`task_cards_view.dart`): badges “🔥 7d/30d” e “⚡ 24h/7d” carregam agregados via `/trechos/{taskId}/alertas?refId=taskId`.

### Testes rápidos
1) Rodar migration (local ou supabase CLI): `psql -d postgres -f supabase/migrations/20260131_geoeventos_inpe.sql`.
2) Inserir trecho geom (exemplo): `INSERT INTO trechos_geoms(ref_type, ref_id, nome, geom) VALUES ('TASK', '<task_uuid>', 'Trecho teste', ST_GeomFromText('LINESTRING(-48 -15, -47.9 -15)', 4326));`
3) Chamar `/jobs/run` com Bearer `GEO_JOB_TOKEN`.
4) Verificar eventos: `/eventos/queimadas?limit=10`.
5) Verificar agregados: `/trechos/<trechos_geoms.id>/alertas` ou com `refId=<task_uuid>`.
6) Forçar notificação: `/trechos/<id>/notify` (token).

### Observações
- Não expor `SUPABASE_SERVICE_KEY` no Flutter; apenas GETs públicos são usados no app.
- Anti-spam: notifica somente quando `ultimo_evento > last_notified_at` para cada tipo/trecho.
- Se não houver feed público de raios, use o upload manual e mantenha os hashes de dedup.
