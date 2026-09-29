# TASKFLOW MOBILE UX AUDIT — RELATÓRIO EXECUTIVO E TÉCNICO

## RESUMO EXECUTIVO

Esta auditoria profunda analisou o aplicativo **TaskFlow** sob a ótica estrita de usabilidade mobile em smartphones (resoluções de 320px a 412px de largura), priorizando a rotina das equipes de manutenção e operação que atuam em campo sob luz solar, em movimento e muitas vezes utilizando apenas uma mão ou luvas de proteção.

### 1. Quais são os principais problemas atuais do TaskFlow no mobile?
* **Tentativa de encaixar grades tabulares desktop (DataTables de 8 a 14 colunas) em telas de 390px**, exigindo rolagem horizontal contínua e truncando informações vitais.
* **Uso de gráficos Gantt mensais de 30 dias** com barras microscópicas de 12px e rótulos sobrepostos, ininteligíveis no celular.
* **Barra de filtros horizontal no topo** espremendo mais de 8 seletores em scroll lateral, com botões de fechamento diminutos.
* **Touch targets abaixo do padrão ergonômico** (dezenas de ícones e botões menores que 32 × 32 px, com textos de até 9px).
* **Ausência de uma tela inicial focada no trabalho diário do operador** ("O que eu preciso fazer hoje").

### 2. O sistema está sendo tratado como mobile-first ou como desktop comprimido?
O sistema está sendo tratado quase integralmente como um **"Desktop Comprimido"**. O layout adota uma flag binária `isMobile` para simplesmente empilhar colunas ou ocultar painéis laterais, mantendo a mesma densidade informacional, os mesmos formulários de 15 campos e as mesmas tabelas corporativas concebidas para monitores de 24 polegadas.

### 3. Quais telas mais prejudicam hoje o trabalho das equipes?
1. **Atividades (Tabela e Gantt)**: O técnico não consegue ler a descrição da tarefa sem rolar horizontalmente e não consegue arrastar barras no Gantt.
2. **Programação de Equipes / Frota (Escalas)**: A grade mensal impossibilita ver quem está escalado no dia atual.
3. **Notas e Ordens SAP**: Tabelas densas de 14 colunas dificultam a consulta rápida do código da OS e o apontamento em campo.
4. **Formulário de Detalhes da Tarefa**: Diálogos com 8 abas horizontais onde o teclado virtual encobre os botões de salvar.

### 4. Quais problemas são sistêmicos?
* Falta de componentes universais de lista vertical baseados em **Cards com ações na base**.
* Concentração de 85% das ações interativas no topo da tela (**Zona Difícil do polegar**).
* Falta de um Design System com tokens de espaçamento, tipografia e tamanhos de toque mínimos (≥48px).
* Diálogos modais (`AlertDialog`) centralizados que sofrem sobreposição pelo teclado virtual em telas estreitas.

### 5. Quais problemas são específicos de algumas telas?
* **Gantt Chart**: Problema específico dos módulos de Atividades, Planejamento, Equipes e Frota.
* **Mapa de Linhas de Transmissão**: Controles de camada e cards de torre que ocupam mais de 50% da área do mapa.
* **Chat**: Campo de digitação de texto que perde a ancoragem na abertura do teclado virtual no iOS.

### 6. Quais componentes precisam ser padronizados?
* **Cards**: Unificar os 6 estilos divergentes em um único `TFCard` / `MobileTaskCard` (raio de 12px, padding interno de 14px).
* **Chips de Status**: Padronizar paleta de cores e garantir contraste mínimo WCAG (≥4.5:1) sob sol intenso.
* **Bottom Sheet**: Substituir os diálogos centrais por folhas arrastáveis ancoradas na base para filtros, detalhes e seleção.
* **Botões de Ação**: Padronizar botões primários com altura mínima de 48px e largura total (*full-width*) na base.

### 7. O que deveria ser completamente diferente entre desktop e mobile?
* **Desktop**: Ferramenta analítica de gestão — exibe visão macro, Gantts de longo prazo, múltiplos filtros simultâneos e tabelas comparativas.
* **Mobile**: Terminal de execução em campo — exibe a tarefa atual, botão de "Iniciar/Concluir", câmera rápida para evidências fotográficas, checklist de segurança e comunicação instantânea.

