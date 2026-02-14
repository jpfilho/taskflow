# Como é feito o cálculo das Horas Programadas

## Onde o valor aparece

- **Tela Metas de Horas**: coluna "Prog" e barra de horas programadas por empregado/mês.
- **Fonte no app**: o número vem da view `horas_programadas_por_empregado_mes` no Supabase (coluna usada: **`total_trabalho_planejado`**).

---

## Fluxo no aplicativo (Dart)

1. **`HoraSAPService.getHorasPorEmpregadoMes()`**  
   - Monta a lista de empregados/meses com horas apontadas e metas.  
   - Chama **`_buscarHorasProgramadas(ano, mes, matriculasFiltro)`** para obter as horas programadas.

2. **`_buscarHorasProgramadas()`** (`lib/services/hora_sap_service.dart`)  
   - Consulta a view **`horas_programadas_por_empregado_mes`**:
     - **Colunas**: `matricula`, `mes_ref`, `total_trabalho_planejado`
     - **Filtros**: `mes_ref` (data) para o mês/ano desejado e lista de matrículas do perfil.
   - Monta um mapa: `matricula -> (ano_mes -> total_trabalho_planejado)`.
   - Esse valor é exposto como **horas programadas** por empregado e mês.

3. **Uso no modelo**  
   - Em **`HorasEmpregadoMes`** o campo **`horasProgramadas`** recebe exatamente o `total_trabalho_planejado` da view para aquele empregado e aquele mês (ex.: jan/2026).

Ou seja: **o app não calcula horas programadas; só lê o que já vem da view e usa como “Prog” na tela.**

---

## Onde o cálculo é feito: VIEW dinâmica (banco de dados)

A migration **`20260228_horas_programadas_view_dinamica.sql`** define a VIEW **`horas_programadas_por_empregado_mes`** de forma dinâmica (sem MV), para os dados ficarem sempre atualizados. **Fórmula:** dias distintos com atividade no mês × 8h (excl. FER). Colunas: `matricula`, `ano`, `mes`, `mes_ref`, `ano_mes`, `horas_programadas`, `total_trabalho_planejado`.

*(Antes a view podia usar a MV estática; abaixo a referência à MV foi removida.)*

```sql
create view public.horas_programadas_por_empregado_mes as
select
  horas_programadas_por_empregado_mes_mv.matricula,
  horas_programadas_por_empregado_mes_mv.nome_empregado,
  horas_programadas_por_empregado_mes_mv.centro_trabalho_real,
  horas_programadas_por_empregado_mes_mv.mes_ref,
  horas_programadas_por_empregado_mes_mv.total_trabalho_planejado,
  horas_programadas_por_empregado_mes_mv.total_trabalho_real,
  horas_programadas_por_empregado_mes_mv.total_trabalho_restante,
  horas_programadas_por_empregado_mes_mv.qtde_registros
from
  horas_programadas_por_empregado_mes_mv;
```

Portanto, **o cálculo real está na definição da MV `horas_programadas_por_empregado_mes_mv`** (no Supabase/Postgres). O que você vê de “horas programadas” para janeiro/2026 é o valor de **`total_trabalho_planejado`** retornado por essa MV para cada (matrícula, `mes_ref`).

Para saber exatamente como está sendo calculado (soma de planejado de tarefas, dias × 8h, outra regra, etc.), é necessário olhar a definição dessa MV no banco (DDL da materialized view).

---

## Referência: lógica que existia no repositório (view antiga)

No projeto existe uma migration (**`supabase/migrations/20260216_horas_programadas_max_8h_por_dia.sql`**) que define outra versão da view, **sem usar a MV**. Essa versão não é a que está rodando no seu banco hoje, mas documenta uma lógica possível de “horas programadas”:

- **Fonte**: períodos de execução em tarefas (`executor_periods`) + `tasks` + `executores`.
- **Regra**:
  - Para cada (executor, mês): considera a interseção do período da tarefa com o mês.
  - Conta **dias distintos** em que o empregado teve atividade nesse mês.
  - **Horas programadas = dias distintos × 8h** (máximo 8h por dia, mesmo com várias atividades no mesmo dia).
  - **Exclusão**: períodos do tipo **FER (férias)** não entram no cálculo.

Resumo da fórmula dessa versão:

```text
horas_programadas = COUNT(DISTINCT dia) * 8.0
```

em que `dia` são os dias do mês cobertos por `executor_periods` (excluindo FER).

---

## Resumo

| O quê | Onde |
|------|------|
| Valor exibido como “Prog” (ex.: jan/2026) | `total_trabalho_planejado` da view `horas_programadas_por_empregado_mes` |
| Quem calcula | VIEW dinâmica (dias distintos × 8h, excl. FER) – migration 20260228 `horas_programadas_por_empregado_mes_mv` no banco |
| O que o app faz | Só consulta a view, monta o mapa por matrícula/mês e preenche `HorasEmpregadoMes.horasProgramadas` |

Para documentar ou auditar o cálculo que está sendo “realmente” usado (incluindo jan/2026), é necessário inspecionar a definição da **materialized view `horas_programadas_por_empregado_mes_mv`** no Supabase (SQL da MV).
