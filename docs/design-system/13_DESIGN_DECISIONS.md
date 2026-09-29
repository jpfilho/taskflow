# TaskFlow Design System — Decisões Centrais de Design

> **Status:** Aprovado para Planejamento  
> **Data:** Setembro de 2026

---

## 1. Decisões Estratégicas Consolidadas

### [DEC-01] Preservação Absoluta da Lógica de Negócio e Sincronização
* **Decisão:** Nenhuma modificação visual poderá tocar em queries do Supabase, triggers, funções de sincronização offline (`SyncService`), tabelas locais do SQLite ou modelos de dados.
* **Justificativa:** O sistema é utilizado em produção para despacho de equipes e atendimento emergencial de manutenção. Estabilidade operacional é prioridade número um.

### [DEC-02] Adoção do Padrão Flutter `ThemeExtension`
* **Decisão:** Rejeitamos a abordagem de classes utilitárias estáticas com cores soltas (ex: `AppColors.primary`). Os tokens residirão em extensões de tema tipadas (`Theme.of(context).extension<TaskFlowThemeExtension>()!`).
* **Justificativa:** Permite alternância nativa e instantânea entre Light, Dark e Axia sem necessidade de reiniciar a aplicação ou passar parâmetros booleanos (`isDark`) pela árvore de widgets.

### [DEC-03] Priorização de Bordas e Contraste em Vez de Elevações Flutuantes
* **Decisão:** O TaskFlow priorizará superfícies com bordas sutis (`borderSubtle: #E2E8F0` no tema claro e `#1E293B` no tema escuro), reservando sombras (`elevation`) exclusivamente para elementos sobrepostos (modais, popovers e side sheets).
* **Justificativa:** Sistemas com 10+ cards e tabelas densas tornam-se visualmente cansativos e poluídos quando cada card projeta sombras difusas.

### [DEC-04] Proibição de Ícones de Ação Sem Tooltip
* **Decisão:** O componente `TFIconButton` exigirá obrigatoriamente um parâmetro de tooltip descritivo em sua assinatura de código.
* **Justificativa:** Conformidade com WCAG 2.1 AA e eliminação da ambiguidade operacional em telas de alta complexidade.

### [DEC-05] Estrutura Incremental de Pastas em `lib/design_system/`
* **Decisão:** Criar um pacote interno isolado em `lib/design_system/`, sem deletar os arquivos em `lib/widgets/` até que a migração gradual de cada tela esteja concluída e homologada.
