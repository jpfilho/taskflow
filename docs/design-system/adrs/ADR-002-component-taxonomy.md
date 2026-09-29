# ADR-002: Nomenclatura e Taxonomia dos Componentes (Prefixo TF)

## Status
Aprovado

## Contexto
O projeto possui 109 arquivos dentro de `lib/widgets/` e 38 widgets em `lib/features/`, muitos com nomes genéricos ou conflitantes com o framework Flutter (ex: `TaskTable`, `FilterBar`, `Dashboard`, `GanttChart`, `CustomButton`).

## Decisão
Todos os componentes reutilizáveis que integram o Design System oficial receberão o prefixo corporativo **`TF`** (ex.: `TFButton`, `TFIconButton`, `TFTextField`, `TFStatusBadge`, `TFDataTable`, `TFPageHeader`, `TFDialog`).

## Consequências
* **Positivas:**
  * Diferenciação visual imediata no código entre o componente padronizado do Design System e widgets legados ou de bibliotecas de terceiros.
  * Facilidade de busca no IDE e auto-complete rápido digitando `TF...`.
* **Negativas:**
  * Necessidade de renomeação ou import de alias durante a fase de migração.
