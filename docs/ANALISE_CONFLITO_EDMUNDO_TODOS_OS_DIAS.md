# Análise: EDMUNDO — todos os dias com atividade (fevereiro 2026)

## Resumo das atividades de EDMUNDO (com base na imagem e documentação)

| Local      | Tarefa(s) | Executores | Período de EXECUÇÃO (dias) |
|------------|-----------|------------|----------------------------|
| **BES**    | Apoio instalação de medidor de qualidade de energia na 01Y2 | EDMUNDO | 03 a 07 |
| **BES**    | Atender NM 11513522 - BES 11Y2 NÃO ATIVOU RELIG.AUTOMÁTICO | EDMUNDO | 06 a 07 |
| **TSD**    | Retrofit CS 01K1 (período específico de EDMUNDO) | EDMUNDO, RICARDO, VINICIUS | 10 a 14 e 19 a 28 (só EDMUNDO nesses dias) |
| **NEPTRFET** (OUTROS) | **Treinamento NR-35** | **EDMUNDO, FCO WILSON, DANILLO, JOSELIO, SERGIO** | Barra no Gantt ~ dias **17 a 20** (conferir `executorPeriods`) |

Regra de conflito: **conflito** = mesmo executor com EXECUÇÃO no **mesmo dia** em **mais de um local**. Um único local no dia = sem conflito.

### Regra quando não há período específico por executor (Treinamento NR-35)

- **Se a tarefa tem executorPeriods** para o executor: só o período específico desse executor é considerado para conflito.
- **Se a tarefa não tem executorPeriods** (ou não tem entrada para esse executor): **usar os dias da tarefa** (ganttSegments de EXECUÇÃO) — o executor está programado nesses dias e a tarefa conta para conflito. Ex.: **Treinamento NR-35** (vários executores, barra ~ 17–20): EDMUNDO conta em NEPTRFET nesses dias → nos dias **19 e 20** há conflito com TSD (Retrofit).

---

## Dia a dia (fevereiro 2026)

| Dia | Locais com atividade (EDMUNDO) | Conflito? | Motivo |
|-----|---------------------------------|-----------|--------|
| **01** | Nenhum (ou só outros executores em TSD) | **Não** | EDMUNDO não está em TSD no dia 01 (período dele no Retrofit começa no 10). |
| **02** | Idem | **Não** | Mesmo motivo. |
| **03** | BES | **Não** | Apenas um local (BES). |
| **04** | BES | **Não** | Apenas um local (BES). |
| **05** | BES | **Não** | Apenas um local (BES). |
| **06** | BES | **Não** | Apenas um local (BES). |
| **07** | BES | **Não** | Apenas um local (BES). TSD não conta para EDMUNDO nesse dia (período dele em TSD a partir do 10). |
| **08** | Nenhum | **Não** | Sem atividade em mais de um local. |
| **09** | Nenhum | **Não** | Sem atividade em mais de um local. |
| **10** | TSD | **Não** | Apenas um local (TSD). |
| **11** | TSD | **Não** | Apenas um local (TSD). |
| **12** | TSD | **Não** | Apenas um local (TSD). |
| **13** | TSD | **Não** | Apenas um local (TSD). |
| **14** | TSD | **Não** | Apenas um local (TSD). |
| **15** | *Conferir no Gantt* | **Não** | Se só um local no dia, sem conflito. |
| **16** | *Conferir no Gantt* | **Não** | Idem. |
| **17** | NEPTRFET (se Treinamento NR-35 tiver executorPeriods para EDMUNDO); senão nenhum | **Não** | Se só NEPTRFET no dia, sem conflito. Se executorPeriods vazio, Treinamento não conta (vários executores). |
| **18** | Idem | **Não** | Mesmo motivo. |
| **19** | TSD + NEPTRFET (Treinamento NR-35, dias da tarefa 17–20) | **Sim** | Dois locais no mesmo dia. Regra: sem período específico por executor, usar os dias da tarefa → Treinamento conta → conflito. |
| **20** | TSD + NEPTRFET (Treinamento NR-35, dias da tarefa 17–20) | **Sim** | Dois locais no mesmo dia. Conflito esperado. |
| **21** | TSD | **Não** | Apenas um local (TSD). |
| **22** | TSD | **Não** | Apenas um local (TSD). |
| **23** | TSD | **Não** | Apenas um local (TSD). |
| **24** | TSD | **Não** | Apenas um local (TSD). |
| **25** | TSD | **Não** | Apenas um local (TSD). |
| **26** | TSD | **Não** | Apenas um local (TSD). |
| **27** | TSD | **Não** | Apenas um local (TSD). |
| **28** | TSD | **Não** | Apenas um local (TSD). |

