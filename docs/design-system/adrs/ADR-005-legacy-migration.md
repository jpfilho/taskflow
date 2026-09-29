# ADR-005: Convivência Incremental Legacy UI → Design System

## Status
Aprovado

## Contexto
O TaskFlow é um sistema complexo em produção ativa, integrando SQLite offline, webhooks de Telegram, Supabase e rotinas SAP. Uma refatoração simultânea de todas as telas (*Big Bang*) paralisaria o desenvolvimento de produto e criaria alto risco de falha operacional.

## Decisão
1. Os novos componentes residirão na pasta `lib/design_system/`.
2. A migração ocorrerá em lotes independentes, guiada pelo índice *Migration Priority Score*.
3. Componentes legados não serão excluídos imediatamente; passarão por um ciclo de depreciação com `@deprecated` e anotações explicativas no código.

## Consequências
* **Positivas:**
  * Zero risco de interrupção de produção.
  * Validação gradual com feedback contínuo dos operadores reais.
  * Entregas parciais de valor a cada sprint.
* **Negativas:**
  * Convivência temporária de duas formas de construir telas no repositório durante a fase de transição.