### 8. Quais são os maiores quick wins?
1. Aumentar os botões da barra inferior (`_buildFootbar`) de 38px para 56px de altura e a tipografia de 9px para 12px.
2. Substituir a tabela tabular de Atividades por uma lista vertical de cartões nos smartphones.
3. Converter a barra horizontal de filtros em uma `BottomSheet` acessível por um único botão de filtro.
4. Definir tipo de teclado numérico (`TextInputType.number`) nos campos de código SAP, horímetro e horas.
5. Inserir botão flutuante (FAB) de "Tirar Foto" na tela de tarefas e evidências.

### 9. Quais mudanças exigirão refatoração arquitetural?
* Criação de um shell dedicado `MobileShell` com `BottomNavigationBar` persistente de 5 abas.
* Separação conceitual da visualização de cronograma: manter Gantt no desktop e criar uma **Agenda Vertical Diária** no mobile.
* Estruturação de um Design System mobile com tokens em `lib/mobile/core/theme/`.

### 10. Qual deveria ser a estratégia de modernização?
Adoção de uma estratégia em **fases modulares não destrutivas**:
1. Construir o Design System Mobile e a barra de navegação ergonômica.
2. Adaptar a tela inicial ("Meu Dia") e a lista de Atividades em cards operacionais.
3. Substituir o Gantt mobile por Agenda Cronológica.
4. Adaptar os fluxos de campo (Checklists, Evidências e Apontamento de Horas SAP).
5. Migrar gradualmente as telas secundárias e relatórios.

---

## TOP 20 PROBLEMAS MOBILE IDENTIFICADOS

Abaixo estão os 20 problemas mais críticos encontrados na auditoria técnica e visual do TaskFlow:

