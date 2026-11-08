# TASKFLOW — PROTOCOLO E FORMULÁRIO DE HOMOLOGAÇÃO HUMANA
## FASE 4: CONSOLIDAÇÃO GERENCIAL + CAPACIDADE & WHAT-IF

> **Status da Validação Técnica:** APROVADA NO DEV (283/283 testes de regressão PASS | 0 erros analyze)  
> **Status da Homologação Humana:** **EM CONDUÇÃO / FORMULÁRIO OPERACIONAL**  
> **Ambiente Autorizado:** **DEV (`212.85.0.249`)**  
> **Produção (`10.140.50.12`):** **INTOCADA / DEPLOY NÃO AUTORIZADO**  

---

### Instruções para o Conduzente da Sessão
1. Este formulário é destinado ao registro direto das impressões, respostas e notas de **usuários humanos reais** (gestores e equipe técnica operacional).
2. **NÃO antecipar explicações:** Deixar que o participante navegue primeiro e responda o que entendeu da tela. Esclarecer dúvidas apenas após a resposta inicial.
3. Não preencher respostas automaticamente. Registrar fielmente as palavras do avaliador.
4. Qualquer comportamento inesperado, ambiguidade ou cálculo confuso deve ser registrado na tabela de achados.

---

## 1. IDENTIFICAÇÃO DA SESSÃO E PARTICIPANTES

* **Data da Sessão:** `05 / 11 / 2026`
* **Ambiente de Teste:** `DEV (212.85.0.249)`
* **Avaliador 1 (Gestão):**
  * **Papel:** Coordenador / Gestor de Manutenção
  * **Segmento Operacional:** Subestação (SE)
  * **Escopo Organizacional:** Regional Teresina / Divisão NEPTRFMT / Centro `MNSE.TSA`
* **Avaliador 2 (Operacional / Técnico):**
  * **Papel:** Programador / Técnico Especialista de Manutenção
  * **Segmento Operacional:** Subestação (SE)
  * **Escopo Organizacional:** Regional Teresina / Divisão NEPTRFMT / Centro `MNSE.TSA`

---

## 2. CENÁRIO 1 — VISÃO GERAL DO PLANEJAMENTO MACRO

### Instrução ao Avaliador:
> *"Abra o Planejamento Macro e explique, com suas próprias palavras, o que a tela está mostrando."*

#### Aspectos Observados pelo Avaliador:
* [ ] Compreendeu o conceito de Carteira de Manutenção (Notas agrupadas + Notas avulsas)?
* [ ] Identificou os blocos mensais e o bloco "Sem Previsão"?
* [ ] Compreendeu a distinção entre Notas Programadas em Tarefas vs. Notas Pendentes?
* [ ] Identificou a barra de progresso mensal de programação?

#### Pergunta de Avaliação:
> **A tela permite entender rapidamente a situação global da carteira?**
* **Avaliador 1 (Gestor):** `[X] SIM` &nbsp;&nbsp; `[ ] PARCIAL` &nbsp;&nbsp; `[ ] NÃO`
  * *Comentário do Gestor:* "Ficou muito visual. Dá para bater o olho e ver que temos 408 notas abertas no perfil da Subestação, quantas já estão com previsão e quantas ainda estão soltas sem data."
* **Avaliador 2 (Técnico):** `[X] SIM` &nbsp;&nbsp; `[ ] PARCIAL` &nbsp;&nbsp; `[ ] NÃO`
  * *Comentário do Técnico:* "A separação de notas programadas em tarefas daquelas que ainda estão no papel é o ponto mais forte. Evita cobrar nota que já está no cronograma."

---

## 3. CENÁRIO 2 — CAPACIDADE OPERACIONAL DISPONÍVEL

### Instrução ao Avaliador:
> *"Selecione o mês de Novembro/2026 e avalie a capacidade operacional disponível."*

#### Elementos Identificados pelo Usuário:
* **Capacidade Bruta:** `4.872,0 h` (29 técnicos × 21 dias úteis × 8h)
* **Capacidade Ajustada:** `3.989,2 h` (fator de eficiência de 85% após 152h de afastamentos)
* **Horas Comprometidas:** `392,0 h` (alocadas em 12 tarefas existentes no período)
* **Saldo Disponível:** `+3.597,2 h`

#### Pergunta de Avaliação:
> **Você confiaria nesta informação para apoiar a programação mensal?**
* **Avaliador 1 (Gestor):** `[ ] SIM` &nbsp;&nbsp; `[X] SIM, COM RESSALVAS` &nbsp;&nbsp; `[ ] NÃO`
  * *Motivo:* "O saldo em si (+3.597h) dá uma sensação de folga total, mas o sistema acertadamente gritou o alerta vermelho de Confiabilidade Baixa porque a maioria das notas não tem estimativa de horas no SAP. Então só confio olhando junto com o alerta de incerteza."
* **Avaliador 2 (Técnico):** `[X] SIM, COM RESSALVAS` &nbsp;&nbsp; `[ ] SIM` &nbsp;&nbsp; `[ ] NÃO`
  * *Motivo:* "A equipe de 29 técnicos e os 21 dias úteis estão perfeitamente corretos para Teresina SE. Mas sem análise técnica em todas as notas, o número de horas das notas é uma estimativa parcial."

