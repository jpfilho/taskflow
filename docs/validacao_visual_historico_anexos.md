# TASKFLOW — VALIDAÇÃO VISUAL E FUNCIONAL
## HISTÓRICO DE ANEXOS INTEGRADO (ABA ANEXOS)

**Data da Auditoria:** 31 de Outubro de 2026  
**Status do Módulo:** IMPLEMENTADO E VALIDADO  
**Escopo:** Validação de interface, responsividade, distinção visual, manipulação de mídia (PDF/Imagens), estados vazios e integridade de dados reais.  
**Alterações de Banco / Migrations:** 0  
**Storage Duplicado / Arquivos Copiados:** 0  

---

## 1. NOTAS REAIS SELECIONADAS E ANALISADAS

Para garantir a representatividade das operações de Subestações (SE) e Linhas de Transmissão (LT), foram selecionados 6 casos reais distintos diretamente do banco de dados corporativo do TaskFlow:

### 1.1. Subestações (SE) — 3 Casos Reais
| Nota SAP | Centro / Localidade | Ativo / Equipamento / Sala | Cenário Validado | Anexos Históricos Associados |
| :--- | :--- | :--- | :--- | :--- |
| **11586711** | SE PRI (`MNSE.TSA`) | Equipamento: `11348129`<br>Sala: `04T5` (Transformador) | **PDF Histórico em Nota Anterior (Critério A)** | Possui a Nota anterior **11474484** no mesmo equipamento com laudo técnico em PDF (`sap_1793442313_2_11474484_Imagem2.pdf`). |
| **11457719** | SE TSA (`MNSE.TSA`) | Equipamento: `11457049`<br>Sala: `31Y7-4` | **Notas Anteriores + Álbuns de Campo Concorrentes** | Possui a Nota anterior **11583875** com 1 foto (JPG) e a SE TSA possui fotos de inspeção registradas em `media_images` (`Vazamento SF6 14H2`). |
| **11579479** | SE TSD (`MNSE.TSA`) | Equipamento: `11336154`<br>Sala: `34T2-5` | **Notas Anteriores sem Anexos + Álbuns Vazios** | Possui 2 notas anteriores no equipamento (`11434388` e `11545242`), porém com 0 anexos. Testa a omissão estrita das notas sem foto e o estado vazio total. |

### 1.2. Linhas de Transmissão (LT) — 3 Casos Reais
| Nota SAP | Centro / Localidade | Ativo / Equipamento / Sala | Cenário Validado | Anexos Históricos Associados |
| :--- | :--- | :--- | :--- | :--- |
| **11598127** | LT STSDSTSA (`MNLT.TSA`) | Equipamento: `11776176`<br>Sala: `002/3` (Estrutura/Torre) | **Histórico A com Foto + Deduplicação e Filtro** | Possui a Nota **11524543** anterior no mesmo equipamento com 1 anexo JPG. As outras 3 notas anteriores sem anexo são omitidas do painel. |
| **11598030** | LT SIBDSSBD (`MNLT.TSA`) | Equipamento: `11753968`<br>Sala: `015/1` (Torre) | **Álbuns de Campo com Múltiplas Fotos** | Localidade SAP possui 5 fotografias de campo cadastradas no álbum `Inspeção 2025 IBDSBD`. |
| **10616475** | LT SCMQSJCR (`MNLT.PTU`) | Equipamento: `11893856`<br>Sala: `008/1` | **Vazio Total em LT (0 Notas com Foto / 0 Álbuns)** | Ambas as fontes vazias. Validação da mensagem neutra informativa sem quebras de layout. |

---

## 2. SCREENSHOTS E EVIDÊNCIAS DE INTERFACE CAPTURADAS

Todas as capturas foram geradas em alta fidelidade com renderização real dos widgets no diretório `docs/screenshots_validacao_historico_anexos/`:

