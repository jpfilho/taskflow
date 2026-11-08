# Documento 3 — Catálogo de Indicadores e KPIs Gerenciais da Carteira

## 1. Visão Geral do Sistema de Indicadores

O objetivo do catálogo de KPIs é oferecer **visibilidade completa, auditabilidade estrita e rastreabilidade total**.

> [!IMPORTANT]
> **Regra de Ouro da Rastreabilidade:** Nenhum número no painel gerencial pode ser abstrato ou fechado. Cada indicador deve permitir o **drill-down em um clique**, abrindo exatamente a listagem das Notas SAP ou Grupos que compõem o valor exibido.

---

## 2. Catálogo Detalhado de KPIs

### KPI-01: Total de Notas Pendentes na Carteira
* **Objetivo:** Mensurar o passivo real de manutenção sob gestão.
* **Fórmula:**
  $$\text{Total Pendentes} = \text{COUNT}(ns.id) \quad \text{onde } ns.status\_sistema \in \text{Pendentes (MSPN, MSPR e } \notin \text{CONC, ENCE, CANC)}$$
* **Fonte de Dados:** View `public.notas_sap_com_prazo` (filtro `estaAberta = true`).
* **Granularidade:** Total, Regional, Divisão, Segmento, Centro de Trabalho, Local de Instalação.
* **Drill-down:** Filtra a tabela de notas com `status = 'abertas'`.

---

### KPI-02: Cobertura de Previsibilidade da Carteira (%)
* **Objetivo:** Indicador mestre de previsibilidade — mede a adesão ao planejamento macro.
* **Fórmula:**
  $$\text{Cobertura de Previsibilidade (\%)} = \left( \frac{\text{Qtd de Notas Pendentes com Previsão Válida}}{\text{Total de Notas Pendentes na Carteira}} \right) \times 100$$
* **Regra de Inclusão no Numerador:** Nota pendente pertencente a grupo ativo com mês/ano preenchido OU com previsão individual definida.
* **Meta Estratégica:** $100\%$ das notas pendentes com horizonte previsto.
* **Fonte de Dados:** `notas_sap_com_prazo` cruzado com `notas_sap_grupos_itens` e `notas_sap_grupos`.
* **Drill-down:** Filtra notas com `previsao = 'definida'` vs `previsao = 'sem_previsao'`.

---

### KPI-03: Demandas sem Previsão de Atendimento
* **Objetivo:** Identificar o "ponto cego" do planejamento (notas pendentes esquecidas sem data prevista).
* **Fórmula:**
  $$\text{Sem Previsão} = \text{COUNT}(ns.id) \quad \text{onde nota está pendente E não possui mês/ano previsto}$$
* **Impacto:** Alimenta a fila de priorização da gestão para alocação em grupos ou definição de mês.
* **Drill-down:** Abre a lista de notas com filtro rápido `Sem Previsão`.

---

### KPI-04: Horas Estimadas Pendentes na Carteira
* **Objetivo:** Quantificar o volume de esforço técnico necessário para esgotar o passivo de manutenção.
* **Fórmula:**
  $$\text{Total Horas Pendentes} = \sum nsa.estimativa\_horas \quad \text{para todas as notas pendentes com análise}$$
* **Tratamento de Dados Incompletos:** Notas sem análise técnica não possuem `estimativa_horas`. O indicador deve exibir:
  $$\text{Horas Calculadas} \quad (\text{com base em } X\% \text{ das notas com análise concluída})$$
  **Nunca assumir que falta de análise equivale a 0 horas.**

---

### KPI-05: Horas Estimadas em Demandas sem Previsão
* **Objetivo:** Mensurar o volume de esforço de trabalho que ainda não foi alocado em nenhum horizonte temporal.
* **Fórmula:**
  $$\sum nsa.estimativa\_horas \quad \text{para notas pendentes sem previsão e com estimativa}$$

---

### KPI-06: Notas Efetivamente Programadas em Tarefas
* **Objetivo:** Identificar o percentual da carteira que já transicionou do planejamento macro para o cronograma executivo.
* **Fórmula:**
  $$\text{Notas Programadas} = \text{COUNT}(\text{DISTINCT } tns.nota\_sap\_id) \quad \text{onde } t.status \in \{\text{'PROG', 'ANDA', 'CONC', 'RPAR', 'RPGR'}\}$$
