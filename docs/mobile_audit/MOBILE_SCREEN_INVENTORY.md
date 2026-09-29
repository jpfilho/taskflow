# INVENTÁRIO COMPLETO DE TELAS — TASKFLOW MOBILE

Este documento apresenta o inventário técnico e diagnóstico de usabilidade de todas as telas e módulos do TaskFlow no contexto mobile (smartphones Android e iOS em resoluções 320px a 412px de largura).

---

## 1. Critérios de Classificação do Estado Mobile

* **BOM**: Tela já implementada com layout responsivo nativo, cartões adaptados, touch targets confortáveis (≥44px) e fluxo ergonômico.
* **ACEITÁVEL**: Tela utilizável no celular, mas com densidade um pouco alta ou necessidade de rolagem lateral secundária pontual.
* **PRECISA MELHORIA**: Tela com excesso de informação condensada, filtros cortados, inputs difíceis de selecionar ou botões pequenos.
* **RUIM**: Layout nitidamente "desktop comprimido", tabelas que estouram a tela, diálogos cortados ou navegação confusa.
* **CRÍTICO**: Inutilizável em campo com uma mão. Provoca RenderFlex overflow, truncamento severo de texto, Gantt ininteligível ou impossibilidade de completar tarefas operacionais.

---

## 2. Matriz de Inventário das Telas

