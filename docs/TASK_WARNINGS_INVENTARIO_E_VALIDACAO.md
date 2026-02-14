# Task Warnings — Inventário e Validação

## 1) Inventário do schema (fontes usadas)

| Uso | Fonte | Observação |
|-----|--------|------------|
| **Tasks (id, status, datas)** | `public.tasks` | Colunas: `id`, `status`, `data_inicio`, `data_fim`, `updated_at`, `coordenador`. A migration garante `regional_id`, `divisao_id`, `segmento_id` (ADD COLUMN IF NOT EXISTS). |
| **Vínculo executor ↔ tarefa** | `public.tasks_executores` (task_id, executor_id), `public.executor_periods` (task_id, executor_id, data_inicio, data_fim) | Usado na RPC para “usuário é executor vinculado”. |
| **Coordenador** | `public.tasks.coordenador` (texto) | Comparado com `usuarios.nome` na RPC para “usuário é coordenador”. |
| **Perfil do usuário (gerente)** | `public.usuarios` (id, nome, email, is_root), `public.usuarios_regionais` (usuario_id, regional_id), `public.usuarios_divisoes` (usuario_id, divisao_id), `public.usuarios_segmentos` (usuario_id, segmento_id) | Usado na RPC para filtrar por escopo regional + divisão + segmento. |
| **Pendências SAP (W2)** | `public.tasks_conc_encerramento_sap` | View existente: `task_id`, `qtd_notas_nao_encerradas`, `qtd_ordens_nao_encerradas`, `qtd_ats_nao_encerradas`, `tem_algum_nao_encerrado`. Reutilizada para W2. |
| **Identificação do usuário** | `auth.uid()` | Na RPC assume-se `usuarios.id = auth.uid()` (ou vínculo equivalente). |

## 2) Onde está a migration

- **Arquivo:** `supabase/migrations/20260222_task_warnings.sql`
- **Conteúdo:** VIEW base `v_task_warnings_base`, função `get_task_warnings_for_user()`, índices recomendados, comentários de validação.

## 3) Regras implementadas (extensível para W3, W4…)

- **W1 — Status atrasado/indevido:** `CURRENT_DATE > date(data_fim)` e `status IN ('PROG','ANDA')` → message + fix_hint conforme spec.
- **W2 — CONC sem SAP encerrado:** `tasks_conc_encerramento_sap.tem_algum_nao_encerrado = TRUE` → message + fix_hint; `details_json` com quantidades.

Para novas regras: criar `wN_candidates` (SELECT com task_id, warning_code, severity, message, fix_hint, details_json, created_at, task_updated_at, regional_id, divisao_id, segmento_id) e adicionar `UNION ALL SELECT ... FROM wN_candidates` em `all_warnings`.

## 4) Exemplos de consulta

```sql
-- Base (todos os warnings, sem filtro de usuário)
SELECT * FROM public.v_task_warnings_base ORDER BY severity DESC, task_id LIMIT 50;

-- Por usuário (requer auth; usar no app com sessão Supabase)
SELECT * FROM public.get_task_warnings_for_user() ORDER BY severity DESC, task_id LIMIT 50;
```

## 5) Testes sugeridos

| Caso | Como validar |
|------|-----------------------------|
| Tarefa atrasada PROG/ANDA | Task com `data_fim` &lt; hoje e `status` PROG ou ANDA → deve aparecer W1. |
| Tarefa CONC com SAP pendente | Task CONC com nota/ordem/AT vinculado e `status_sistema` sem ENTE/ENCE/MSEN → deve aparecer W2. |
| Usuário executor vê só suas tarefas | Usuário com `executores.login = usuarios.email` (ou `executores.usuario_id = usuarios.id`) → só warnings de tarefas em que é executor ou coordenador. |
| Gerente vê tarefas do escopo | Usuário com linhas em `usuarios_regionais`, `usuarios_divisoes`, `usuarios_segmentos` → warnings de tasks cujo (regional_id, divisao_id, segmento_id) batem com o perfil. |

## 6) Visibilidade na RPC

- **Root** (`usuarios.is_root = true`): todos os registros de `v_task_warnings_base`.
- **Gerente** (tem perfil em usuarios_regionais/divisoes/segmentos): tarefas em que `tasks.regional_id` / `divisao_id` / `segmento_id` batem com o perfil (e task.segmento_id pode ser NULL).
- **Demais:** apenas tarefas em que o usuário é executor (via `tasks_executores` ou `executor_periods` e vínculo executores ↔ usuarios por `login` ou `usuario_id`) ou coordenador (`tasks.coordenador = usuarios.nome`).

## 7) Performance

- Uso de `EXISTS` na RPC em vez de joins pesados onde basta existência.
- Índices criados/garantidos: `tasks(status)`, `tasks(data_fim)`, `tasks(regional_id, divisao_id, segmento_id)`, `tasks_executores(executor_id)`, `executor_periods(task_id)`.
