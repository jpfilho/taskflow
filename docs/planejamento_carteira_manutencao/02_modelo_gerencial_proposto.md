# Documento 2 — Modelo Gerencial da Carteira de Manutenção

## 1. Princípios Fundamentais do Modelo

O modelo gerencial proposto para o **TaskFlow** parte de uma premissa básica: **gestão integrada sem bloqueio operacional**.

A equipe em campo e o planejador não devem ter sua rotina travada por exigências cadastrais prévias. O papel da solução gerencial é iluminar lacunas, calcular riscos e apontar desvios para tomada de decisão proativa.

---

## 2. Dimensões Independentes da Demanda

Uma demanda de manutenção no TaskFlow **não é definida por um único campo de status**. Ela navega simultaneamente em quatro dimensões ortogonais:

```
[ Dimensão 1: Ciclo de Vida SAP ]        --> Aberta (MSPN/MSPR) vs. Encerrada (MSEN/CONC)
[ Dimensão 2: Previsão Gerencial ]       --> Sem Previsão vs. Prevista (Mês/Ano)
[ Dimensão 3: Programação Operacional ]  --> Não Programada vs. Programada em Tarefa
[ Dimensão 4: Risco e Prazo ]            --> No Prazo, Risco, Posterior, Vencida, Sem Prazo
```

Essa separação dimensional é essencial para evitar armadilhas comuns onde "programar uma nota" sobrepõe sua previsão macro ou onde "concluir uma tarefa" esconde que a nota ainda está aberta no SAP.

---

## 3. Definição Formal das Categorias de Gestão

### 3.1 Carteira Pendente (Universo da Demanda Ativa)
* **Critério de Inclusão:** Notas SAP que estão ativas no ciclo de manutenção.
  * Status de sistema SAP contendo `MSPN` (Nota pendente) ou `MSPR` (Nota em processamento).
  * Ausência de indicadores de conclusão/encerramento no SAP (`CONC`, `ENCE`, `MSEN`, `CANC`).
* **Critério de Exclusão:** Notas tecnicamente encerradas ou canceladas no SAP (`status_sistema` contendo `MSEN`, `CONC`, `ENCE` ou `CANC`).
* **Nota Crítica sobre Tarefas Concluídas:** Se uma tarefa no TaskFlow foi concluída (`status = 'CONC'`), mas a Nota SAP continua aberta no SAP (`MSPR`), essa nota **permanece na carteira pendente com status operacional "Em Encerramento Técnico no SAP"**. Isso evita que demandas atendidas em campo sejam esquecidas sem baixa administrativa no ERP.

---

### 3.2 Previsibilidade Gerencial (Horizonte de Atendimento)
Determina quando a organização pretende atender a demanda, no horizonte tático mensal:

1. **Sem Previsão:**
   * Nota pendente que não possui previsão direta e não pertence a nenhum grupo ativo com previsão válida.
   * *Ação Gerencial:* Prioridade zero de triagem gerencial — precisa de horizonte definido.
2. **Com Previsão por Grupo Ativo (Herdada):**
   * Nota vinculada a um `notas_sap_grupos` com `status_grupo = 'ativo'` e com `mes_programacao_previsto` e `ano_programacao_previsto` preenchidos.
   * Todas as notas do grupo compartilham o mesmo mês de intervenção macro.
3. **Com Previsão Individual Direta:**
   * Nota que não pertence a um grupo, mas recebeu um mês/ano de previsão gerencial próprio (evolução proposta sem exigir a criação de grupo fictício de 1 única nota).
4. **Previsão Ultrapassada:**
   * Previsão cujo mês/ano é cronologicamente anterior ao mês/ano corrente e a nota ainda não foi executada/programada.

---

