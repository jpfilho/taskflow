# AUDITORIA DE COMPONENTES E DESIGN SYSTEM — TASKFLOW MOBILE

Este documento detalha a auditoria em nível de componentes, elementos de interface, usabilidade tátil e tokens visuais do TaskFlow para telas de smartphones.

---

## 1. Touch Targets e Ergonomia de Toque (< 44 × 44 px)

As diretrizes do Android (Material Design) e Apple (Human Interface Guidelines) estabelecem como área mínima de toque **48 × 48 px** e **44 × 44 px**, respectivamente. Na operação em campo, onde técnicos utilizam luvas ou operam com uma mão em movimento, a área recomendada é de **48 a 56 px**.

### 1.1 Violações Críticas Encontradas

1. **Footbar Buttons (`lib/main.dart` - `_buildFootbar`)**:
   * *Dimensões reais*: Botões de navegação com altura total de 38px, ícones de `size: 20` e rótulos tipográficos com `fontSize: 9`.
   * *Touch Target*: ~36 × 32 px.
   * *Impacto*: Alto índice de toques errados entre botões adjacentes.
2. **Ações de Linha em Tabelas (`lib/widgets/task_table.dart`, `notas_sap_screen.dart`)**:
   * *Dimensões reais*: `IconButton` com `iconSize: 16` ou `18` e `padding: EdgeInsets.all(4)`.
   * *Touch Target*: ~24 × 24 px.
   * *Impacto*: Praticamente impossível de tocar sem zoom ou em ambiente de campo.
3. **Seletor de Datas e Dias no Gantt (`lib/widgets/team_schedule_view.dart`)**:
   * *Dimensões reais*: Colunas de dias com largura de 22 a 28px no grid de escala.
   * *Touch Target*: 24 × 30 px.
   * *Impacto*: Impossível selecionar um dia específico da escala com o polegar.
4. **Chips de Filtro Horizontal (`lib/widgets/filter_bar.dart`)**:
   * *Dimensões reais*: Chips com altura de 28px, texto de 11px e ícone de exclusão "x" de 12px.
   * *Touch Target do "X"*: ~16 × 16 px.
   * *Impacto*: O usuário tenta remover o filtro e acaba clicando no chip inteiro, reabrindo o dropdown.
5. **Checkbox de Conclusão de Checklist (`lib/widgets/checklist_screen.dart`)**:
   * *Dimensões reais*: Checkbox com escala padrão de 18px sem preenchimento expansivo na linha (sem `ListTile.dense = false`).
   * *Touch Target*: 28 × 28 px.

---

## 2. Tipografia e Escala Tipográfica Mobile

### 2.1 Diagnóstico Atual
* **Falta de Escala Tipográfica Padronizada**: O projeto não utiliza uma hierarquia tipográfica unificada em `Theme.of(context).textTheme`. Encontram-se centenas de definições diretas de `TextStyle(fontSize: X, fontWeight: Y)` espalhadas nos widgets.
* **Textos Excessivamente Pequenos**:
  * `fontSize: 9` e `10`: Utilizados em legendas, datas, rodapés e tags de status de SAP. Em tela de celular sob luz solar direta, tornam-se completamente ilegíveis.
  * `fontSize: 11` e `12`: Utilizados como texto de corpo em tabelas e cards secundários, gerando esforço visual desnecessário.
* **Truncamento Agressivo (`overflow: TextOverflow.ellipsis`)**:
  * Títulos de atividades, nomes de subestações e descrições de falhas são cortados após 15 a 20 caracteres sem possibilidade de expansão por toque.

### 2.2 Proposta de Escala Tipográfica Mobile Recomendada

| Nome do Token | Tamanho (sp/pt) | Altura de Linha | Peso | Uso Recomendado no Mobile |
|---------------|-----------------|-----------------|------|---------------------------|
| `Display` | 24 | 32 | Bold (700) | Títulos principais de tela (ex: "Minhas Atividades") |
| `Title Large` | 18 | 24 | SemiBold (600) | Títulos de cards e seções |
| `Title Medium`| 16 | 22 | SemiBold (600) | Nome da tarefa, código do ativo |
| `Body Large`  | 16 | 24 | Regular (400) | Textos de leitura e inputs de formulário |
| `Body Medium` | 14 | 20 | Regular (400) | Descrições secundárias, observações |
| `Label`       | 12 | 16 | Medium (500) | Chips de status, badges, datas |
| `Caption Min` | 11 | 14 | Regular (400) | Apenas carimbos de hora auxiliares (**mínimo absoluto**) |

---

## 3. Tabelas vs. Padrões de Listas/Cards no Mobile

A maioria dos módulos críticos do TaskFlow (Atividades, Notas SAP, Ordens SAP, SIs, ATs, Apontamento de Horas) foi estruturada em torno de **tabelas bidimensionais** corporativas com 6 a 15 colunas.

### 3.1 Classificação das Tabelas do Sistema

