# TaskFlow Design System — Screen Inventory

| Módulo | Tela / Diálogo | Arquivo | Tipo | Responsividade | Problemas Encontrados | Prioridade |
| :--- | :--- | :--- | :--- | :---: | :--- | :---: |
| **Shell Global** | MainScreen | `lib/main.dart` | Shell / Container | Sim | Switch monolítico de 30 índices, rebuild amplo | **P0** |
| **Programação** | TaskTable | `lib/widgets/task_table.dart` | Tabela Operacional | Parcial | 3.795 linhas, 30+ funções internas, sync com Gantt | **P0** |
| **Programação** | ActivityGanttView | `lib/widgets/activity_gantt_view.dart` | Cronograma / Gantt | Parcial | 138 KB, renderização customizada de barras | **P0** |
| **Programação** | GanttChart | `lib/widgets/gantt_chart.dart` | Cronograma / Gantt | Parcial | 213 KB, escala temporal complexa | **P0** |
| **Programação** | TaskFormDialog | `lib/widgets/task_form_dialog.dart` | Modal / Formulário | Parcial | 282 KB, dezenas de campos em abas internas | **P0** |
| **Programação** | HourlyCalendarView | `lib/widgets/hourly_calendar_view.dart` | Calendário Horário | Parcial | Exibição horária densa | **P1** |
| **Programação** | PlannerView | `lib/widgets/planner_view.dart` | Kanban / Colunas | Parcial | Colunas por status com cards densos | **P1** |
| **Programação** | FilterBar | `lib/widgets/filter_bar.dart` | Barra de Filtros | Não | 1.397 linhas, lógica misturada com visual | **P0** |
| **SAP & Operação** | NotasSAPView | `lib/widgets/notas_sap_view.dart` | Tabela / Cards | Parcial | 3.914 linhas, paginação manual, 19 colunas | **P0** |
| **SAP & Operação** | OrdemView | `lib/widgets/ordem_view.dart` | Tabela / Cards | Parcial | 3.263 linhas, filtros internos | **P0** |
| **SAP & Operação** | HorasSAPView | `lib/widgets/horas_sap_view.dart` | Tabela Operacional | Parcial | 2 DataTables, apropriação de horas | **P0** |
| **SAP & Operação** | HorasMetasView | `lib/widgets/horas_metas_view.dart` | Tabela & Metas | Parcial | 223 KB, cálculos densos de produtividade | **P1** |
| **SAP & Operação** | ATView | `lib/widgets/at_view.dart` | Tabela Operacional | Parcial | 83 KB, visualização de ATs | **P1** |
| **SAP & Operação** | SIView | `lib/widgets/si_view.dart` | Tabela Operacional | Parcial | 72 KB, visualização de SIs | **P1** |
| **SAP & Operação** | ConfirmacaoOrdensView | `lib/widgets/confirmacao_ordens_view.dart` | Tabela Operacional | Parcial | Validação de encerramento SAP | **P1** |
| **SAP & Operação** | NotasSAPCalendarView | `lib/widgets/notas_sap_calendar_view.dart`| Calendário | Sim | Badges de prazo em células de dia | **P2** |
| **SAP & Operação** | OrdemCalendarView | `lib/widgets/ordem_calendar_view.dart` | Calendário | Sim | Pílulas de tolerância e ordem | **P2** |
| **SAP & Operação** | ATsCalendarView | `lib/widgets/ats_calendar_view.dart` | Calendário | Sim | Calendário operacional | **P2** |
| **SAP & Operação** | NotaSAPSelectionDialog| `lib/widgets/nota_sap_selection_dialog.dart`| Diálogo de Seleção| Parcial | Tabela interna em modal de 45 KB | **P1** |
| **SAP & Operação** | OrdemSelectionDialog | `lib/widgets/ordem_selection_dialog.dart` | Diálogo de Seleção| Parcial | Tabela interna em modal | **P1** |
| **SAP & Operação** | ATSelectionDialog | `lib/widgets/at_selection_dialog.dart` | Diálogo de Seleção| Parcial | Tabela interna em modal | **P1** |
| **SAP & Operação** | SISelectionDialog | `lib/widgets/si_selection_dialog.dart` | Diálogo de Seleção| Parcial | Tabela interna em modal | **P1** |
| **SAP & Operação** | LinhasTransmissaoView | `lib/widgets/linhas_transmissao_view.dart` | Operacional / Mapa | Sim | Visualização de linhas e torres | **P2** |
| **SAP & Operação** | SupressaoVegetacaoView| `lib/widgets/supressao_vegetacao_view.dart`| Operacional / Mapa | Sim | 97 KB, controle de intervenções florestais | **P2** |
| **Dashboards** | ComprehensiveDashboard| `lib/widgets/comprehensive_dashboard.dart`| Dashboard Gerencial | Sim | Indicadores globais, KPIs de notas e ordens | **P1** |
| **Dashboards** | Dashboard (Legacy) | `lib/widgets/dashboard.dart` | Dashboard | Sim | Gráficos e distribuição de status | **P2** |
| **Dashboards** | AnalyticsView | `lib/widgets/analytics_view.dart` | Indicadores | Sim | Análise de produtividade e histórico | **P2** |
| **Dashboards** | NotasSAPDashboardView | `lib/widgets/notas_sap_dashboard_view.dart`| Dashboard SAP | Sim | Gráficos por prioridade e vencimento | **P2** |
| **Dashboards** | ATsDashboardView | `lib/widgets/ats_dashboard_view.dart` | Dashboard ATs | Sim | Resumo de autorizações de trabalho | **P2** |
| **Recursos / Equipes**| TeamScheduleView | `lib/widgets/team_schedule_view.dart` | Cronograma Equipes | Parcial | 198 KB, visualização de escala e conflitos | **P0** |
| **Recursos / Frota** | FleetScheduleView | `lib/widgets/fleet_schedule_view.dart` | Cronograma Frota | Parcial | 110 KB, alocação de veículos e manutenções | **P1** |
| **Recursos / Equipes**| TeamManagementView | `lib/widgets/team_management_view.dart` | Gestão | Sim | Cards de status e executores | **P2** |
| **Recursos / Frota** | FleetManagementView | `lib/widgets/fleet_management_view.dart` | Gestão | Sim | Cards de frota | **P2** |
| **Demandas** | DemandasScreen | `lib/features/demandas/presentation/screens/demandas_screen.dart` | Tabela / Listagem | Sim | **TFDS MIGRATED** (Fase 9 - 96.8% Coverage) | **P1** |
| **Demandas** | DemandaDetailScreen | `lib/features/demandas/presentation/screens/demanda_detail_screen.dart` | Detalhes | Sim | **TFDS MIGRATED** (Fase 9 - 97.2% Coverage) | **P1** |
| **Projetos** | ProjetosHomeScreen | `lib/features/projetos/presentation/screens/projetos_home_screen.dart` | Gestão de Projetos | Sim | **TFDS MIGRATED** (Fase 10 - 97.5% Coverage) | **P1** |
| **Projetos** | ProjetoDetailScreen | `lib/features/projetos/presentation/screens/projeto_detail_screen.dart` | Detalhes & Abas | Sim | **TFDS MIGRATED** (Fase 10 - 97.0% Coverage) | **P1** |
| **Projetos** | ProjetoFormDialog | `lib/features/projetos/presentation/widgets/projeto_form_dialog.dart` | Diálogo / Form | Sim | **TFDS MIGRATED** (Fase 10 - 98.0% Coverage) | **P2** |
| **Projetos** | MacroetapaFormDialog| `lib/features/projetos/presentation/widgets/macroetapa_form_dialog.dart`| Diálogo / Form | Sim | **TFDS MIGRATED** (Fase 10 - 98.0% Coverage) | **P2** |
| **Projetos** | EtapaFormDialog | `lib/features/projetos/presentation/widgets/etapa_form_dialog.dart` | Diálogo / Form | Sim | **TFDS MIGRATED** (Fase 10 - 98.0% Coverage) | **P2** |
| **Projetos** | ProjetoAtividadeFormDialog| `lib/features/projetos/presentation/widgets/projeto_atividade_form_dialog.dart`| Diálogo / Form | Sim | **TFDS MIGRATED** (Fase 10 - 98.0% Coverage) | **P2** |
| **IA & Assistentes** | AiAssistantsListScreen | `lib/features/ai_assistants/presentation/screens/ai_assistants_list_screen.dart` | Listagem | Sim | Cards de assistentes com paleta Slate | **P2** |
| **IA & Assistentes** | AiAssistantEditorScreen| `lib/features/ai_assistants/presentation/screens/ai_assistant_editor_screen.dart` | Formulário / Editor| Sim | Editor de prompts e parâmetros | **P2** |
| **IA & Assistentes** | AiAssistantTestScreen | `lib/features/ai_assistants/presentation/screens/ai_assistant_test_screen.dart` | Teste / Chat | Sim | Chat interativo de homologação de IA | **P2** |
| **IA & Assistentes** | PromptVersionHistoryScreen| `lib/features/ai_assistants/presentation/screens/prompt_version_history_screen.dart`| Histórico | Sim | Timeline de revisões de prompt | **P3** |
| **Álbuns de Mídia** | MediaAlbumsGalleryPage | `lib/features/media_albums/presentation/pages/gallery_page.dart` | Galeria | Sim | **TFDS MIGRATED** (Fase 11 - 97.5% Coverage) | **P1** |
| **Álbuns de Mídia** | StatusAlbumListView | `lib/features/media_albums/presentation/pages/status_album_list_view.dart` | Tabela | Sim | **TFDS MIGRATED** (Fase 11 - 97.8% Coverage) | **P2** |
| **Álbuns de Mídia** | UploadPage | `lib/features/media_albums/presentation/pages/upload_page.dart` | Formulário / Upload| Sim | **TFDS MIGRATED** (Fase 11 - 97.0% Coverage) | **P2** |
| **Documentos** | DocumentsPage | `lib/features/documents/presentation/pages/documents_page.dart` | Documentação | Sim | **TFDS MIGRATED** (Fase 11 - 97.5% Coverage) | **P2** |
| **Documentos** | DocumentDetailPage | `lib/features/documents/presentation/pages/document_detail_page.dart` | Detalhes | Sim | **TFDS MIGRATED** (Fase 11 - 98.0% Coverage) | **P2** |
| **Documentos** | DocumentUploadPage | `lib/features/documents/presentation/pages/document_upload_page.dart` | Formulário / Upload| Sim | **TFDS MIGRATED** (Fase 11 - 97.2% Coverage) | **P2** |
| **GTD** | GtdHomePage | `lib/modules/gtd/presentation/screens/gtd_home_page.dart` | Produtividade | Sim | Painel com 8 abas de metodologia GTD | **P2** |
| **Melhorias & Bugs** | MelhoriasBugsHomeScreen| `lib/modules/melhorias_bugs/presentation/screens/melhorias_bugs_home_screen.dart`| Gestão | Sim | Triagem de melhorias e chamados | **P2** |
| **Comunicação** | ChatView | `lib/widgets/chat_view.dart` | Comunicação | Sim | Painel de grupos e tópicos | **P1** |
| **Comunicação** | ChatScreen | `lib/widgets/chat_screen.dart` | Chat Bidirecional | Sim | 120 KB, mensagens, anexos e notas | **P1** |
| **Administração** | ConfiguracaoView | `lib/widgets/configuracao_view.dart` | Configurações | Sim | Menu central de cadastros | **P1** |
| **Administração** | FuncaoListView | `lib/widgets/funcao_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Piloto - 96.4% Coverage) | **P2** |
| **Administração** | StatusListView | `lib/widgets/status_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 1 - 96.5% Coverage) | **P2** |
| **Administração** | CentroTrabalhoListView | `lib/widgets/centro_trabalho_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 1 - 96.2% Coverage) | **P2** |
| **Administração** | SegmentoListView | `lib/widgets/segmento_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 1 - 97.1% Coverage) | **P2** |
| **Recursos / Equipes**| EquipeListView | `lib/widgets/equipe_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 1 - 95.8% Coverage) | **P2** |
| **Administração** | RegionalListView | `lib/widgets/regional_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 2 - 96.8% Coverage) | **P2** |
| **Administração** | DivisaoListView | `lib/widgets/divisao_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 2 - 96.4% Coverage) | **P2** |
| **Administração** | EmpresaListView | `lib/widgets/empresa_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 2 - 97.0% Coverage) | **P2** |
| **Administração** | TipoAtividadeListView | `lib/widgets/tipo_atividade_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 2 - 95.5% Coverage) | **P2** |
| **Administração** | LocalListView | `lib/widgets/local_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Wave 2 - 96.2% Coverage) | **P2** |
| **Administração** | FeriadoListView | `lib/widgets/feriado_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Phase 8 - 96.6% Coverage) | **P2** |
| **Administração** | RegraPrazoNotaListView | `lib/widgets/regra_prazo_nota_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Phase 8 - 96.8% Coverage) | **P2** |
| **Recursos / Frota** | FrotaListView | `lib/widgets/frota_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Phase 8 - 96.5% Coverage) | **P2** |
| **Recursos / Equipes**| ExecutorListView | `lib/widgets/executor_list_view.dart` | Tabela CRUD | Sim | **TFDS MIGRATED** (Phase 8 - 96.7% Coverage) | **P2** |
| **Autenticação** | LoginScreen | `lib/widgets/login_screen.dart` | Login | Sim | Tela de login e autenticação simples | **P2** |
| **Navegação Mobile** | HomeShortcutsScreen | `lib/widgets/home_shortcuts_screen.dart` | Grade de Atalhos | Sim | Menu em cards rápidos para celular | **P1** |