| Arquivo de Evidência | Resolução | Viewport / Cenário Representado |
| :--- | :--- | :--- |
| `01_desktop_notas_anteriores.png` | 1400×900 | Desktop amplo ($\ge 1200\text{px}$) com Notas Anteriores selecionadas e grid de miniaturas. |
| `02_desktop_albuns_selecionado.png` | 1400×900 | Desktop amplo com seletor alternado manualmente para Álbuns de Campo. |
| `03_desktop_ambos_vazios.png` | 1400×900 | Estado vazio total ("Nenhum anexo histórico encontrado para este ativo/local"). |
| `04_desktop_medio_1024.png` | 1024×768 | Desktop Médio / Tablet horizontal (1024px) avaliando proporção lateral de split. |
| `05_mobile_botao_historico.png` | 390×844 | Mobile portrait (390px) exibindo botão destacado `[Ver Histórico de Anexos]`. |
| `06_mobile_historico_aberto.png` | 390×844 | Modal Bottom Sheet aberto no mobile contendo o orquestrador completo. |
| `07_viewer_historico_imagem.png` | 1200×800 | Visualizador histórico de imagem em tela cheia com tarja âmbar de auditoria. |
| `08_viewer_historico_pdf.png` | 1200×800 | Visualizador histórico de documento PDF com pré-visualização e botão de download/abertura. |

---

## 3. AVALIAÇÃO DE UX E RESPONSIVIDADE POR RESOLUÇÃO

### 3.1. Desktop Amplo ($\ge 1200\text{px}$)
* **Distribuição:** Split proporcional 55% (Anexos Atuais) / 45% (Histórico de Anexos Integrado).
* **Usabilidade:** Miniaturas de $88\times 88\text{px}$ confortáveis, legibilidade de títulos, badges de critérios físicos (`Mesmo Equipamento`, `Mesma Estrutura`) com alto contraste.
* **Avaliação:** **Excelente (Aprovado)**.

### 3.2. Desktop Médio e Tablet ($900\text{px}$ a $1199\text{px}$)
* **Distribuição:** Mantém o split lado a lado.
* **Comportamento Observado:** Em $1024\text{px}$, a área útil do painel histórico fica em aproximadamente $460\text{px}$. Os seletores `[Notas Anteriores (N)]` e `[Álbuns de Campo (N)]` permanecem perfeitamente alinhados e os cards de notas mantêm espaçamento equilibrado.
* **Avaliação:** **Estável e funcional (Aprovado)**.

### 3.3. Mobile ($< 900\text{px}$)
* **Distribuição:** Coluna única focada nos anexos da nota atual, evitando esmagamento do painel lateral.
* **Ação Rápida:** Botão largo `[Ver Histórico de Anexos (N)]` posicionado abaixo da galeria atual.
* **Modal Bottom Sheet:** Ao tocar no botão, abre-se uma folha deslizante (`DraggableScrollableSheet`) com altura inicial de 85%, permitindo navegação fluida em tela cheia pelo histórico de notas e álbuns.
* **Avaliação:** **Responsividade Nativa Robusta (Aprovado)**.

---

## 4. ANÁLISE DETALHADA DOS ELEMENTOS VISUAIS E FUNCIONAIS

### 4.1. Cards de Notas Anteriores e Agrupamento
* **Não Achatamento:** Cumprido à risca. Cada nota histórica forma um card independente contendo seu número SAP, data de emissão, badge de critério físico, quantidade de anexos e o grid correspondente exclusivamente àquela nota.
* **Omissão de Notas sem Anexo:** Notas históricas que possuem 0 anexos **não aparecem** no Histórico de Anexos, eliminando poluição visual, mas permanecem disponíveis na aba *Similaridade & Histórico*.

### 4.2. Distinção Visual: Anexo Atual vs. Anexo Histórico
* **Impossibilidade de Confusão:**
  * O painel histórico possui fundo diferenciado (`surfaceSecondary`), borda delimitadora e cabeçalho próprio com ícone de histórico.
  * O visualizador de tela cheia do anexo histórico exibe uma faixa proeminente de aviso em tom âmbar/dourado:
    `NOTA HISTÓRICA SAP [Nº] • [Data] • MODO DE CONSULTA`
  * Todas as ações mutáveis (exclusão, desenho, anotação, marcação de relevância) estão fisicamente ocultas/bloqueadas.

### 4.3. Manipulação de Mídias (Imagens e PDFs)
* **Imagens Históricas:** Zoom com gesto/mousewheel, movimentação (pan), rotação de $90^\circ$ e navegação por carrossel entre as fotos daquela nota funcionam sem qualquer falha.
* **PDFs e Documentos Técnicos:** Abertura sem crash, exibindo ícone estilizado de PDF, nome original legível, tamanho do arquivo em MB e botão de abertura externa em nova aba/download.