| Tabela / Tela | Colunas Médias | Diagnóstico Mobile | Padrão Mobile Recomendado |
|---------------|----------------|---------------------|---------------------------|
| `TaskTable` (Atividades) | 8 colunas | **INADEQUADA** | **Card de Atividade Operacional** com status no topo, equipe/veículo no corpo e botão de ação rápida no rodapé. |
| `NotasSapScreen` | 14 colunas | **INADEQUADA** | **Card de Nota SAP** com Número da Nota em destaque, tipo de nota, subestação e botão "Vincular à Tarefa". |
| `OrdensSapScreen` | 12 colunas | **INADEQUADA** | **Card de Ordem** com status de liberação, tipo de manutenção e lista de operações associadas. |
| `HorasSapScreen` | 7 colunas | **INADEQUADA** | **Card de Apontamento Diário** com horas normais/extras e aprovação em um toque. |
| `SisSapScreen` | 10 colunas | **INADEQUADA** | **Card de Intervenção** com período de bloqueio elétrico e status ONS. |
| `AtsSapScreen` | 9 colunas | **INADEQUADA** | **Card de Autorização** com assinaturas pendentes e validade temporal. |
| `TeamScheduleView` | 31 colunas (dias) | **INADEQUADA** | **Agenda Diária / Semanal Vertical** com seletor de dia em carrossel superior (chips). |
| `FleetScheduleView`| 31 colunas (dias) | **INADEQUADA** | **Visão de Frota por Status** (Disponível, Em Manutenção, Em Campo). |

---

## 4. Formulários e Modais de Entrada de Dados

### 4.1 Problemas de Preenchimento em Celular
1. **Diálogos Centralizados (`AlertDialog` e `Dialog`)**:
   * O sistema utiliza diálogos padrão para edição de tarefas (`TaskFormDialog`), seleção de notas (`NotaSapSelectionDialog`) e seleção de ordens (`OrdemSelectionDialog`).
   * *Problema*: Na tela de 390px, esses diálogos possuem margens laterais de 24px, sobrando apenas ~340px de largura. Quando o teclado virtual abre, 50% da altura da tela é ocupada, deixando apenas ~250px visíveis. O botão de confirmar/salvar fica escondido abaixo do teclado sem rolagem automática.
2. **Falta de Seletores Nativos e Tipos de Teclado Adequados**:
   * Campos numéricos (código de notas, horímetros de veículos, horas trabalhadas) abrem teclado de texto completo (`text`), exigindo que o operador alterne manualmente para o teclado numérico.
   * Seletores de data usam calendário desktop complexo em vez do seletor em carrossel ou modal tátil.
3. **Formulários Excessivamente Longos sem Divisão em Passos**:
   * O cadastro de demandas e tarefas tem mais de 15 campos contínuos em coluna única. O operador perde a noção de onde está e quais campos são estritamente obrigatórios.

---

## 5. Cards: Diagnóstico de Inconsistências

Na auditoria foram identificadas mais de 6 variações independentes de cards no código:
1. `Card` nativo com `elevation: 1` e `borderRadius: 4`.
2. `Container` com `BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [...])`.
3. `Container` com borda cinza fina `Border.all(color: Colors.grey.shade300)` sem sombra.
4. Cards com fundo cinza escuro no modo dark sem borda de contraste.
5. Cartões com padding interno variando aleatoriamente entre 6px, 8px, 12px e 16px.

**Necessidade**: Padronização através de um componente único `TFCard` / `MobileTaskCard` com raio fixo de 12px, elevação sutil e espaçamento interno padronizado de 12px a 16px.

---

## 6. Cores, Contraste e Operação sob Sol

* **Cores de Status Inconsistentes**:
  * Status "Pendente": Em algumas telas é âmbar (`Colors.amber`), em outras é cinza (`Colors.grey`) e em outras é laranja (`Colors.orange`).
  * Status "Concluído": Verde claro sem contraste suficiente em fundo branco sob luminosidade forte.
  * Status "Atrasado / Impedimento": Vermelho com fundo vermelho claro, que em telas com reflexo solar parece um bloco apagado.
* **Índice de Contraste WCAG**:
  * Vários textos com cor `Colors.grey[600]` sobre fundo cinza claro `Colors.grey[100]` falham no teste de contraste mínimo de 4.5:1 exigido para legibilidade operacional.

---

## 7. Comunicação de Estado Offline-First e Sincronização

O TaskFlow possui robusta sincronização SQLite local (`SyncService`), porém a interface mobile peca na comunicação visual:
* **Banner Offline Quase Invisível**: O estado desconectado é sinalizado apenas por um pequeno ícone no canto superior direito da TopBar (onde a mão não alcança e o olho raramente repara).
* **Falta de Indicador por Registro**: O técnico não sabe se a foto ou o checklist que acabou de registrar já foi transmitido para o Supabase ou se está na fila local do SQLite aguardando rede 4G.
* **Ação de Forçar Sincronização**: Oculta dentro do menu de Configurações, quando deveria ser acessível por gesto de *Pull-to-Refresh* nativo no topo da lista.