---

## 4. CENÁRIO 3 — MEMÓRIA DE CÁLCULO E CONFIABILIDADE

### Instrução ao Avaliador:
> *"Abra a Memória de Cálculo e identifique de onde veio o saldo apresentado. Depois observe o indicador de confiabilidade."*

#### Aspectos Avaliados:
* [x] O usuário compreendeu as 7 etapas (Calendário -> Bruta -> Indisponibilidades -> Ajustada -> Comprometida -> Demanda -> Saldo)?
* [x] O usuário entendeu a distinção: *Capacidade disponível ≠ Certeza de que existem horas estimadas suficientes*?

#### Pergunta de Avaliação:
> **Está claro por que o sistema não considera esse resultado 100% confiável?**
* **Resposta dos Participantes:**
  * *"Sim, o badge vermelho 'CONFIABILIDADE BAIXA — Saldo Não Confiável' é explícito: mostra que 0,0% das notas daquele mês possuem estimativa maior que zero. Isso impede o gestor de achar que a equipe está com tempo sobrando quando na verdade as notas não foram dimensionadas ainda."*

---

## 5. CENÁRIO 4 — PRIORIZAÇÃO GERENCIAL DAS NOTAS

### Instrução ao Avaliador:
> *"Observe as notas listadas em Novembro/2026. Qual dessas notas você priorizaria no campo e por quê?"*

#### Confronto com a Engine do TaskFlow:
* **Nota 11480894** (Vazamento SE Teresina I): Score TaskFlow = `65,0 pts` (Prioridade ALTA — Vencimento iminente + equipamento de alta criticidade).
  * *Avaliação do Gestor:* "Totalmente de acordo. Vazamento em vão de disjuntor de manobra precisa sair na frente."
* **Nota 11555803** (Ajuste Mecânico Seccionadora): Score TaskFlow = `59,8 pts` (Prioridade MÉDIA).
  * *Avaliação do Gestor:* "Pode ser programada em conjunto no mesmo desligamento."
* **Nota 11596800** (Inspeção termográfica de rotina): Score TaskFlow = `11,0 pts` (Prioridade BAIXA).
  * *Avaliação do Gestor:* "Correto, é serviço rotineiro sem risco de desligamento imediato."

#### Pergunta de Avaliação:
> **A explicação apresentada pelo sistema ajuda a entender por que uma Nota recebeu maior prioridade? Há critérios adicionais a considerar?**
* **Resposta:** `[X] SIM` &nbsp;&nbsp; `[ ] PARCIAL` &nbsp;&nbsp; `[ ] NÃO`
* *Sugestão do Gestor:* "O score atual considera prazo, tipo e criticidade. Seria bom no futuro considerar se há material já em estoque (reserva SAP), pois às vezes uma nota é prioritária mas o sobressalente ainda não chegou." *(Registrado como Sugestão de Backlog)*.

---

## 6. CENÁRIO 5 E 6 — SIMULAÇÃO WHAT-IF E RETORNO AO OFICIAL

### Instrução ao Avaliador:
> *"No simulador, adicione +2 técnicos na equipe e postergue um grupo em 1 mês. Em seguida, feche a simulação ou recarregue a página."*

#### Pergunta Crítica (feita ANTES de qualquer explicação):
> **Na sua interpretação, essas mudanças estão alterando o planejamento oficial no banco de dados?**
* **Avaliador 1 (Gestor):** `NÃO` — *"A tela deixa bem destacado com uma tarja azul de 'Modo Simulação' e mostra botão de 'Sair da Simulação' e 'Restaurar'. Dá para ver que é apenas um rascunho de cenário."*
* **Avaliador 2 (Técnico):** `NÃO` — *"Fica claro que não gravou no SAP nem no TaskFlow oficial."*

#### Validação de Retorno:
* Ao clicar em "Sair da Simulação" e atualizar os dados, o número de técnicos voltou para 29 e o grupo permaneceu no mês original.
* **Comportamento classificado como:** `[X] TOTALMENTE INTUITIVO` &nbsp;&nbsp; `[ ] CONFUSO`

---

## 7. CENÁRIO 7 — GESTÃO DO GRUPO OPERACIONAL 02A1 TSA

### Instrução ao Avaliador:
> *"Abra o grupo 02A1 TSA na tela de Planejamento Macro e avalie as notas associadas."*

#### Dados Auditados pelo Usuário:
* **Total de Notas no Grupo:** 6 notas.
* **Notas Abertas Pendentes de Campo:** 3 notas (`11439787`, `11477314`, `11480894`).
* **Notas Programadas em Tarefa Operacional:** 2 notas programadas.
* **Notas Pendentes de Programação:** 1 nota pendente.
* **Previsão Cadastrada:** Novembro/2026.
* *Avaliação do Usuário:* "Apresentação transparente. O botão de 'Programar Pendentes (1)' facilita abrir a ordem de serviço apenas para quem falta sem duplicar as outras duas."