### Problema 01: Tabelas Tabulares Corporativas Inavegáveis em Smartphone
* **Tela**: Atividades (`lib/widgets/task_table.dart`), Notas SAP (`notas_sap_screen.dart`), Ordens SAP (`ordens_sap_screen.dart`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/04_atividades_tabela.png` e `11_notas_sap.png`.
* **Impacto**: O usuário enxerga apenas 1 coluna e meia na largura de 390px; precisa arrastar horizontalmente dezenas de vezes para ver o status ou responsável.
* **Causa Provável**: Utilização de `DataTable` e `TFDataTable` com larguras mínimas de coluna projetadas para desktop.
* **Severidade**: **CRÍTICO**
* **Solução Sugerida**: Condicionar a renderização no mobile (`Responsive.isMobile`) para lista vertical de cards com dados essenciais na frente e secundários expansíveis.

### Problema 02: Gráfico Gantt Tradicional Inutilizável no Celular
* **Tela**: Atividades (`gantt_chart.dart`), Escala de Equipes (`team_schedule_view.dart`), Escala de Frota (`fleet_schedule_view.dart`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/02_atividades_gantt.png` e `07_equipes_escala_gantt.png`.
* **Impacto**: Células de 22 a 28px de largura; texto sobreposto; barras finas de 12px que não respondem adequadamente ao toque do dedo.
* **Causa Provável**: Reutilização direta do componente de Gantt de 30 dias contínuos em viewport estreita.
* **Severidade**: **CRÍTICO**
* **Solução Sugerida**: Substituir o Gantt no mobile por uma **Agenda Cronológica Diária/Semanal** com seleção de dia em carrossel horizontal de chips.

### Problema 03: Barra de Navegação Inferior ("Footbar") com Fontes e Toques Minúsculos
* **Tela**: Rodapé de Atividades e Telas SAP (`lib/main.dart` - `_buildFootbar`).
* **Evidência Visual**: Presente em todas as capturas operacionais (`02_atividades_gantt.png`, `04_atividades_tabela.png`).
* **Impacto**: Alto índice de toques errados; textos ilegíveis sob luminosidade solar; botões abaixo de 36px de altura com fonte de 9px.
* **Causa Provável**: Estilização ad-hoc com valores literais `fontSize: 9` e `size: 20` para "caber" na barra.
* **Severidade**: **CRÍTICO**
* **Solução Sugerida**: Implementar `NavigationBar` nativa com altura mínima de 64px, touch target de 48 × 48 px e tipografia de 12px.

### Problema 04: Drawer Lateral Desorganizado com 27 Itens Consecutivos
* **Tela**: Menu Lateral Geral (`lib/main.dart` - `_buildDrawer`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/00_drawer_navegacao.png`.
* **Impacto**: O operador perde tempo rolando uma lista interminável para achar funções essenciais de campo.
* **Causa Provável**: Lista flat contendo todos os módulos do sistema sem diferenciação de perfil ou frequência.
* **Severidade**: **CRÍTICO**
* **Solução Sugerida**: Agrupar em 4 categorias expansíveis ("Operação", "SAP", "Engenharia", "Sistema") e colocar os 5 módulos principais na barra inferior fixa.

### Problema 05: Barra de Filtros Horizontal com Dropdowns Espremidos
* **Tela**: Cabeçalho de Atividades (`lib/widgets/filter_bar.dart`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/03_atividades_planner.png`.
* **Impacto**: Exige rolagem lateral constante para ajustar filtros; ícones de limpar filtro com área de toque de 16px.
* **Causa Provável**: `SingleChildScrollView(scrollDirection: Axis.horizontal)` empilhando dezenas de `DropdownButton`.
* **Severidade**: **CRÍTICO**
* **Solução Sugerida**: Substituir por um botão único `[Filtrar (N)]` que dispara uma `ModalBottomSheet` ergonômica com chips de seleção.

### Problema 06: Diálogos Modais Sobrepostos pelo Teclado Virtual
* **Tela**: Detalhes da Tarefa (`task_detail_dialog.dart`), Vínculo de Nota (`nota_sap_selection_dialog.dart`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/05_atividades_detalhes.png`.
* **Impacto**: O operador clica para digitar uma observação ou apontamento e os botões "Salvar" / "Confirmar" somem atrás do teclado.
* **Causa Provável**: Utilização de `AlertDialog` centralizado sem ajuste de `viewInsets` ou sem conversão para bottom sheet expansível.
* **Severidade**: **ALTO**
* **Solução Sugerida**: Migrar diálogos de edição para `showModalBottomSheet(isScrollControlled: true)` com barra de ação ancorada no teclado.

### Problema 07: Apontamento de Horas SAP Estruturado como Planilha
* **Tela**: Horas SAP (`lib/widgets/horas_sap_screen.dart`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/09_horas_apontamento.png`.
* **Impacto**: Dificuldade para o encarregado apontar horas da equipe no fim do expediente com o celular; campos numéricos difíceis de selecionar.
* **Causa Provável**: Interface de lançamento em linha de tabela direta.
* **Severidade**: **ALTO**
* **Solução Sugerida**: Layout de "Cartão de Horas do Dia", permitindo seleção do executor, preenchimento das horas com teclado numérico e confirmação rápida.

### Problema 08: Falta de Feedback Visual Claro do Estado Offline e Sincronização
* **Tela**: Global (`SyncService` e AppBar).
* **Evidência Visual**: Ícone de sincronização sutil no canto superior direito.
* **Impacto**: O operador em campo sem 4G não sabe se sua foto ou confirmação de ordem foi salva com sucesso no banco local ou se foi perdida.
* **Causa Provável**: Ausência de badge de status de sincronização no próprio cartão da atividade.
* **Severidade**: **ALTO**
* **Solução Sugerida**: Inserir banner contextual "Modo Offline — 3 alterações pendentes" e ícone de relógio cinza em cada item não sincronizado.

### Problema 09: Checklists com Checkboxes Próximos Demais e Fotos Escondidas
* **Tela**: Checklist Operacional (`lib/widgets/checklist_screen.dart`).
* **Evidência Visual**: Análise do código de renderização de itens de verificação.
* **Impacto**: Alto risco de marcar "Conforme" quando a intenção era "Não Conforme"; atrito para anexar evidência fotográfica do defeito.
* **Causa Provável**: Uso de `CheckboxListTile` compacto com botões de anexo em menu secundário.
* **Severidade**: **ALTO**
* **Solução Sugerida**: Estrutura de botões segmentados largos: `[ CONFORME ]` `[ NÃO CONFORME ]` `[ N/A ]` e botão de câmera em destaque.

### Problema 10: Concentração Excessiva de Ações no Topo da Tela (Zona Inalcançável)
* **Tela**: Global (`TopBar` de `lib/main.dart`).
* **Evidência Visual**: Todas as telas capturadas (`01_dashboard.png`, `08_frota_veiculos.png`).
* **Impacto**: Obriga o uso de duas mãos para alternar telas, aplicar filtros ou pesquisar; risco de queda do aparelho em campo.
* **Causa Provável**: Arquitetura herdada da web com menu, busca, sincronização e ações agrupadas no topo.
* **Severidade**: **ALTO**
* **Solução Sugerida**: Transferir as 3 ações mais usadas para a base da tela ou através de um Floating Action Button (FAB).

### Problema 11: Inconsistência Cromática nos Status das Atividades
* **Tela**: Atividades, Demandas, GTD.
* **Evidência Visual**: `04_atividades_tabela.png` e `08_frota_veiculos.png`.
* **Impacto**: Confusão visual; a mesma situação ("Aguardando Aprovação") aparece em azul em um módulo e em amarelo em outro.
* **Causa Provável**: Definições locais de cores em múltiplos widgets em vez de um seletor unificado de tema.
* **Severidade**: **MÉDIO**
* **Solução Sugerida**: Centralizar mapeamento de status em `AppColors.statusColor(statusEnum)`.

### Problema 12: Contraste Insuficiente sob Luminosidade Solar Direta
* **Tela**: Global (Textos secundários e bordas de cards).
* **Evidência Visual**: `01_dashboard.png` (subtítulos e tags cinzas).
* **Impacto**: Em campo aberto, os textos em `Colors.grey[500]` e `Colors.grey[600]` desaparecem completamente.
* **Causa Provável**: Design testado em monitores de escritório com iluminação controlada.
* **Severidade**: **MÉDIO**
* **Solução Sugerida**: Elevar a escala de contraste para o padrão mínimo WCAG AAA (7:1) nos elementos operacionais críticos.

### Problema 13: Ausência de Atalho Rápido para Captura de Evidências Fotográficas
* **Tela**: Álbuns e Atividades (`media_albums_screen.dart`, `task_detail_dialog.dart`).
* **Evidência Visual**: Falta de botão primário de câmera nas telas principais.
* **Impacto**: Para tirar uma foto de um transformador ou serviço concluído, o operador precisa de 5 a 6 cliques.
* **Causa Provável**: O upload de mídia é tratado como anexo secundário em vez de registro central de campo.
* **Severidade**: **MÉDIO**
* **Solução Sugerida**: Adicionar FAB de câmera contextual na visualização da atividade atual.

### Problema 14: Confirmação de Ordens SAP com Tabela Densa de Operações
* **Tela**: Confirmação de Ordens (`confirmacao_ordens_screen.dart`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/10_confirmacao_ordens.png`.
* **Impacto**: Técnico precisa rolar lateralmente para encontrar a caixa de texto de apontamento de texto explicativo da ordem.
* **Causa Provável**: Estrutura orientada a grid para exibição de múltiplas operações de uma ordem.
* **Severidade**: **ALTO**
* **Solução Sugerida**: Apresentação em lista tipo acordeão (uma operação por vez com expansão no toque).

### Problema 15: Mapas de Linhas de Transmissão com Painéis que Cobrem a Viewport
* **Tela**: Linhas de Transmissão (`transmission_line_screen.dart`).
* **Evidência Visual**: Análise da sobreposição de painéis no Flutter Map.
* **Impacto**: Ao tocar em uma torre para inspecionar o vão, o card de detalhes abre cobrindo 80% do mapa, impedindo a visualização da linha.
* **Causa Provável**: Cards de dados desenhados com altura fixa de 400px.
* **Severidade**: **MÉDIO**
* **Solução Sugerida**: Implementar BottomSheet recolhível (`DraggableScrollableSheet`) com altura inicial de 15% (apenas nome da torre) e expansível para 70% sob demanda.

### Problema 16: Campos de Formulário sem Tipo de Teclado Específico
* **Tela**: Demanda Form, Task Form, Cadastro de Frota.
* **Evidência Visual**: Análise dos `TextFormField` nas telas de formulário.
* **Impacto**: O usuário precisa tocar repetidamente no botão `?123` do teclado virtual para digitar números de OS, placas ou datas.
* **Causa Provável**: Omissão da propriedade `keyboardType: TextInputType.number` nos campos numéricos.
* **Severidade**: **MÉDIO**
* **Solução Sugerida**: Configurar tipos de teclado adequados em todos os formulários (`number`, `phone`, `emailAddress`, `datetime`).

### Problema 17: Truncamento Severo de Nomes de Ativos e Subestações
* **Tela**: Atividades, SIs, Notas SAP.
* **Evidência Visual**: `04_atividades_tabela.png` e `11_notas_sap.png`.
* **Impacto**: O operador não sabe se a tarefa é na "SE Miracema - TR-01" ou "SE Miracema - TR-02" porque o texto é cortado como "SE Miracema - ...".
* **Causa Provável**: Uso de `maxLines: 1` e `TextOverflow.ellipsis` em containers com largura restrita.
* **Severidade**: **ALTO**
* **Solução Sugerida**: Permitir `maxLines: 2` com quebra de linha inteligente nos títulos dos cartões mobile.

### Problema 18: Planner Semanal Inviável para Arrastar e Soltar no Toque
* **Tela**: Planner de Atividades (`planner_view.dart`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/03_atividades_planner.png`.
* **Impacto**: Tentativas de arrastar tarefas entre dias disparam o scroll horizontal da página por conflito de gestos.
* **Causa Provável**: Mecanismo de drag-and-drop concebido para cursor do mouse em desktop.
* **Severidade**: **ALTO**
* **Solução Sugerida**: No mobile, desativar drag-and-drop e utilizar ação no card: "Reagendar para..." com seleção rápida de data.

### Problema 19: Dashboard Geral com Gráficos Desprovidos de Interatividade Tátil
* **Tela**: Dashboard Geral (`dashboard_screen.dart`).
* **Evidência Visual**: `docs/mobile_audit/screenshots/01_dashboard.png`.
* **Impacto**: Gráficos de pizza e barras com fatias finas que não permitem toque preciso para filtrar; legendas empurradas para fora da tela.
* **Causa Provável**: Configuração de `fl_chart` com dimensões fixas voltadas para visualização em monitor widescreen.
* **Severidade**: **MÉDIO**
* **Solução Sugerida**: No mobile, priorizar cards numéricos diretos (KPIs) e gráficos de barras horizontais simples com legendas verticais.

### Problema 20: Descontinuidade de Sessão e Falta de "Pull-to-Refresh"
* **Tela**: Global.
* **Evidência Visual**: Ausência de `RefreshIndicator` envolvendo as listas móveis.
* **Impacto**: O técnico não possui o gesto universal mobile de puxar a lista para baixo para forçar atualização ou sincronização com a nuvem.
* **Causa Provável**: Telas estruturadas com botões discretos de "recarregar" no topo.
* **Severidade**: **MÉDIO**
* **Solução Sugerida**: Envolver todas as listas mobile em `RefreshIndicator` que aciona `SyncService.syncNow()`.

---

## TOP 10 QUICK WINS

Alterações cirúrgicas de alto impacto perceptível e baixa complexidade:

1. **Aumentar o Rodapé Mobile**: Ajustar `_buildFootbar` em `lib/main.dart` para altura de 56px, ícones de 24px e textos de 11-12px (eliminar fontes de 9px).
2. **Adicionar `RefreshIndicator` Global**: Permitir gesto de arrastar para baixo (*Pull-to-Refresh*) nas listas de tarefas, equipes e SAP.
3. **Ajustar Tipos de Teclado Virtual**: Adicionar `keyboardType: TextInputType.number` nos campos de Nota SAP, Ordem SAP, Horas e Horímetro.
4. **Substituir Ícones de Linha em Tabelas**: Aumentar padding dos botões de ação para garantir touch target mínimo de 44 × 44 px.
5. **Permitir Quebra de Linha em Títulos Críticos**: Trocar `maxLines: 1` por `maxLines: 2` em nomes de tarefas, ativos e subestações.
6. **Elevar Contraste dos Textos Secundários**: Substituir `Colors.grey[500]` por `Colors.grey[800]` no tema claro operacional.
7. **Adicionar Botão Flutuante (FAB) na Tela de Atividades**: Ação rápida e evidente para criação de nova tarefa ou apontamento.
8. **Banner de Modo Offline no Topo da Lista**: Exibir aviso claro quando o dispositivo estiver sem conexão com a contagem de itens locais.
9. **Desativar Drag-and-Drop em Celular**: Evitar conflito de gestos no Planner e Gantt quando a largura da tela for inferior a 768px.
10. **Aumentar Área de Toque nos Checklists**: Tornar a linha inteira do item clicável (`ListTile(onTap: ...)`), e não apenas a caixinha do checkbox.

---

## TOP 10 TELAS PRIORITÁRIAS PARA REDESIGN

Classificação das telas que devem ser redesenhadas primeiro, ponderando impacto operacional, frequência de uso e fricção atual:

| Ranking | Tela / Módulo | Justificativa Operacional | Frequência de Uso |
|:---:|---|---|:---:|
| **1º** | **Shell de Navegação Geral** (`lib/main.dart`) | Ponto de entrada de toda a aplicação; resolve o Drawer sobrecarregado e a ausência de barra inferior persistente. | Contínua |
| **2º** | **Atividades — Lista / Cards** (`task_table.dart`) | Núcleo do trabalho das equipes em campo; deve exibir o que executar com prioridade e botão de status imediato. | Diária |
| **3º** | **Home Operacional ("Meu Dia")** (Nova visão) | O operador precisa abrir o app e ver imediatamente: tarefas do dia, veículo alocado e equipe. | Diária |
| **4º** | **Detalhes da Tarefa** (`task_detail_dialog.dart`) | Onde o técnico consulta endereço, instruções, segurança e registra evidências; deve ser BottomSheet. | Diária |
| **5º** | **Checklist e APR** (`checklist_screen.dart`) | Bloqueante para segurança do trabalho em campo; deve ser ergonômico mesmo com luvas. | Diária |
| **6º** | **Programação / Agenda Diária** (`team_schedule_view.dart`) | Substituição do Gantt mensal por visão de agenda cronológica utilizável com uma mão. | Diária |
| **7º** | **Apontamento de Horas SAP** (`horas_sap_screen.dart`) | Fechamento diário de produtividade das equipes; alto risco atual de dados incorretos no SAP. | Diária |
| **8º** | **Notas e Ordens SAP** (`notas_sap_screen.dart`, `ordens_sap_screen.dart`) | Consulta de ordens de manutenção em trânsito; conversão de grid para cards informativos. | Frequente |
| **9º** | **Álbum de Evidências Fotográficas** (`media_albums_screen.dart`) | Registro comprobatório de serviços executados com compressão e sincronização rápida. | Diária |
| **10º** | **Chat e Comunicação Operacional** (`chat_view.dart`) | Alinhamento instantâneo entre o centro de operação e a equipe em campo. | Frequente |

---

## ÍNDICE DE EVIDÊNCIAS VISUAIS (SCREENSHOTS)

As evidências foram capturadas em resolução mobile nativa (390 × 844 px) e estão organizadas em `docs/mobile_audit/screenshots/`:

* `00_drawer_navegacao.png`: Drawer lateral com 27 itens sem categorização lógica.
* `01_dashboard.png`: Dashboard analítico com compressão de gráficos e perda de legibilidade de legendas.
* `02_atividades_gantt.png`: Gantt de atividades mensal com barras e textos microscópicos.
* `03_atividades_planner.png`: Planner semanal com colunas estreitas e filtros horizontais espremidos no topo.
* `04_atividades_tabela.png`: Tabela tabular desktop exibindo apenas 1 coluna e meia na tela de 390px.
* `05_atividades_detalhes.png`: Dialog modal centralizado com 8 abas horizontais e campos cortados pelo teclado.
* `06_equipes_lista.png`: Lista de equipes em cards verticais com botões de ação de 24px.
* `07_equipes_escala_gantt.png`: Escala mensal de equipe com colunas diárias de 22px inalcançáveis no toque.
* `08_frota_veiculos.png`: Visualização de veículos e status operacional.
* `09_horas_apontamento.png`: Tela de apontamento de horas estruturada em grade de planilha corporativa.
* `10_confirmacao_ordens.png`: Confirmação de ordens com tabela densa de operações técnicas.
* `11_notas_sap.png`: Tabela de Notas SAP com 14 colunas sofrendo severo corte lateral.
* `12_ordens_sap.png`: Listagem de ordens com status de liberação inacessível sem rolagem horizontal.
