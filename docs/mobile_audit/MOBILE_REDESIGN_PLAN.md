# PLANO ESTRATÉGICO DE REDESIGN — TASKFLOW MOBILE

Este documento estabelece o plano estruturado de modernização da experiência mobile do TaskFlow, definindo a arquitetura de componentes, matriz de prioridades e o roadmap sequencial de implementação.

---

## 1. Princípio Arquitetural: Desktop vs. Mobile

| Dimensão | Versão Desktop / Web | Versão Mobile (Smartphones) |
|---|---|---|
| **Papel Principal** | Planejamento, Gestão Estratégica, Análise de Dados | Execução em Campo, Consulta Rápida, Registro Operacional |
| **Padrão de Layout** | Múltiplas colunas, Gráficos Gantt 30 dias, Tabelas densas | Fluxo vertical (coluna única), Cards operacionais, Timeline diária |
| **Dispositivo de Entrada** | Teclado físico, Mouse com ponteiro e hover | Toque com uma mão, polegar, possibilidade de luvas |
| **Ambiente de Uso** | Escritório, monitor grande, rede corporativa cabeada/Wi-Fi | Luz solar direta, movimento, 3G instável ou offline |
| **Navegação** | Sidebar retrátil lateral fixa, Breadcrumbs, Topbar densa | Bottom Navigation Bar (5 destinos), Floating Action Button, BottomSheets |
| **Filtros** | Barra horizontal persistente com 8 a 12 selects | Botão de filtro que abre ModalBottomSheet arrastável |
| **Diálogos** | AlertDialog centralizado com 800px e abas | Fullscreen Sheet ou BottomSheet com botão de ação fixo na base |

---

## 2. Nova Arquitetura de Componentes Mobile Proposta

Para não duplicar regras de negócio nem alterar a versão desktop consolidada, a arquitetura mobile deve ser implementada com componentes especializados consumindo os mesmos serviços (`TaskService`, `SyncService`, `ChatService`):

```
lib/mobile/
├── core/
│   ├── theme/
│   │   ├── mobile_theme.dart          # Escala tipográfica, cores operacionais de alto contraste
│   │   └── mobile_touch_targets.dart  # Constantes de tamanho mínimo (48x48, 56x56)
│   └── widgets/
│       ├── mobile_app_bar.dart        # AppBar enxuta com status de conexão e busca rápida
│       ├── mobile_bottom_bar.dart     # Barra inferior com 5 abas ergonômicas
│       ├── mobile_card.dart           # Card base padronizado (raio 12px, padding 14px)
│       ├── mobile_status_chip.dart    # Chip de status com alto contraste sob sol
│       ├── mobile_filter_sheet.dart   # BottomSheet arrastável para filtros
│       ├── mobile_offline_banner.dart # Banner discreto mas visível com fila pendente
│       └── mobile_empty_state.dart    # Feedback visual para listas sem registros
├── modules/
│   ├── home/
│   │   ├── mobile_home_screen.dart    # Dashboard diário: Minhas tarefas, equipe, veículo
│   │   └── widgets/
│   │       ├── today_summary_card.dart
│   │       └── urgent_warnings_banner.dart
│   ├── tasks/
│   │   ├── mobile_task_list_screen.dart
│   │   ├── widgets/
│   │   │   ├── mobile_task_card.dart  # Card com código, OS, status e botão "Iniciar/Concluir"
│   │   │   └── mobile_task_detail_sheet.dart
│   ├── schedule/
│   │   ├── mobile_agenda_view.dart    # Agenda cronológica vertical (substitui Gantt mensal)
│   │   └── widgets/
│   │       └── day_carousel_selector.dart
│   ├── field_records/
│   │   ├── mobile_checklist_screen.dart # Checklists com botões grandes de Sim/Não/Foto
│   │   ├── mobile_photo_capture_screen.dart # Câmera rápida com compressão e georreferenciamento
│   │   └── mobile_timesheet_screen.dart # Apontamento de horas diário simplificado
│   └── sap/
│       ├── mobile_notas_list_screen.dart
│       └── mobile_ordens_list_screen.dart
└── shell/
    └── mobile_shell.dart              # Gerenciador de navegação e transições de tela
```

---

## 3. Matriz de Priorização de Problemas (P0 a P3)