* **Fonte:** [tasks_notas_sap](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/criar_tabela_notas_sap.sql#L43) JOIN [tasks](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/models/task.dart#L153).
* **Exclusão:** Tarefas canceladas (`t.status = 'CANC'`) são rigorosamente ignoradas.

---

### KPI-07: Taxa de Programação da Carteira (%)
* **Objetivo:** Aferir a conversão do backlog em trabalho executivo.
* **Fórmula:**
  $$\text{Taxa Programação (\%)} = \left( \frac{\text{Notas Pendentes Programadas em Tarefas Ativas}}{\text{Total de Notas Pendentes na Carteira}} \right) \times 100$$

---

### KPI-08: Demandas com Prazo Vencido (SIT-4)
* **Objetivo:** Destacar inadimplência regulatória/operacional consumada.
* **Fórmula:**
  $$\text{Notas Vencidas} = \text{COUNT}(ns.id) \quad \text{onde nota está pendente E } ns.dias\_restantes < 0$$
* **Fonte:** View `notas_sap_com_prazo`.
* **Sinalização:** Alerta crítico imediato com prioridade de ordenação no topo de qualquer listagem.

---

### KPI-09: Demandas com Risco de Violação de Prazo (SIT-3)
* **Objetivo:** Alerta precoce de descumprimento de prazo decorrente de previsão inadequada.
* **Fórmula:**
  $$\text{Previsão Posterior ao Prazo} = \text{COUNT}(ns.id) \quad \text{onde nota está pendente E } (\text{ano\_previsto} \times 12 + \text{mes\_previsto}) > (\text{ano\_vencimento} \times 12 + \text{mes\_vencimento})$$
* **Utilidade:** Permite ao coordenador antecipar a previsão antes que a nota vença.

---

### KPI-10: Demandas com Incerteza Temporal (SIT-2)
* **Objetivo:** Identificar notas cuja previsão está no mesmo mês do prazo legal, demandando programação nos primeiros dias do mês.
* **Fórmula:**
  $$\text{Previsão no Mês do Prazo} = \text{COUNT}(ns.id) \quad \text{onde } (\text{ano\_previsto} \times 12 + \text{mes\_previsto}) == (\text{ano\_vencimento} \times 12 + \text{mes\_vencimento})$$

---

### KPI-11: Demandas com Previsão Ultrapassada (SIT-6)
* **Objetivo:** Medir a quebra de plano de manutenção (o mês previsto já findou e a nota segue pendente e não programada).
* **Fórmula:**
  $$\text{Previsão Ultrapassada} = \text{COUNT}(ns.id) \quad \text{onde } (\text{ano\_previsto} \times 12 + \text{mes\_previsto}) < (\text{ano\_atual} \times 12 + \text{mes\_atual}) \text{ E não programada}$$

---

### KPI-12: Demandas sem Previsão com Prazo Crítico (SIT-7)
* **Objetivo:** Demandas desassistidas de planejamento com vencimento próximo (menos de 60 dias).
* **Fórmula:**
  $$\text{Sem Previsão Crítica} = \text{COUNT}(ns.id) \quad \text{onde Sem Previsão AND } 0 \le ns.dias\_restantes \le 60$$

---

### KPI-13 a KPI-16: Indicadores de Grupos de Previsão
* **KPI-13: Grupos Ativos:** Total de agrupamentos com `status_grupo = 'ativo'`.
* **KPI-14: Grupos sem Previsão:** Grupos ativos onde `mes_programacao_previsto IS NULL`.
* **KPI-15: Grupos com Prazo Crítico:** Grupos onde pelo menos uma nota possui `dias_restantes < 0` ou está na SIT-3.
* **KPI-16: Grupos Parcialmente Programados:** Grupos onde $0 < \text{notas programadas} < \text{total notas do grupo}$.

---

### KPI-17: Índice de Reprogramações Acumuladas
* **Objetivo:** Medir a estabilidade do planejamento.
* **Fórmula:**
  $$\text{Total Reprogramações} = \text{COUNT}(h.id) \quad \text{da tabela } public.notas\_sap\_grupos\_previsoes\_hist$$
* **Métrica Secundária:** Média de reprogramações por grupo ativo.

---

### KPI-18: Curva de Distribuição Mensal da Carteira
* **Objetivo:** Gráfico de distribuição do passivo de manutenção nos próximos 12 a 24 meses.
* **Eixos:**
  * **Eixo X:** Mês/Ano (ex: Nov/26, Dez/26, Jan/27, Fev/27...)
  * **Eixo Y:** Horas estimadas e Quantidade de Notas.
  * **Empilhamento de Cores:**
    * Verde: Notas já programadas em tarefas.
    * Azul: Notas com previsão, no prazo (SIT-1).
    * Amarelo: Notas com previsão no mês do prazo (SIT-2).
    * Vermelho: Notas com previsão posterior ao prazo (SIT-3).

---

### KPI-19: Cobertura da Análise Técnica Prévia
* **Objetivo:** Avaliar a qualidade dos dados técnicos antes da execução.
* **Fórmula:**
  $$\text{Taxa de Cobertura de Análise (\%)} = \left( \frac{\text{Notas com Análise Concluída ou em Análise}}{\text{Total de Notas Pendentes}} \right) \times 100$$
* **Reutilização:** Aproveita o modelo [NotaSapIndicadores](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/models/nota_sap_indicadores.dart#L96) já existente.

---

### KPI-20: Relação Demanda Prevista vs. Capacidade Operacional Disponível
* **Objetivo:** Avaliar se a quantidade de horas previstas para um determinado mês é exequível pelas equipes daquele centro de trabalho/regional.
* **Fórmula:**
  $$\text{Taxa de Ocupação da Capacidade (\%)} = \left( \frac{\text{Demanda Prevista de Horas no Mês}}{\text{Capacidade Operacional Disponível no Mês}} \right) \times 100$$
* **Capacidade Disponível:**
  $$\text{Capacidade (h)} = \text{Efetivo de Executores da Equipe} \times \text{Dias Úteis do Mês} \times 8\text{h} \times \text{Fator de Disponibilidade Utilizável (ex: 70\%)}$$
  *(Descontando férias, treinamentos e percentual alocado para manutenção de rotina).*