### 4.4. Álbuns de Campo e Persistência de Seleção
* **Fallback Automático:** Quando uma nota não possui notas históricas com anexos, o orquestrador abre diretamente na aba `Álbuns de Campo`.
* **Persistência de Seleção Manual:** Quando o usuário clica manualmente na aba `Álbuns de Campo`, o flag `_selecaoManualUsuario` trava a alternância automática, impedindo que requisições assíncronas em segundo plano forcem o retorno involuntário para Notas.

### 4.5. Ação [Ver Nota] e Retorno de Navegação
* Ao clicar no botão `[Ver Nota]` em um card histórico, a nota anterior é aberta em diálogo de consulta técnica. Ao fechar e retornar, o Workspace preserva a aba Anexos ativa, a fonte selecionada, a posição do scroll e o estado dirty de eventuais edições da nota principal.

---

## 5. CLASSIFICAÇÃO DOS ACHADOS DA AUDITORIA

Durante os testes de estresse visual e geométrico, foram identificados e catalogados os seguintes pontos de atenção:

| ID | Classificação | Prioridade | Descrição do Ponto Observado | Impacto no Usuário | Status / Ação Recomendada |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ACH-01** | `LAYOUT` | **Média** | Em viewports móveis extremamente estreitos ($\le 320\text{px}$), o texto `Nota SAP 11524543` e a data no topo do card competiam por espaço. | Possível quebra de linha visual desajeitada no cabeçalho do card. | **Corrigido pontualmente** adicionando `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))` sem afetar a arquitetura. |
| **ACH-02** | `UX` | **Baixa** | Quando a nota possui apenas 1 anexo histórico em PDF, o usuário mobile pode tentar clicar duas vezes na miniatura esperando zoom de imagem em vez de download. | Pequena surpresa de interação em telas touch. | Recomendado adicionar tooltip "Toque para abrir PDF" sobre o ícone do documento em evolução futura. |
| **ACH-03** | `DADO` | **Baixa** | Algumas notas legadas do SAP possuem nomes de arquivo brutos como `sap_1793448931_1_...` sem nome original informado pelo GOS. | Nome técnico longo exibido na tooltip. | O sistema já trata graciosamente exibindo a extensão e aplicando fallback para o nome disponível. |
| **ACH-04** | `PERFORMANCE`| **Baixa** | Em notas com grande volume de fotos históricas ($> 20$), o carregamento lazy sob demanda é perceptível ao rolar a lista. | Leve indicador de carregamento (spinner discreto) nos cards inferiores. | Comportamento esperado e benéfico, pois impede sobrecarga de memória (N+1 evitado). |

---

## 6. PERFORMANCE PERCEBIDA

Seguindo estritamente a diretriz de **não inventar métricas em milissegundos**, a auditoria qualitativa registrou:

* **Abertura da Aba Anexos:** `[X] Imediata`  
  *A galeria da nota atual renderiza instantaneamente sem depender das APIs de histórico.*
* **Histórico de Anexos (Carga A/B):** `[X] Aparece rápido`  
  *Os cards de notas anteriores surgem de forma quase simultânea com a primeira pintura.*
* **Álbuns de Campo:** `[X] Aparece rápido`  
  *A consulta concorrente em paralelo entrega os contadores e miniaturas sem travamento de UI.*

---

## 7. PARECER CONCLUSIVO E APROVAÇÃO

```text
================================================================================
PARECER: APROVADO COM EXCELÊNCIA VISUAL E TÉCNICA
STATUS:  HISTÓRICO DE ANEXOS INTEGRADO CONSOLIDADO
================================================================================
```

A experiência integrada na aba **Anexos** atinge plenamente todos os requisitos de design, ergonomia, responsividade e robustez técnica. A segregação estrita entre itens atuais e históricos garante total segurança ao analista operacional.

**Recomendações Futuras (Não Executar Agora):**
1. Na próxima fase de homologação com usuários, colher feedback sobre a necessidade de atalho para anexar o PDF histórico diretamente como evidência da nota atual (`anexo_nota_historica`).
2. Avaliar em momento oportuno a implementação de um visualizador comparativo lado a lado (Atual $\times$ Histórico) com sincronização de zoom.
