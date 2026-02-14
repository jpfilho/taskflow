# Análise: EDMUNDO no dia 07 de fevereiro — deve ter conflito?

## Cenário na imagem

- **BES (dia 07):** EDMUNDO está programado em duas tarefas de EXECUÇÃO:
  - Apoio instalação de medidor de qualidade de energia na 01Y2 (barra até dia 07)
  - Atender NM 11513522 (barra 06–07)
- **TSD (dia 07):** Tarefa **Retrofit CS 01K1** tem três executores: EDMUNDO, RICARDO, VINICIUS.
  - A **barra da subtarefa “EDMUNDO - Retrofit CS 01K1”** começa **somente no dia 10** (segmentos 10–14 e 19–28).
  - As barras de RICARDO e VINICIUS para a mesma tarefa cobrem o período 01–07 (e outros).

Ou seja: na própria tela, a programação **visual** de EDMUNDO em TSD para essa tarefa é **apenas a partir do dia 10**; no dia 07 ele não aparece em TSD.

---

## Regras de conflito (documentação)

1. **Conflito** = mesmo executor com atividade de **EXECUÇÃO** no **mesmo dia** em **mais de um local**.
2. **Período por executor:** Se a tarefa tem `executorPeriods`, só o período **daquele executor** conta; o período geral (`ganttSegments`) **não** é usado para esse executor.
3. **Vários executores sem executorPeriods:** Se a tarefa tem **mais de um executor** e **não** tem `executorPeriods` carregados, essa tarefa **não** é contada para conflito (evita assumir período geral para todos).
4. **Subtarefa:** Se a tarefa é subtarefa e o **pai** tem `executorPeriods` para o executor, usa-se **só o período do pai** para esse executor.

---

## Aplicação ao dia 07 para EDMUNDO

| Local | Conta para conflito? | Motivo |
|-------|----------------------|--------|
| **BES** | Sim | EDMUNDO tem EXECUÇÃO no dia 07 (duas tarefas em BES = um único local). |
| **TSD** | Não | Tarefa “Retrofit CS 01K1” tem vários executores. Se tiver `executorPeriods`: o período de EDMUNDO na imagem é a partir do dia 10 → dia 07 **não** está no período dele → não conta. Se **não** tiver `executorPeriods`: pela regra “vários executores sem executorPeriods” a tarefa **não** é contada para conflito. Em ambos os casos, TSD não entra para EDMUNDO no dia 07. |

Resultado: no dia 07, para EDMUNDO, só há **um local** (BES). Conflito exige **dois ou mais locais**.

---

## Conclusão

**EDMUNDO não deve ter conflito no dia 07 de fevereiro.**

- Ele está em **BES** no dia 07 (correto).
- Em **TSD**, para a tarefa Retrofit CS 01K1, a programação dele é a partir do dia 10; o dia 07 não faz parte do período de EDMUNDO nessa tarefa (seja por `executorPeriods` na tarefa pai, seja pela regra de não contar tarefa com vários executores sem períodos).
- Conflito só existe quando há execução no **mesmo dia** em **mais de um local**. Como no dia 07 só BES conta para EDMUNDO, **não há conflito**.

Se a interface ainda mostrar conflito (vermelho/tooltip) para EDMUNDO no dia 07, é inconsistente com a documentação e com o desenho das barras (EDMUNDO em TSD só a partir do dia 10). Nesse caso, vale checar:
- Se a tarefa “Retrofit CS 01K1” está vindo com `executorPeriods` preenchidos para EDMUNDO (ex.: API vs cache).
- Se a lista usada na detecção de conflito (`tasksForConflictDetection` / `widget.tasks`) é a mesma que alimenta as linhas expandidas por executor, para que a regra de período por executor e a de “vários executores sem executorPeriods” sejam aplicadas corretamente.
