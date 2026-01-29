# Dropdowns que não são multiseleção – lista para conversão

Objetivo: identificar todos os dropdowns nas views que **não** são multiseleção (e, quando for o caso, não têm pesquisa) e que devem ser padronizados para **multiseleção com pesquisa**, como já existe em `ordem_view`, `notas_sap_view`, `ordem_selection_dialog` e `nota_sap_selection_dialog`.

---

## Referência: onde já existe multiseleção com pesquisa

| Arquivo | Componente | Filtros/campos |
|--------|------------|------------------|
| `ordem_view.dart` | `MultiSelectFilterDialog` | Status, Local, Tipo, etc. |
| `notas_sap_view.dart` | `MultiSelectFilterDialog` | Vários filtros |
| `ordem_selection_dialog.dart` | `_buildMultiSelect` + `_showMultiSelectDialog` | Local, Tipo, Ordem, Sala, Status Usuário |
| `nota_sap_selection_dialog.dart` | `_buildMultiSelect` | Tipo, Prioridade, Nota, Sala, Local, Status, Ordem |
| `task_form_dialog.dart` | `DropdownSearch` + dialogs de seleção | Status, Regional, Divisão; Nota/Ordem/AT/SI via dialogs com busca |

---

## 1. Dialogs de seleção – filtros em dropdown único (→ multiseleção + pesquisa)

Estes dialogs usam **DropdownButtonFormField** para filtros (um valor por vez). O padrão desejado é o de `ordem_selection_dialog` e `nota_sap_selection_dialog`: **multiseleção com pesquisa** (`_buildMultiSelect` + `_showMultiSelectDialog`).

| Arquivo | Filtros atuais (dropdown único) | Ação |
|--------|----------------------------------|------|
| **at_selection_dialog.dart** | Status, Tipo, Local (3 dropdowns single) | Trocar por multiseleção com pesquisa (como ordem_selection_dialog). |
| **si_selection_dialog.dart** | Status, Tipo, Local (3 dropdowns single) | Idem. |
| **task_selection_dialog.dart** | Status, Local, Tipo (3 dropdowns single) | Idem. |

---

## 2. Views – filtros em dropdown único (→ multiseleção + pesquisa)

Views que usam **DropdownButtonFormField** apenas para filtro (um valor por vez). O padrão desejado é multiseleção com pesquisa (ex.: `MultiSelectFilterDialog` ou equivalente).

| Arquivo | Filtros atuais (dropdown único) | Ação |
|--------|----------------------------------|------|
| **at_view.dart** | Status, Local, Status Usuário (3 dropdowns). Ano/Mês podem permanecer single. | Status, Local e Status Usuário → multiseleção com pesquisa. ✅ |
| **si_view.dart** | Status, Local, Status Usuário (3 dropdowns) | Idem. ✅ |
| **filter_bar.dart** (tela Atividades) | Regional, Divisão, Status, Local, Tipo, Executor, Frota, Coordenador (8 dropdowns) | Todos → multiseleção com pesquisa. ✅ |

---

## 3. Formulários e outras views – dropdown único sem pesquisa (→ pelo menos pesquisa; multiseleção se fizer sentido)

Estes usam **FloatingLabelDropdown** ou **DropdownButtonFormField** para escolher **uma** entidade (Regional, Divisão, etc.). Para listas longas, o mínimo desejado é **pesquisa** (ex.: `DropdownSearch`). Multiseleção só onde a regra de negócio permitir mais de um valor.

| Arquivo | Campos (dropdown único, sem pesquisa) | Sugestão |
|--------|----------------------------------------|----------|
| **executor_form_dialog.dart** | Empresa, Função, Divisão | Adicionar pesquisa (ex.: DropdownSearch). Manter single se for 1 por executor. |
| **empresa_form_dialog.dart** | Regional, Divisão, Tipo | Pesquisa. Single. |
| **divisao_form_dialog.dart** | Regional | Pesquisa. Single. |
| **local_form_dialog.dart** | Regional, Divisão, Segmento | Pesquisa. Single. |
| **frota_form_dialog.dart** | Tipo veículo, Regional, Divisão, Segmento | Pesquisa. Single. |
| **equipe_form_dialog.dart** | Tipo, Regional, Divisão, Segmento, Executor | Pesquisa (principalmente Executor/lista longa). Single ou multi conforme regra. |
| **centro_trabalho_form_dialog.dart** | Regional, Divisão, Segmento | Pesquisa. Single. |
| **kmz_view.dart** | Regional, Divisão | Pesquisa. Single (filtro de tela). |
| **linhas_transmissao_view.dart** | Regional, Divisão | Idem. |
| **supressao_vegetacao_view.dart** | Linha | Pesquisa (e multiseleção se for filtro por várias linhas). |
| **demandas_view.dart** | Status, Prioridade (form) | Se for filtro: multiseleção + pesquisa; se for campo do registro: pesquisa. |
| **crc_form_dialog.dart** | Status | Pesquisa. |
| **apr_form_dialog.dart** | Status | Pesquisa. |
| **advanced_list_view.dart** | Ordenação, Filter Status | Filtro Status → multiseleção + pesquisa; ordenação pode permanecer single. |
| **maintenance_history_view.dart** | Filtro, Período | Filtro → multiseleção + pesquisa se fizer sentido; período pode ser single. |
| **regra_prazo_nota_form_dialog.dart** | Prioridade, Data Referência | Pesquisa. Single. |
| **feriado_form_dialog.dart** | Tipo | Pesquisa. Single. |
| **horas_metas_view.dart** | Ano, Mês | Podem permanecer single (controle de data). |

---

## 4. Casos que podem permanecer single (sem obrigação de multiseleção)

| Arquivo | Campo | Motivo |
|--------|--------|--------|
| **telegram_config_dialog.dart** | Modo (dropdown) | Escolha única de modo. |
| **gantt_chart.dart** | Tipo, Tipo Período | Tipos de segmento, geralmente single. |
| **horas_metas_view.dart** | Ano, Mês | Controle de data, single é suficiente. |

---

## Resumo de prioridade

1. **Alta (filtros em dialogs de seleção):**  
   `at_selection_dialog.dart`, `si_selection_dialog.dart`, `task_selection_dialog.dart`  
   → Trocar filtros de dropdown único por **multiseleção com pesquisa** (mesmo padrão de `ordem_selection_dialog` / `nota_sap_selection_dialog`).

2. **Alta (filtros em views):**  
   `at_view.dart`, `si_view.dart`, `filter_bar.dart` (tela Atividades)  
   → Filtros em **multiseleção com pesquisa** (ex.: `MultiSelectFilterDialog` ou equivalente). ✅

3. **Média (formulários / outras views):**  
   Form dialogs e views da seção 3  
   → Pelo menos **pesquisa** em todos; multiseleção onde for filtro ou onde a regra de negócio permitir múltiplos valores.

Implementação sugerida para filtros: reutilizar o padrão de `_buildMultiSelect` + `_showMultiSelectDialog` (como em `ordem_selection_dialog.dart`) ou `MultiSelectFilterDialog` (como em `ordem_view.dart` / `notas_sap_view.dart`).