| Tela / Módulo | Problema Identificado | Severidade | Impacto no Usuário | Frequência | Complexidade | Prioridade |
|---|---|---|---|---|---|---|
| **Navegação Shell** | Drawer com 27 itens sem categorização; Footbar quebrada em 3 telas com texto de 9px. | CRÍTICO | Alto (desorientação e atrito constante) | Contínua (toda sessão) | Média | **P0** |
| **Atividades (Tabela)** | Tabela tabular inavegável em 390px; colunas cortadas; scroll horizontal infinito. | CRÍTICO | Alto (impossível consultar tarefas em campo) | Diária | Média | **P0** |
| **Filtros Globais** | Barra horizontal no topo com 8 dropdowns cortados; touch target de 28px. | CRÍTICO | Alto (usuário não consegue filtrar sua equipe) | Frequente | Média | **P0** |
| **Gantt Atividades** | Gráfico de 30 dias em tela pequena; barras finas de 12px; rótulos sobrepostos. | CRÍTICO | Alto (inútil em smartphone de campo) | Diária | Alta | **P0** |
| **Notas & Ordens SAP** | Tabelas corporativas de 14 colunas espremidas na vertical. | CRÍTICO | Alto (erros operacionais de vínculo de OS) | Diária | Alta | **P0** |
| **Equipes (Escala)** | Gantt de escala mensal impossível de manipular no toque. | CRÍTICO | Alto (técnico não consegue ver sua escala) | Diária | Alta | **P0** |
| **Detalhes da Tarefa** | Dialog centralizado com 8 abas minúsculas; teclado cobre campos de salvar. | ALTO | Médio-Alto (perda de dados ao digitar) | Frequente | Média | **P1** |
| **Checklist & APR** | Checkboxes pequenos e próximos (<32px); botão de foto escondido. | ALTO | Alto (dificuldade de preenchimento com luvas) | Diária | Média | **P1** |
| **Apontamento Horas** | Tela tipo planilha em vez de cartão de ponto diário simplificado. | ALTO | Médio-Alto (erros de apontamento SAP) | Diária | Média | **P1** |
| **Evidências / Fotos** | Falta botão flutuante rápido de captura com compressão imediata. | ALTO | Médio (lentidão no upload em 3G) | Diária | Baixa-Média | **P1** |
| **Chat de Mensagens** | Campo de digitação não ancora corretamente acima do teclado no iOS. | ALTO | Médio (atrito na comunicação com base) | Frequente | Média | **P1** |
| **Dashboard KPIs** | Gráficos perdem legendas e sofrem text clipping lateral. | MÉDIO | Baixo-Médio (dificuldade de leitura rápida) | Ocasional | Baixa | **P2** |
| **Demandas (Lista)** | Ações de mudança de status exigem menu de contexto diminuto. | MÉDIO | Médio (lentidão para atualizar status) | Frequente | Baixa | **P2** |
| **Linhas Transmissão** | Card de torre sobrepõe o mapa inteiro na vertical. | MÉDIO | Médio (perda de contexto geográfico) | Ocasional | Média | **P2** |
| **Status Offline** | Falta de feedback visual em cada card indicando "Pendente de Sync". | MÉDIO | Médio (insegurança do técnico sobre envio) | Contínua | Baixa | **P2** |
| **Refinamentos Visuais** | Inconsistência de sombras, raios de borda e cores de status. | BAIXO | Baixo (apenas coerência estética) | Contínua | Baixa | **P3** |

---

## 4. Roadmap de Execução da Modernização

### FASE 1 — Fundamentos & Design System Mobile
* Definição de tokens de espaçamento (padding 8, 12, 16, 24px) e escala de touch target (mínimo 48px).
* Escala tipográfica mobile padronizada com pesos definidos.
* Paleta de cores operacionais de alto contraste (status, avisos, offline, sincronizado).
* Biblioteca de componentes atômicos: `TFCard`, `TFButton`, `TFStatusChip`, `TFBottomSheet`.

### FASE 2 — Shell de Navegação e Ergonomia de Campo
* Criação do `MobileShell` com verificação de largura de tela (`Responsive.isMobile`).
* Implementação da `MobileBottomBar` com 5 destinos prioritários.
* Drawer secundário simplificado, organizado em 4 categorias sanfonadas.
* Transição de filtros horizontais para `MobileFilterSheet` ancorada na base.

### FASE 3 — Home Operacional ("Hoje") & Módulo de Atividades
* Construção da tela inicial mobile: "Meu Dia" (tarefas atribuídas, veículo, equipe, pendências).
* Substituição de `TaskTable` em mobile por lista vertical de `MobileTaskCard`.
* Criação de BottomSheet para detalhes da atividade com ações principais na base ("Iniciar", "Pausar", "Concluir").

### FASE 4 — Programação e Agenda (Substituição do Gantt no Mobile)
* Criação da **Agenda Cronológica Vertical** com seletor de dia em carrossel horizontal de chips.
* Substituição do Gantt mensal de 30 dias em telas pequenas por visualização diária/semanal expansível.
* Cartões de escala de equipe e frota adaptados para visualização vertical.

### FASE 5 — Registros de Campo: Checklists, APR, Evidências e Horas
* Interface ergonômica de checklist com botões largos estilo "Sim / Não / Não Aplica".
* Captura de evidências fotográficas em um toque com botão flutuante (FAB).
* Apontamento de Horas SAP em formato de "Cartão de Ponto Diário".

### FASE 6 — Módulos SAP, Demandas e Gestão
* Cards operacionais para Notas SAP e Ordens SAP.
* Diálogo de seleção e vínculo de Nota/Ordem em ModalBottomSheet de tela cheia.
* Visualização simplificada de Demandas e Documentos.

### FASE 7 — Comunicação, Mapas e Refinamentos
* Ajuste do layout de chat mobile com ancoragem de teclado e balões otimizados.
* Controles compactos para mapas de linhas de transmissão.
* Indicador individual de status de sincronização offline por cartão.
