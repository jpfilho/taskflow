# Documento 5 — Plano Estratégico de Implementação em Fases

## 1. Visão Geral da Estratégia de Implantação

Para garantir estabilidade, risco zero para a operação diária e entrega contínua de valor, o plano é estruturado em **6 fases incrementais**, com uma primeira entrega mínima (**MVP Gerencial**) imediatamente acionável.

> [!IMPORTANT]
> **Diretriz de Segurança:** Nenhuma alteração pode quebrar o fluxo operacional existente de notas, ordens ou tarefas. Toda evolução no banco de dados deve ser não-destrutiva e compatível com rollback.

---

## 2. O Menor Primeiro Incremento de Valor (MVP Gerencial)

A menor entrega capaz de responder imediatamente à alta gestão é a união da **Fase 1** e da **Fase 2**:
* Disponibilizar no topo do Planejamento Macro os indicadores de **Total de Notas Pendentes**, **Taxa de Cobertura de Previsibilidade (%)** e **Demandas sem Previsão**, permitindo clicar e filtrar as notas correspondentes.
* **Tempo de retorno de valor:** Imediato, sem qualquer impacto no banco nem alteração no fluxo de trabalho das equipes.

---

## 3. Detalhamento das Fases

### Fase 1 — Formalização do Modelo de Dados e Enriquecimento de Previsão
* **Objetivo:** Permitir que o sistema reconheça a previsão macro tanto via grupo quanto de forma direta na nota, e unificar o conceito de nota aberta/concluída.
* **Entregáveis:**
  1. Migration SQL adicionando colunas opcionais `mes_previsao` e `ano_previsao` em `notas_sap` (para notas não agrupadas) ou view consolidada `notas_sap_com_previsao`.
  2. Ajuste na view `notas_sap_com_prazo` para expor o grupo ativo e o mês/ano previsto consolidado.
  3. Equalização da regra `estaAberta` entre [nota_sap.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/models/nota_sap.dart#L88) e os dashboards.
* **Arquivos a Modificar:**
  * `supabase/migrations/20261103_carteira_previsao_consolidada.sql` (novo)
  * [nota_sap.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/models/nota_sap.dart)
  * [criar_view_notas_sap_com_prazo.sql](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/criar_view_notas_sap_com_prazo.sql)
* **Testes Necessários:** Testes unitários de parsing de status SAP; teste de consistência da view com notas agrupadas e não agrupadas.
* **Critérios de Aceite:** 100% das notas pendentes possuem um campo determinístico de previsão (valor real ou `null`).
* **Estratégia de Rollback:** Reverter a view para a versão anterior (`20260926_deduplicar_notas_sap_com_local.sql`).

---

### Fase 2 — Motor de Indicadores de Cobertura e Risco de Prazo
* **Objetivo:** Calcular os KPIs gerenciais de Cobertura (%), Violação de Prazo (SIT-3), Incerteza (SIT-2) e Previsão Ultrapassada (SIT-6).
* **Entregáveis:**
  1. Criação do serviço agregador `CarteiraManutencaoIndicadoresService` ou evolução de [nota_sap_backlog_service.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/services/nota_sap_backlog_service.dart).
  2. Implementação das 7 regras formais de correlação Previsão x Prazo em Dart/SQL.
  3. Testes com dados históricos reais.
* **Arquivos a Modificar:**
  * `lib/services/carteira_indicadores_service.dart` (novo)
  * [backlog_macro_models.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/models/backlog_macro_models.dart)
  * `test/carteira_indicadores_test.dart` (novo)
* **Testes Necessários:** Testes de borda: nota vencendo no dia 01 do mês previsto, no dia 28, nota sem prioridade, nota em grupo cancelado.
* **Critérios de Aceite:** O KPI de cobertura reflete rigorosamente a proporção matemática sobre a base total de notas abertas.
* **Estratégia de Rollback:** Desativação do serviço via feature flag sem impacto no restante do app.

---

### Fase 3 — Visão Integrada no Painel Tático (Planejamento Macro Expandido)
* **Objetivo:** Eliminar o ponto cego do planejamento macro, exibindo demandas fora de grupo e alertas de violação de prazo nos grupos.
* **Entregáveis:**
  1. Inclusão da aba/gaveta de **Demandas sem Previsão** no [PlanejamentoMacroView](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/planejamento_macro/planejamento_macro_view.dart).
  2. Badges de alerta de risco de prazo nos cards dos grupos (ex: "🔴 Risco Crítico de Prazo").
  3. Cards de KPIs de Cobertura e Violação no cabeçalho do painel.
* **Arquivos a Modificar:**
  * [planejamento_macro_view.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/planejamento_macro/planejamento_macro_view.dart)
  * [nota_sap_backlog_service.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/services/nota_sap_backlog_service.dart)
* **Testes Necessários:** Validação de responsividade (Desktop e Tablet); validação de drill-down.
* **Critérios de Aceite:** O usuário consegue ver a totalidade das notas pendentes na tela, agrupadas ou não.

---

### Fase 4 — Gestão Ativa e Ações em Lote na Carteira
* **Objetivo:** Permitir ao planejador agir rapidamente sobre notas desassistidas de previsão.
* **Entregáveis:**
  1. Ação em lote na tabela de notas: *"Atribuir Previsão Mensal em Lote"*.
  2. Dialog aprimorado de vinculação rápida a grupos ou criação de grupo a partir da seleção.
  3. Mecanismo de aviso caso o usuário selecione uma previsão posterior ao prazo da nota.
* **Arquivos a Modificar:**
  * [notas_sap_view.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/notas_sap_view.dart)
  * [nota_sap_grupo_service.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/services/nota_sap_grupo_service.dart)
* **Testes Necessários:** Teste de concorrência e idempotência nas operações em lote.
* **Critérios de Aceite:** Atribuir previsão a 50 notas selecionadas em menos de 2 segundos.

---

### Fase 5 — Painel Executivo e Histórico de Estabilidade
* **Objetivo:** Disponibilizar para diretores e gerentes o dashboard de alto nível com gráficos de tendência e curva de distribuição mensal.
* **Entregáveis:**
  1. Seção Executiva com gráfico de barras empilhadas (notas e horas por mês previsto nos próximos 12 a 24 meses).
  2. Relatório de índice de reprogramações (estabilidade do plano).
* **Arquivos a Modificar:**
  * [notas_sap_dashboard_view.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/notas_sap_dashboard_view.dart)
  * Novos widgets de gráficos em `lib/widgets/dashboard/`
* **Testes Necessários:** Teste de performance de renderização de gráficos com grandes volumes.
* **Critérios de Aceite:** Renderização suave em 60fps sem travas de interface.

---

### Fase 6 — Confrontação de Capacidade Operacional e Viabilidade
* **Objetivo:** Comparar horas de demanda previstas com a capacidade real de atendimento das equipes.
* **Entregáveis:**
  1. Cálculo de capacidade disponível por centro de trabalho com base no efetivo de executores e jornada.
  2. Indicador visual de taxa de ocupação da capacidade mensal no gráfico.
  3. Alerta de sobrecarga de capacidade (ex: Mês com 140% da capacidade alocada).
* **Arquivos a Modificar:**
  * `lib/services/capacidade_operacional_service.dart` (novo)
  * Integração com [horas_empregado_mes.dart](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/models/horas_empregado_mes.dart) e `equipe_service.dart`.
* **Testes Necessários:** Validação de dias úteis, feriados e multiplicadores de jornada.
* **Critérios de Aceite:** O coordenador identifica imediatamente os meses em que a demanda supera os recursos disponíveis.
