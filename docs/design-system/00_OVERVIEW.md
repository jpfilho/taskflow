# TaskFlow Design System — Overview

> **Versão:** 1.0.0-draft  
> **Status:** Diagnóstico & Proposta de Arquitetura  
> **Data:** Setembro de 2026  
> **Responsáveis:** Principal Product Designer, UX/UI Architect & Flutter Design System Engineer

---

## 1. Missão e Objetivo

O **TaskFlow** é uma aplicação corporativa e operacional multiplataforma (Desktop, Web, Tablet e Mobile) voltada para gestão e planejamento de tarefas, equipes, frota, manutenção industrial/elétrica e integração profunda com SAP.

O objetivo deste levantamento é auditar a arquitetura visual existente, catalogar seus ativos, identificar gargalos de inconsistência e dívida técnica, e propor a fundação para o:

> **`TaskFlow Design System` (TFDS)**

O Design System não tem como objetivo transformar o TaskFlow em um aplicativo minimalista de consumo (B2C), mas sim estabelecer o equilíbrio perfeito entre:
$$\textbf{Clareza} + \textbf{Densidade Informacional} + \textbf{Velocidade Operacional} + \textbf{Consistência Multiplataforma} + \textbf{Hierarquia Visual}$$

---

## 2. Princípios de Design do TaskFlow

1. **Densidade Informacional Eficiente**: Sistemas de engenharia e planejamento de manutenção demandam alto volume de dados visíveis simultaneamente (tabelas com 15+ colunas, cronogramas de Gantt com escalas diárias/horárias). A densidade deve ser organizada por hierarquia, tipografia precisa e alinhamento milimétrico, e não sacrificada com espaços vazios excessivos.
2. **Respeito à Natureza Offline-First**: O status de conectividade, filas locais do SQLite e sincronização com Supabase devem ser expressos de forma cristalina em cada item e em nível global de aplicação.
3. **Semântica Operacional Rigorosa**: Status críticos de segurança, prazos de notas de manutenção, bloqueios de programação e alertas de conflito de recursos não podem depender apenas de cores isoladas; devem combinar ícone, texto, contraste e formato.
4. **Resiliência Multiplataforma**: A experiência Desktop (orientada a mouse, teclado, atalhos e telas largas) deve ser especializada, enquanto a experiência Mobile/Tablet deve adaptar fluxos para toque, navegação inferior e visualizações condensadas (sem mero encolhimento da interface).
5. **Evolução Incremental Segura**: Nenhuma regra de negócio, trigger, banco de dados ou sincronização foi ou será alterada nesta etapa. A migração seguirá a estratégia de convivência segura *Legacy $\rightarrow$ Design System*.

---

## 3. Resumo da Auditoria Quantitativa

* **Arquivos Dart analisados:** 361
* **Telas / Visões / Diálogos mapeados:** 135
* **Componentes visuais catalogados:** 81 widgets em `lib/widgets/` + 38 widgets em `features/`
* **Cores Hexadecimais hardcoded únicas:** 116 (1.187 ocorrências)
* **Cores Material hardcoded únicas:** 127 (5.405 ocorrências)
* **Estilos de Texto hardcoded (`TextStyle`):** 2.134 ocorrências
* **Tamanhos de fonte distintos (`fontSize`):** 22 variações (de 9px a 36px)
* **Valores de `BorderRadius.circular` distintos:** 19 variações (predomínio de 8px e 12px)
* **Valores de Espaçamento (`EdgeInsets.all`):** 21 variações distintas
* **Ícones Material distintos:** 357 (1.802 ocorrências)
* **Botões de Ícone (`IconButton`):** 413 ocorrências
* **Tooltips de acessibilidade:** apenas 44 (mais de 89% dos botões de ícone sem tooltip explicativo)
* **Widgets `Semantics` explícitos:** 0

---

## 4. TaskFlow Design Consistency Score

O índice de consistência visual inicial apurado é:

$$\mathbf{39 \ / \ 100}$$

* **Meta estabelecida:** $90 \ / \ 100$
* **Gap atual:** $51$ pontos

---

## 5. Estrutura Documental Gerada

A documentação gerada nesta auditoria está organizada em:

* [`01_CURRENT_STATE.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/01_CURRENT_STATE.md) — Diagnóstico da arquitetura front-end atual.
* [`02_UI_INVENTORY.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/02_UI_INVENTORY.md) — Inventário consolidado de UI.
* [`03_FOUNDATIONS.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/03_FOUNDATIONS.md) — Fundações, tokens e temas.
* [`04_COLORS.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/04_COLORS.md) — Auditoria e paleta semântica de cores.
* [`05_TYPOGRAPHY.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/05_TYPOGRAPHY.md) — Escala e tokens de tipografia.
* [`06_SPACING.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/06_SPACING.md) — Escala de espaçamento e densidade.
* [`07_COMPONENTS.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/07_COMPONENTS.md) — Catálogo dos componentes propostos (TF*).
* [`08_RESPONSIVE.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/08_RESPONSIVE.md) — Breakpoints e adaptação mobile/desktop.
* [`09_ACCESSIBILITY.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/09_ACCESSIBILITY.md) — Auditoria WCAG e plano corretivo.
* [`10_PATTERNS.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/10_PATTERNS.md) — Padrões arquiteturais de página (Page Shell).
* [`11_TECHNICAL_DEBT.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/11_TECHNICAL_DEBT.md) — Mapa de dívida técnica visual (P0 a P3).
* [`12_MIGRATION_PLAN.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/12_MIGRATION_PLAN.md) — Plano de migração em fases (Fase 0 a 6).
* [`13_DESIGN_DECISIONS.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/13_DESIGN_DECISIONS.md) — Princípios e decisões consolidadas.
* [`COMPONENT_INVENTORY.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/COMPONENT_INVENTORY.md) — Inventário tabular detalhado de componentes.
* [`SCREEN_INVENTORY.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/SCREEN_INVENTORY.md) — Inventário completo das 135 telas e diálogos.
* [`DESIGN_TOKENS_INVENTORY.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/DESIGN_TOKENS_INVENTORY.md) — Mapeamento tokenizado.
* [`VISUAL_DEBT_REPORT.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/VISUAL_DEBT_REPORT.md) — Relatório evidenciado de dívida.
* [`DESIGN_SYSTEM_ROADMAP.md`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/DESIGN_SYSTEM_ROADMAP.md) — Cronograma de implantação.
* [`adrs/`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/docs/design-system/adrs/) — Architecture Decision Records (ADR-001 a ADR-005).