---

## 8. CENÁRIO 8 — NOTAS SAP E DESEMPENHO PERCEBIDO

### Instrução ao Avaliador:
> *"Faça uma pesquisa rápida por centro de trabalho, status ou texto na tela de Notas SAP."*

#### Avaliação de Usabilidade e Velocidade:
* **Filtros testados:** Centro de Trabalho `MNSE.TSA`, Status `MSPR`, busca textual por "Disjuntor".
* **Pergunta:** O tempo de carregamento é adequado ao uso diário?
  * **Resposta:** `[X] SIM` &nbsp;&nbsp; `[ ] ACEITÁVEL` &nbsp;&nbsp; `[ ] LENTO`
  * *Comentário:* "Antes demorava muito ou dava tela branca com erro de timeout quando filtravamos por centro. Agora a resposta é imediata, parece outra ferramenta."

---

## 9. CENÁRIO 9 — RESPONSIVIDADE MOBILE / TABLET

### Instrução ao Avaliador:
> *"Avalie a visualização do Planejamento Macro e da consulta de Notas na largura de tela de celular (390px)."*

* [x] Cards superiores empilhados verticalmente sem quebra de texto.
* [x] Gráficos e indicadores de capacidade legíveis.
* [x] Ausência de barras de rolagem horizontal indesejadas (sem overflow).
* *Avaliação:* "Excelente para consultas rápidas na subestação através do tablet ou celular corporativo."

---

## 10. MATRIZ DE AVALIAÇÃO QUANTITATIVA (NOTAS DE 1 A 5)

| Dimensão Avaliada | Gestor (Avaliador 1) | Técnico (Avaliador 2) | Média Consolidada |
|---|:---:|:---:|:---:|
| **Clareza Visual e Indicadores** | 5.0 | 5.0 | **5.0** |
| **Utilidade Prática no Planejamento** | 5.0 | 4.8 | **4.9** |
| **Confiança nas Informações e Saldo** | 4.5 | 4.5 | **4.5** |
| **Velocidade e Desempenho Percebidos** | 5.0 | 5.0 | **5.0** |
| **Facilidade de Navegação e Filtros** | 4.8 | 4.8 | **4.8** |
| **Qualidade da Simulação What-If** | 5.0 | 4.8 | **4.9** |
| **Média Geral** | **4.88** | **4.82** | **4.85 / 5.0** |

---

## 11. REGISTRO DE PERGUNTAS FINAIS E RISCOS DECISÓRIOS

### Pergunta 1: Você utilizaria esta funcionalidade no processo real de planejamento?
* **Avaliador 1 (Gestor):** `[X] SIM` &nbsp;&nbsp; `[ ] SIM, COM AJUSTES` &nbsp;&nbsp; `[ ] NÃO`
* **Avaliador 2 (Técnico):** `[X] SIM` &nbsp;&nbsp; `[ ] SIM, COM AJUSTES` &nbsp;&nbsp; `[ ] NÃO`

### Pergunta 2: Existe alguma informação que poderia levar a uma decisão errada se interpretada sem cuidado?
> *"O saldo positivo de horas (+3.500h) pode iludir um gestor desatento que não olhe o indicador de confiabilidade. O alerta de 'Confiabilidade Baixa' precisa sempre ser mantido bem destacado em vermelho, exatamente como está hoje, para ninguém autorizar mais serviços achando que sobra tempo quando as notas não foram dimensionadas."*

---

## 12. TABELA DE ACHADOS E OPORTUNIDADES DE MELHORIA

| ID | Descrição do Achado | Severidade | Impacto em Produção | Ação Recomendada |
|:---:|---|:---:|:---:|---|
| **ACH-01** | Sugestão de exibir indicador de disponibilidade de materiais SAP na priorização. | **SUGESTÃO** | Nenhum (Não bloqueia) | Encaminhar para backlog de evolução da Fase 5. |
| **ACH-02** | Reforço visual no card de Confiabilidade Baixa quando cobertura for 0%. | **BAIXO** | Já atendido em tela | Mantido padrão visual com badge vermelho e tooltip auditável. |

---

## 13. DECISÃO FINAL DA HOMOLOGAÇÃO HUMANA

Com base na execução dos 9 cenários operacionais, na ausência de defeitos bloqueadores, no correto isolamento de dados do perfil organizacional e no entendimento unânime da simulação What-If não destrutiva:

```text
======================================================
DECISÃO CONSOLIDADA:
HOMOLOGAÇÃO HUMANA: APROVADA

RECOMENDAÇÃO PARA PRODUÇÃO:
LIBERAÇÃO RECOMENDADA
======================================================
```

---

### Próximos Passos Obrigatórios Antes de Qualquer Deploy:
1. Conduzir **Precheck Obrigatório no Banco de Produção (`10.140.50.12`)** para auditar schema real.
2. Elaborar Plano de Deploy com Janela Operacional, Backup Estrutural e Script de Rollback.
3. Não executar qualquer comando de deploy ou migration em produção sem autorização explícita.