---

## Quando haveria conflito para EDMUNDO?

Só há conflito em um dia em que ele tiver **EXECUÇÃO em dois ou mais locais distintos** no mesmo dia:

- BES **e** TSD no mesmo dia, ou  
- BES **e** NEPTRFET no mesmo dia, ou  
- TSD **e** NEPTRFET no mesmo dia.

Períodos considerados:

- **BES:** 03 a 07  
- **TSD (EDMUNDO):** 10–14 e 19–28  
- **NEPTRFET — Treinamento NR-35:** EDMUNDO está na atividade **junto com FCO WILSON, DANILLO, JOSELIO, SERGIO**. A barra no Gantt indica período por volta de **17 a 20**.

**Sobreposição relevante:**

- **Dias 19 e 20:** EDMUNDO está em **TSD** (Retrofit 19–28) e em **NEPTRFET** (Treinamento NR-35, dias da tarefa 17–20). **Há conflito** nesses dias. Regra: quando não há período específico por executor, usar os dias da tarefa (ganttSegments) — assim o Treinamento NR-35 (vários executores) conta e o conflito é detectado.
- **Dias 17 e 18:** Só NEPTRFET (Treinamento) → um local → sem conflito.
- BES (03–07) não se sobrepõe a NEPTRFET (17–20) nem a TSD (10+), então não gera conflito.

---

## Resumo final

| Conjunto de dias | Local(is) | Conflito? |
|------------------|-----------|-----------|
| 01–02 | — | Não |
| 03–07 | Só BES | **Não** |
| 08–09 | — | Não |
| 10–14 | Só TSD | **Não** |
| 15–16 | Conferir Gantt | Não (se só um local) |
| 17–18 | NEPTRFET (Treinamento NR-35), se executorPeriods para EDMUNDO | **Não** (um local) |
| **19–20** | TSD **e** NEPTRFET (Treinamento NR-35) | **Sim** (conflito: dois locais no mesmo dia) |
| 21–28 | Só TSD | **Não** |

**Conclusão:** A atividade **Treinamento NR-35** (NEPTRFET), em que EDMUNDO está **junto com FCO WILSON, DANILLO, JOSELIO, SERGIO**, entra na detecção de conflito. **Regra:** quando não tem período específico por executor, usar os dias da tarefa (ganttSegments). Nos dias **19 e 20** ele está em TSD (Retrofit) e em NEPTRFET (Treinamento) → **há conflito** e o sistema deve indicar (vermelho/tooltip).

---

## Treinamento NR-35 (NEPTRFET) — resumo

- **Atividade:** Treinamento NR-35 (local NEPTRFET / OUTROS).  
- **Executores:** EDMUNDO, FCO WILSON, DANILLO, JOSELIO, SERGIO (vários executores).  
- **Período no Gantt:** barra por volta dos dias 17–20.

**Regra aplicada:** Se **não** tem período específico por executor (`executorPeriods`), **usar os dias da tarefa** (ganttSegments de EXECUÇÃO) em que ele está programado. Assim o Treinamento NR-35 conta para EDMUNDO nos dias 17–20 → nos dias **19 e 20** há **conflito** (NEPTRFET + TSD). Dias 17 e 18 → só NEPTRFET → sem conflito.