| # | Módulo | Tela / Visão | Arquivo Principal / Widget | Estado Mobile | Problema Principal Identificado | Severidade |
|---|--------|--------------|----------------------------|---------------|---------------------------------|------------|
| 01 | **Atividades** | Tabela de Atividades | `lib/widgets/task_table.dart` | **CRÍTICO** | Grid tabular desktop espremido em 390px; colunas truncadas; necessidade de scroll horizontal infinito; ações de linha minúsculas. | CRÍTICO |
| 02 | **Atividades** | Gantt de Atividades | `lib/widgets/gantt_chart.dart` | **CRÍTICO** | Gráfico Gantt de 30 dias em tela pequena; barras finas de 12px; rótulos de datas sobrepostos; exige pinça de zoom contínua. | CRÍTICO |
| 03 | **Atividades** | Planner Diário / Semanal | `lib/widgets/planner_view.dart` | **RUIM** | Colunas diárias colapsadas horizontalmente; cards de tarefa estreitos com texto cortado; sem drag-and-drop utilizável no toque. | ALTO |
| 04 | **Atividades** | Detalhes da Tarefa | `lib/widgets/task_detail_dialog.dart` | **RUIM** | Dialog centralizado com 8 abas horizontais minúsculas; teclado virtual cobre campos inferiores; botões de salvar no topo. | ALTO |
| 05 | **Atividades** | Filtros Globais | `lib/widgets/filter_bar.dart` | **CRÍTICO** | Barra horizontal com mais de 8 dropdowns empilhados em SingleChildScrollView horizontal; difícil manipulação em campo. | CRÍTICO |
| 06 | **Dashboard** | Visão Geral Operacional | `lib/widgets/dashboard_screen.dart` | **PRECISA MELHORIA** | Cards KPI empilhados verticalmente com bom contraste, mas gráficos de pizza/barra perdem legendas e sofrem text clipping. | MÉDIO |
| 07 | **Equipes** | Lista de Equipes | `lib/widgets/team_view.dart` | **ACEITÁVEL** | Lista em cards verticais funcional, mas botões de ação (editar, alocar) menores que 36px e sem feedback tátil. | MÉDIO |
| 08 | **Equipes** | Escala / Gantt de Equipes | `lib/widgets/team_schedule_view.dart` | **CRÍTICO** | Visualização mensal do time com grade de dias microscópica; linhas de executores cortadas; impossível alocar com luvas. | CRÍTICO |
| 09 | **Frota** | Gestão de Veículos | `lib/widgets/frota_view.dart` | **ACEITÁVEL** | Cards de veículos limpos com status chip, porém filtro de equipes no topo não permite seleção rápida com o polegar. | MÉDIO |
| 10 | **Frota** | Escala da Frota | `lib/widgets/fleet_schedule_view.dart` | **CRÍTICO** | Gantt idêntico ao de equipes com células de 24px; impossível correlacionar veículo e motorista no celular sem scroll duplo. | CRÍTICO |
| 11 | **Demandas** | Lista de Demandas | `lib/features/demandas/presentation/screens/demandas_screen.dart` | **PRECISA MELHORIA** | Tabela simplificada; chips de prioridade legíveis, mas ações de transição de status exigem menu de contexto diminuto. | MÉDIO |
| 12 | **Demandas** | Formulário de Demanda | `lib/features/demandas/presentation/screens/demanda_form_screen.dart` | **RUIM** | Formulário extenso de tela cheia sem paginação ou etapas ("stepper"); teclado cobre campos de anexos e observação. | ALTO |
| 13 | **Documentos** | Gestão de Docs / APR / CRC | `lib/features/documents/presentation/screens/documents_screen.dart` | **PRECISA MELHORIA** | Lista de arquivos funcional, mas preview de PDF embutido não possui controle de zoom tátil adequado em telas estreitas. | MÉDIO |
| 14 | **Documentos** | Assinatura Digital | `lib/features/documents/presentation/widgets/signature_pad.dart` | **ACEITÁVEL** | Canvas de assinatura sensível ao toque, porém área de desenho pequena em celulares de 360px de largura. | BAIXO |
| 15 | **Checklists** | Execução de Checklist em Campo | `lib/widgets/checklist_screen.dart` | **PRECISA MELHORIA** | Radios e checkboxes muito próximos (<32px); botão de "Evidência / Foto" pequeno e escondido no rodapé do item. | ALTO |
| 16 | **Chat** | Central de Mensagens | `lib/widgets/chat_view.dart` | **PRECISA MELHORIA** | Layout tipo Slack com sidebar de canais que precisa ser aberta via modal; campo de texto não ancora acima do teclado no iOS. | ALTO |
| 17 | **Chat** | Conversa da Tarefa | `lib/widgets/task_chat_bottom_sheet.dart` | **ACEITÁVEL** | Bottom sheet bem posicionada, porém balões de mensagem com margens excessivas reduzem área útil do texto. | BAIXO |
| 18 | **Notas SAP** | Listagem de Notas | `lib/widgets/notas_sap_screen.dart` | **CRÍTICO** | Tabela com 14 colunas; paginação minúscula no canto inferior direito; botões de associar tarefa difíceis de clicar. | CRÍTICO |
| 19 | **Notas SAP** | Seleção e Vínculo de Notas | `lib/widgets/nota_sap_selection_dialog.dart` | **RUIM** | Diálogo estreito com lista de notas truncada; busca sem autofoco e sem teclado numérico para código SAP. | ALTO |
| 20 | **Ordens SAP** | Listagem de Ordens | `lib/widgets/ordens_sap_screen.dart` | **CRÍTICO** | Grid tabular extenso não responsivo; status de liberação da ordem escondido além da borda direita da viewport. | CRÍTICO |
| 21 | **Ordens SAP** | Confirmação de Ordens | `lib/widgets/confirmacao_ordens_screen.dart` | **RUIM** | Tabela de operações com campos numéricos de apontamento de horas muito pequenos; alto risco de erro de digitação. | ALTO |
| 22 | **Horas SAP** | Apontamento de Horas | `lib/widgets/horas_sap_screen.dart` | **RUIM** | Tabela de lançamentos em vez de interface tipo "Cartão de Ponto Diário"; seletores de hora padrão desktop. | ALTO |
| 23 | **SIs SAP** | Solicitações de Intervenção | `lib/widgets/sis_sap_screen.dart` | **CRÍTICO** | Tabela densa com códigos longos de subestação e linhas; texto sofre text clipping sem tooltip touch. | CRÍTICO |
| 24 | **ATs SAP** | Autorizações de Trabalho | `lib/widgets/ats_sap_screen.dart` | **CRÍTICO** | Planilha espremida; botões de validação técnica exigem pinça de zoom no navegador mobile. | CRÍTICO |
| 25 | **Linhas Transmissão** | Mapa de Vãos e Torres | `lib/widgets/transmission_line_screen.dart` | **RUIM** | Flutter Map com controles de zoom e camadas ocupando 40% da viewport; card de detalhes da torre cobre o mapa inteiro. | ALTO |
| 26 | **Supressão** | Supressão de Vegetação | `lib/widgets/vegetation_suppression_screen.dart` | **RUIM** | Grid de polígonos e árvores marcadas; fotos de evidência em miniaturas de 30x30px impossíveis de inspecionar. | ALTO |
| 27 | **Mídia / Álbuns** | Galeria de Evidências Fotográficas | `lib/features/media_albums/presentation/screens/media_albums_screen.dart` | **ACEITÁVEL** | Grid de 2 ou 3 colunas razoável, mas falta botão flutuante rápido para "Tirar Foto Imediata" com geolocalização. | MÉDIO |
| 28 | **Alertas** | Central de Alertas e Notificações | `lib/features/warnings/presentation/screens/warnings_screen.dart` | **ACEITÁVEL** | Lista vertical simples, porém falta distinção cromática clara entre alertas bloqueantes (P0) e avisos informativos. | BAIXO |
| 29 | **GTD** | Gestão Pessoal / Tarefas Rápidas | `lib/modules/gtd/presentation/screens/gtd_screen.dart` | **PRECISA MELHORIA** | Caixa de entrada funcional, mas processo de clarificar/organizar depende de menus dropdown pensados para mouse. | MÉDIO |
| 30 | **Melhorias e Bugs** | Abertura de Tickets Internos | `lib/modules/melhorias_bugs/presentation/screens/melhorias_bugs_screen.dart` | **ACEITÁVEL** | Lista em cards simples; formulário com bom tamanho, porém upload de prints no mobile sem compressão automática. | BAIXO |
| 31 | **Assistentes IA** | Chat com IA e Gráficos | `lib/features/ai_assistants/presentation/screens/ai_assistants_screen.dart` | **PRECISA MELHORIA** | Respostas em markdown longas sem colapso; gráficos embutidos geram overflow horizontal de 15 a 45px na lateral direita. | ALTO |
| 32 | **Custos** | Gestão de Custos Operacionais | `lib/widgets/cost_management_screen.dart` | **RUIM** | Painel analítico denso com tabelas de rateio de despesas; essencialmente uma tela de escritório/gestão. | ALTO |
| 33 | **Configurações** | Ajustes do Usuário e Sistema | `lib/widgets/config_screen.dart` | **ACEITÁVEL** | Lista padrão de opções; botões de alternância e seletores com espaçamento aceitável. | BAIXO |
| 34 | **Navegação Shell** | Drawer Principal e Top App Bar | `lib/main.dart` (`_buildDrawer`, `_buildTopBar`) | **CRÍTICO** | Drawer com 27 itens em texto corrido sem categorização operacional; AppBar com 6 ícones no topo inalcançáveis com uma mão. | CRÍTICO |
| 35 | **Barra Inferior** | Footbar Atual | `lib/main.dart` (`_buildFootbar`) | **CRÍTICO** | Só aparece em 3 índices (0, 16, 20); ícones de 20px com texto de 9px; viola zona ergonômica mínima de 44x44px. | CRÍTICO |

---

## 3. Síntese do Diagnóstico de Telas

* **Telas Auditadas**: 35 visões mapeadas.
* **Estado Crítico**: 10 telas (28,6%) — Inutilizáveis em operação de campo em smartphone.
* **Estado Ruim**: 10 telas (28,6%) — Forte atrito, perda de contexto e frustração do usuário.
* **Precisa Melhoria**: 8 telas (22,8%) — Funcionais com limitações ergonômicas e visuais.
* **Estado Aceitável**: 7 telas (20,0%) — Operam razoavelmente bem, necessitando apenas refinamentos cosméticos e de touch target.
* **Estado Bom**: 0 telas (0,0%) — Nenhuma tela atual foi desenhada com padrão 100% Mobile-First nativo.
