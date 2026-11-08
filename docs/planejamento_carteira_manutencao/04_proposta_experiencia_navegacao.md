# Documento 4 — Proposta de Experiência do Usuário e Navegação Integrada

## 1. Diretriz de Design: Reutilização sem Redundância

O TaskFlow já possui componentes visuais consolidados: o [NotasSAPView](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/notas_sap_view.dart), o [PlanejamentoMacroView](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/planejamento_macro/planejamento_macro_view.dart) e o [NotasSAPDashboardView](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/notas_sap_dashboard_view.dart).

A proposta de UX **não cria um novo módulo isolado**. Em vez disso, une esses três níveis em uma **experiência integrada de funil de gestão**, onde o usuário transita naturalmente do número consolidado da diretoria até a porca e parafuso em campo.

---

## 2. Arquitetura em 3 Níveis de Gestão

```
┌────────────────────────────────────────────────────────────────────────┐
│ NÍVEL 1 — PAINEL EXECUTIVO DA CARTEIRA (Visão Diretoria / Gerência)    │
│  - Total Pendente  |  Cobertura Previsibilidade  |  Vencidas  |  Risco │
│  - Curva de Distribuição Mensal (Demanda vs. Capacidade)               │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (Drill-down por Mês ou Indicador)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ NÍVEL 2 — PAINEL TÁTICO DE PROGRAMAÇÃO (Visão Coordenador / Planejador) │
│  - Matriz Mensal de Atendimento (Carrossel de Meses)                   │
│  - Gestão dos Grupos de Notas (Priorização, Ajuste de Previsão)        │
│  - Fila de Demandas sem Previsão (Atribuição Rápida de Mês/Grupo)      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (Drill-down na Nota ou Grupo)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ NÍVEL 3 — VISÃO OPERACIONAL DE DETALHE (Visão Especialista / Equipe)   │
│  - Tabela/Cards de Notas SAP com Badge de Previsão e Risco             │
│  - Workspace de Análise Técnica (Materiais, Diagnóstico, Horas)        │
│  - Ação Direta de Criar Tarefa no TaskFlow                             │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detalhamento dos Níveis de Experiência

### 3.1 Nível 1 — Painel Executivo (Visão Gerencial)
* **Objetivo:** Responder em 5 segundos às perguntas da alta liderança:
  1. *Qual é o tamanho total do nosso passivo pendente hoje?*
  2. *Quanto dele já possui previsão de atendimento? (Taxa de Cobertura)*
  3. *O que está vencido ou com risco iminente de estourar o prazo?*
  4. *Qual é o cronograma de esforço (horas) previsto para os próximos 12 meses?*
* **Componentes:**
  * **Barra de KPIs Mestres:**
    * Card 1: **Carteira Pendente** (com subtítulo de Horas Estimadas).
    * Card 2: **Cobertura de Previsibilidade** (barra de progresso com meta de 100%).
    * Card 3: **Demandas sem Previsão** (com contador de demandas com prazo próximo).
    * Card 4: **Vencidas & Risco de Violação** (soma de SIT-4 e SIT-3).
    * Card 5: **Taxa de Programação Operacional** (% já alocado em tarefas).
  * **Gráfico de Demanda Mensal:** Histograma empilhado dos próximos 12 a 24 meses, combinando quantidade de notas, horas estimadas e cores de risco de prazo.
  * **Linha de Capacidade Operacional:** Linha horizontal de capacidade máxima utilizável de horas das equipes (permitindo ver meses sobrecarregados).

---

### 3.2 Nível 2 — Painel Tático (Evolução do Planejamento Macro)
* **Objetivo:** Permitir ao planejador equilibrar a carteira mês a mês.
* **Componentes:**
  * **Carrossel de Meses Aperfeiçoado:** Navegação por abas: `Todos`, `Atrasados / Ultrapassados`, `Sem Previsão`, seguido pelos meses cronológicos (`Nov/26`, `Dez/26`, `Jan/27`...).
  * **Seção de Grupos do Mês:**
    * Cards expansíveis dos grupos previstos para aquele mês.
    * Indicadores visuais: Quantidade de Notas, Horas, Status de Programação (Não programado, Parcial, Total) e **Tag de Risco de Prazo** (ex: "🔴 Contém nota com vencimento anterior ao mês").
  * **Gaveta Tática de Demandas sem Previsão (Novo):**
    * Aba lateral retrátil exibindo as notas pendentes que não têm grupo nem previsão.
    * Ação de arrastar ou botão de seleção rápida: *"Mover notas selecionadas para o mês X"* ou *"Criar novo grupo com estas notas"*.

---

### 3.3 Nível 3 — Visão Operacional (Tabela e Cards de Notas SAP)
* **Objetivo:** Trabalho cirúrgico nas notas individuais.
* **Aperfeiçoamento na Tabela Existente ([notas_sap_view.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/notas_sap_view.dart)):**
  * **Novas Colunas Integradas:**
    * **Coluna "Previsão":** Exibe o mês/ano previsto (com ícone indicando se é herdada de grupo ou direta) e badge de situação (Compatível, Risco ou Posterior).
    * **Coluna "Grupo":** Nome do grupo ativo ao qual a nota pertence (com clique para abrir o grupo).
  * **Ação em Lote:** Permite selecionar múltiplas notas com checkbox e acionar:
    * *"Atribuir Previsão Mensal"*
    * *"Vincular a Grupo Existente"*
    * *"Criar Tarefa de Programação"*

---

## 4. Matriz de Filtros Globais e Sincronização

Os filtros aplicados em qualquer nível devem persistir e propagar:

| Filtro | Opções / Tipo | Impacto no Painel Executivo | Impacto no Painel Tático | Impacto na Tabela de Notas |
| :--- | :--- | :--- | :--- | :--- |
| **Regional / Divisão** | Dropdown hierárquico | Recalcula KPIs e gráfico para a regional | Filtra grupos e meses da regional | Lista apenas notas dos centros da regional |
| **Segmento** | Subestação, Linhas, etc. | Recalcula capacidade e demanda do segmento | Exibe planejamento do segmento | Lista notas do segmento |
| **Centro de Trabalho** | Multi-seleção | Foco na capacidade do centro | Grupos de responsabilidade do centro | Notas do centro de trabalho |
| **Situação de Previsão** | Todas / Com Previsão / Sem Previsão | Filtra totais | Alterna abas | Filtra linhas da tabela |
| **Risco de Prazo** | Vencidas / Violação Prevista / Risco Mês / Compatível | Destaca coluna de alerta | Filtra grupos com aquele perfil de risco | Lista apenas notas na situação selecionada |

---

## 5. Fluxo de Interação de Drill-Down

```
[ Usuário clica no KPI "Notas com Violação Prevista: 14" ]
                          │
                          ▼
[ O sistema aplica automaticamente o filtro Situação = SIT-3 ]
                          │
                          ▼
[ A tela transiciona para a Tabela de Notas com os 14 registros filtrados ]
                          │
                          ▼
[ Cada linha exibe: Nota, Equipamento, Vencimento: 15/02/2027, Previsão: 05/2027 (Posterior!) ]
                          │
                          ▼
[ Botão de Ação Rápida: "Ajustar Previsão para 01/2027" ou "Antecipar Grupo" ]
```