### 3.3 Programação Operacional (Alocação em Tarefas)
Reflete o vínculo da nota com a operação real de execução através da tabela [tasks_notas_sap](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/criar_tabela_notas_sap.sql#L43):

* **Não Programada:** A nota não possui nenhum registro em `tasks_notas_sap` OU todos os seus vínculos apontam para tarefas com `status = 'CANC'` (Cancelada).
* **Programada Operacionalmente:** A nota possui pelo menos um vínculo em `tasks_notas_sap` para uma tarefa em um dos status válidos do TaskFlow:
  * `PROG` (Programada com data, equipe e executores)
  * `RPAR` (Reprogramada Parcial)
  * `RPGR` (Reprogramada)
* **Em Execução:** Vinculada a tarefa com status `ANDA` (Em andamento no campo).
* **Executada / Concluída em Campo:** Vinculada a tarefa com status `CONC` (Concluída).

---

## 4. O Relacionamento Crítico: Previsão Mensal vs. Prazo Legal

### 4.1 A Regra de Não-Ficção de Datas
> [!IMPORTANT]
> Uma previsão informada como **"Março de 2027"** não é o dia 01/03/2027 nem o dia 31/03/2027. Ela representa um intervalo probabilístico de atendimento: `[01/03/2027 00:00:00 até 31/03/2027 23:59:59]`.

Portanto, ao confrontar um prazo diário exato (ex: `data_vencimento = 10/03/2027`) com uma previsão mensal (Março/2027), **o sistema não pode assumir que a demanda será atendida antes do dia 10**.

### 4.2 Matriz das 7 Situações de Prazo e Previsão

| Situação | Nome Gerencial | Condição Lógica | Interpretação Gerencial | Sinalização Visual |
| :---: | :--- | :--- | :--- | :---: |
| **SIT-1** | **Previsão Anterior ao Prazo** | Mês da previsão < Mês do prazo | A previsão atende confortavelmente com folga de pelo menos um mês inteiro. | 🟢 Verde (Compatível) |
| **SIT-2** | **Previsão no Mês do Prazo (Risco Temporal)** | Mês da previsão == Mês do prazo | **Atenção:** Como a previsão é mensal, a execução pode ocorrer após o dia exato do vencimento dentro daquele mês. | 🟡 Amarelo (Atenção / Incerteza) |
| **SIT-3** | **Previsão Posterior ao Prazo** | Mês da previsão > Mês do prazo | **Descumprimento Declarado:** O planejamento previu o atendimento para depois da data limite legal da nota. | 🔴 Vermelho (Violação Prevista) |
| **SIT-4** | **Prazo Vencido** | `data_vencimento < CURRENT_DATE` e nota pendente | Demanda pendente cuja data limite legal já expirou. | 🚨 Vermelho Escuro (Vencida) |
| **SIT-5** | **Sem Prazo Conhecido** | `data_vencimento IS NULL` | Nota sem prioridade ou sem regra de prazo aplicável no cadastro. | ⚪ Cinza (Inconformidade Cadastral) |
| **SIT-6** | **Previsão Ultrapassada** | Mês da previsão < Mês Corrente e pendente | O mês previsto no planejamento já encerrou e a nota não foi programada. | 🟠 Laranja (Inadimplência de Plano) |
| **SIT-7** | **Sem Previsão com Prazo Próximo** | Sem previsão AND `0 <= dias_restantes <= 60` | Demanda pendente com vencimento próximo que ainda não foi encaixada em nenhum plano. | ⚠️ Âmbar Pulsante (Urgência Tática) |

---

## 5. Dinâmica de Grupos de Previsão

O grupo de notas é a unidade fundamental de planejamento em lote. Para a visão gerencial, o grupo consolida:

1. **Prazo Mais Próximo do Grupo (Prazo Crítico):**
   $$\text{Prazo Crítico do Grupo} = \min(\text{data\_vencimento das notas pendentes do grupo})$$
2. **Avaliação de Risco do Grupo:**
   * Se **alguma** nota do grupo estiver na **SIT-3** (Previsão posterior ao prazo), o grupo inteiro entra em estado de **Risco Crítico**.
   * Se **alguma** nota estiver na **SIT-2** e nenhuma na SIT-3, o grupo está em **Atenção**.
   * Se todas as notas com prazo têm previsão anterior ao mês do vencimento, o grupo está **Compatível**.
3. **Comportamento com Notas Concluídas no Grupo:**
   * Quando uma nota do grupo é concluída ou encerrada, ela deixa de contar nas pendências do grupo, mas **permanece registrada no grupo** para preservação do histórico de agrupamento.
   * Quando 100% das notas do grupo forem concluídas, o sistema sugere o encerramento administrativo do grupo (`status_grupo = 'encerrado'`).

---

## 6. Histórico de Reprogramação e Rastreabilidade

* Qualquer alteração no mês/ano previsto gera automaticamente um evento na tabela [notas_sap_grupos_previsoes_hist](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/release_20261101_producao/sql/02_grupos_previsao.sql#L86).
* O modelo armazena:
  * `mes_anterior`, `ano_anterior`
  * `mes_novo`, `ano_novo`
  * `motivo` (justificativa da reprogramação)
  * `alterado_por` e `alterado_em`
* Isso permite apurar o índice de estabilidade do plano de manutenção (quantas vezes uma demanda foi adiada antes de ser programada).
