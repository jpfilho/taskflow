# TaskFlow Design System — Inventário Geral de UI

> **Status:** Concluído  
> **Data:** Setembro de 2026

---

## 1. Visão Geral do Inventário

O mapeamento automatizado e manual da interface do TaskFlow identificou **135 telas/diálogos** e **mais de 119 componentes funcionais**, distribuídos da seguinte forma:

```text
Distribuição por Categoria Visual:
├── Modais e Diálogos de Formulário/Seleção: 54 componentes
├── Telas e Visões Operacionais: 38 visões
├── Tabelas de Dados (DataTable / Custom): 28 telas
├── Telas Administrativas (CRUDs Base): 24 telas
├── Dashboards e Telas com Gráficos: 7 visões
├── Telas de Calendário: 5 visões
├── Visões de Cronograma e Gantt: 3 visões
├── Telas de Chat e Feedback: 4 visões
└── Telas de Módulos Especiais (GTD / IA / Projetos): 18 telas
```

---

## 2. Inventário de Elementos de Ação (Botões)

Total de instâncias de botões no código: **1.060 ocorrências**

| Tipo de Botão | Ocorrências | Uso Predominante | Problema Encontrado | Ação Proposta |
| :--- | :---: | :--- | :--- | :--- |
| `IconButton` | **413** | Ações de tabela, cabeçalhos, fechar diálogos | 89% sem `Tooltip`, tamanhos arbitrários (16 a 28px) | Padronizar em `TFIconButton` com tooltip obrigatório |
| `TextButton` | **286** | Ações de "Cancelar", links, fechar modais | Estilos de texto inline, cores cinza/azul variadas | Padronizar em `TFButton.ghost` ou `TFButton.tertiary` |
| `ElevatedButton` | **239** | Ações primárias ("Salvar", "Filtrar", "Novo") | Elevação fixa, cores azuis distintas, paddings mágicos | Padronizar em `TFButton.primary` |
| `OutlinedButton` | **65** | Ações secundárias em filtros e telas novas | Bordas e cores de foco incompatíveis | Padronizar em `TFButton.secondary` |
| `FilledButton` | **56** | Usado quase exclusivamente em `features/ai_assistants` | Estilos Material 3 divergentes das telas legadas | Consolidar dentro da taxonomia de `TFButton` |
| `FloatingActionButton`| **11** | Criação rápida em mobile / listas | Cores e posições inconsistentes | Padronizar em `TFFab` |

---

## 3. Inventário de Formulários e Inputs

Total de campos de entrada: **325 ocorrências**

| Componente | Ocorrências | Padrão Atual | Inconsistências | Padrão Futuro |
| :--- | :---: | :--- | :--- | :--- |
| `TextFormField` | **116** | Formulários em diálogos | Alguns usam `FloatingLabelTextField`, outros decoração inline | `TFTextField` |
| `TextField` | **95** | Barras de filtro e busca rápida | Bordas quadradas vs arredondadas, alturas distintas | `TFSearchField` / `TFTextField` |
| `DropdownButtonFormField` | **73** | Seletores em formulários | Validações e alturas divergentes | `TFDropdown` |
| `DropdownButton` | **20** | Seletores de filtro em tabelas | Fundo transparente sem borda ou com underlines legados | `TFSelect` / `TFFilterDropdown` |
| `Checkbox` | **19** | Seleção em listas e filtros | Cores de preenchimento azuis e verdes | `TFCheckbox` |
| `Switch` | **5** | Toggles de configuração | Cores variadas | `TFSwitch` |
| `Radio` | **2** | Seleção única | Pouco utilizado | `TFRadio` |

---

## 4. Inventário de Tabelas de Dados

Foram identificadas **28 implementações diretas de `DataTable`** no projeto, além da tabela customizada `TaskTable`.

* **Tabelas Operacionais Críticas (P0)**:
  * [`lib/widgets/task_table.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/task_table.dart) (Tabela complexa multi-coluna sincronizada com o Gantt).
  * [`lib/widgets/notas_sap_view.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/notas_sap_view.dart) (Tabela de 19 colunas com ordenação, badges de prazo e paginação manual).
  * [`lib/widgets/ordem_view.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/ordem_view.dart) (Tabela de 16 colunas).
  * [`lib/widgets/horas_sap_view.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/horas_sap_view.dart) (Tabelas de apropriação de horas).
  * [`lib/widgets/at_view.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/at_view.dart) e [`si_view.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/si_view.dart).
* **Tabelas de Diálogos de Seleção**:
  * `nota_sap_selection_dialog.dart`, `ordem_selection_dialog.dart`, `at_selection_dialog.dart`, `si_selection_dialog.dart`, `task_selection_dialog.dart`.
* **Tabelas Administrativas**:
  * 12 list views (`executor_list_view.dart`, `frota_list_view.dart`, `equipe_list_view.dart`, etc.).

---

## 5. Inventário de Barras de Filtros

Identificadas **6 variações** de barras de filtro:
1. `lib/widgets/filter_bar.dart` (1.397 linhas — filtro global de Atividades/Gantt com 10+ campos).
2. Filtros internos em `notas_sap_view.dart` (Wrap com 8 dropdowns + busca textual).
3. Filtros internos em `ordem_view.dart` (Row de dropdowns com formatação local).
4. `lib/features/media_albums/presentation/widgets/filter_bar.dart` (Filtros de status de fotos e álbuns).
5. `lib/features/documents/presentation/widgets/filter_bar_documents.dart` (Filtro simples de busca).
6. Diálogos de seleção com barra de busca e filtros de data embutidos.

---

## 6. Inventário de Estados de Feedback

* **Loading**:
  * 48 arquivos utilizam `CircularProgressIndicator` puro sem centralização visual.
  * Inexistência de componentes do tipo **Skeleton** para carregamento de tabelas ou dashboards.
* **Empty States**:
  * Cada tela cria sua própria mensagem (`Center(child: Text('Nenhum registro encontrado'))`).
  * Não há ilustrações, orientações operacionais ou botões de ação sugerida padronizados.
* **Error States**:
  * Variações entre `ScaffoldMessenger.showSnackBar` com cores `Colors.red`, `Colors.orange` e alertas em diálogo.
