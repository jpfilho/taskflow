# TaskFlow Design System — Estado Atual da Arquitetura Front-End

> **Status:** Diagnóstico Técnico Concluído  
> **Data:** Setembro de 2026  
> **Base de Análise:** 361 arquivos Dart em `lib/`

---

## 1. Mapeamento Real da Estrutura de Código

A análise profunda da pasta `lib/` revelou uma organização mista: parte legada concentrada em `lib/widgets/` (com arquivos monolíticos) e partes mais recentes moduladas em `lib/features/` e `lib/modules/`.

```text
Frontend TaskFlow
│
├── Entrypoint & Shell
│   ├── lib/main.dart (3.831 linhas — Shell principal, controle de abas e switch de rotas)
│   ├── lib/config/app_menu_config.dart (Configuração unificada de itens do menu e visibilidade)
│   ├── lib/providers/theme_provider.dart (Gerenciamento de estado de tema)
│   └── lib/services/theme_service.dart (Definição de temas Light, Dark e Axia + cores customizadas)
│
├── Foundations & Utilities
│   ├── lib/utils/responsive.dart (Breakpoints: 600px mobile, 1024px tablet, 768px home)
│   └── lib/widgets/form_dialog_helpers.dart (Tentativa inicial de campos com floating label e dialog moderno)
│
├── Shared UI & Widgets Monolíticos (lib/widgets/) [109 arquivos]
│   ├── Navegação: sidebar.dart, header_bar.dart, home_shortcuts_screen.dart
│   ├── Tabelas Operacionais: task_table.dart (3.795 lin), notas_sap_view.dart (3.914 lin), ordem_view.dart (3.263 lin)
│   ├── Cronogramas & Gráficos: gantt_chart.dart (213 KB), activity_gantt_view.dart (138 KB), hourly_calendar_view.dart
│   ├── Dashboards: comprehensive_dashboard.dart, dashboard.dart, analytics_view.dart, notas_sap_dashboard_view.dart
│   ├── Filtros: filter_bar.dart (1.397 lin), multi_select_filter_dialog.dart
│   ├── Chat: chat_view.dart, chat_screen.dart (120 KB), chat_grupos_list.dart
│   └── Formulários & Cadastros: 28 pares de *_form_dialog.dart e *_list_view.dart
│
├── Features Modulares (lib/features/) [7 módulos bem delimitados]
│   ├── ai_assistants/ (Assistentes de IA, editores de prompt, histórico de versões)
│   ├── chat_feedback/ (Auditoria de respostas de IA, feedback item a item)
│   ├── demandas/ (Gestão de chamados e demandas operacionais)
│   ├── documents/ (Gestão e visualização de documentos técnicos)
│   ├── media_albums/ (Álbuns de fotos, inspeções visuais em campo e status de álbuns)
│   ├── projetos/ (Módulo de projetos, macroetapas, etapas, cronogramas e riscos)
│   └── warnings/ (Sistema de alertas e avisos operacionais por tarefa)
│
└── Módulos Transversais (lib/modules/)
    ├── gtd/ (Módulo Getting Things Done: Inbox, Next Actions, Waiting, Someday, Projects)
    └── melhorias_bugs/ (Central de reporte e acompanhamento de bugs e melhorias)
```

---

## 2. Como o Tema Funciona Hoje

Atualmente o sistema possui:
* [`ThemeProvider`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/providers/theme_provider.dart): Carrega e persiste `AppTheme.light`, `AppTheme.dark` e `AppTheme.axia` via `SharedPreferences`.
* [`ThemeService`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/services/theme_service.dart): Define `ThemeData` para cada variante.
* **Problema Crítico de Adoção**: Quase a totalidade das telas **ignora o `Theme.of(context)`**.
  * Cores de superfície, bordas, textos e botões são instanciadas diretamente como literais (`Colors.white`, `Colors.blue`, `Color(0xFF1E293B)`, `Colors.grey[200]`).
  * No `ThemeService`, existe persistência de cores arbitrárias para `appbar`, `sidebar` e `footbar` via `ColorThemeNotifier`, gerando fragmentação visual.
  * O modo escuro (`ThemeMode.dark`) falha visualmente na maioria das telas antigas porque muitos containers assumem fundo escuro mas mantêm textos com `Colors.black87` ou fundos brancos com bordas duras.

---

## 3. Navegação e Page Shell

* **Desktop/Web**:
  * Utiliza um layout de 3 faixas: [`HeaderBar`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/header_bar.dart) superior (com logo, atalhos, busca global, badge de chat e perfil), [`Sidebar`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/sidebar.dart) lateral retrátil (índices inteiros 0 a 29) e área de conteúdo principal.
  * O controle de qual tela exibir é feito por um bloco de `switch (_sidebarSelectedIndex)` dentro de `MainScreen` em `lib/main.dart`.
* **Mobile**:
  * Em telas menores que 768px, o usuário é direcionado para [`HomeShortcutsScreen`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/home_shortcuts_screen.dart) com um grid de botões de atalho.
* **Inconsistência Identificada**:
  * Cada tela filha reimplementa seu próprio topo (algumas colocam um `Container` com título, outras usam `AppBar`, outras já começam direto com `Row` de filtros).
  * Não há um componente unificado de **Page Shell** com cabeçalho padronizado, breadcrumbs e barra de ações.

---

## 4. O Que Já Existe de Bom e Deve Ser Preservado

1. **Estrutura central de Menu em `AppMenuConfig`**: O arquivo [`lib/config/app_menu_config.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/config/app_menu_config.dart) centraliza de forma limpa os rótulos, ícones e regras de permissão (root, GTD, etc.). **Manter como fonte de verdade**.
2. **`ResizablePanel` para Layouts Divididos**: O componente [`lib/widgets/resizable_panel.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/resizable_panel.dart) é excelente e essencial para operadores dividirem a visão entre Tabela de Atividades e Gantt.
3. **Padrão de Layout das Telas de Configuração**: `BaseConfigListView` e `form_dialog_helpers.dart` estabeleceram uma base limpa para CRUDs com modais centralizados de 512px de largura máxima.
4. **Isolamento de Features Novas**: Pastas como `features/ai_assistants/`, `features/projetos/` e `features/media_albums/` já possuem arquitetura limpa em camadas (domain/data/presentation).
5. **Sincronização Visual do Gantt**: A sincronização entre cabeçalho da tabela (`kActivitiesHeaderTopHeight`, `kActivitiesHeaderRowHeight`) e linha do tempo do Gantt é uma conquista de engenharia que não pode ser quebrada.
