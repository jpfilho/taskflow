# ADR-003: Estratégia de Responsividade Fluida e Adaptação Mobile

## Status
Aprovado

## Contexto
O arquivo `lib/utils/responsive.dart` atualmente fixa a largura das tabelas no Desktop em 1200px e adota apenas dois breakpoints rígidos (600px e 1024px). Isso provoca cortes horizontais em laptops de 1366px e reduz o mobile a um encolhimento de tabelas complexas.

## Decisão
1. Adotar a escala de 6 breakpoints: `xs` (<480px), `sm` (480-767px), `md` (768-1023px), `lg` (1024-1365px), `xl` (1366-1919px) e `xxl` (>=1920px).
2. No Mobile (`xs`, `sm`), o comportamento de tabelas densas com mais de 6 colunas **não será scroll horizontal forçado**, mas sim uma visão adaptada em **Cards Operacionais** (`TFRecordCard`), com drawer/bottom sheet para detalhes completos.

## Consequências
* **Positivas:**
  * Experiência natural tanto no Desktop quanto no smartphone de campo do eletricista/técnico.
  * Fim de overflows em telas intermediárias.
* **Negativas:**
  * Exige criar uma representação visual em card para cada entidade tabular complexa.
