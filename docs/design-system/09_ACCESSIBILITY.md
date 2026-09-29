# TaskFlow Design System — Acessibilidade & Auditoria WCAG

> **Status:** Concluído  
> **Data:** Setembro de 2026

---

## 1. Diagnóstico de Acessibilidade no TaskFlow

A auditoria de conformidade com as diretrizes **WCAG 2.1 nível AA** identificou pontos críticos que devem ser tratados de forma pragmática, sem descaracterizar a natureza operacional densa do sistema:

### 1.1 Ausência de `Semantics`
* **Achado [CRITICAL]:** Foi detectada **zero ocorrência** de widgets `Semantics` configurados explicitamente no projeto Flutter.
* **Impacto:** Leitores de tela (TalkBack no Android, VoiceOver no iOS/macOS, NVDA no Windows) não conseguem interpretar botões puramente iconográficos, status expressos apenas por containers coloridos e tabelas de dados complexas.

### 1.2 Botões de Ícone Sem Rótulo / Tooltip
* **Achado [HIGH]:** O projeto possui **413 instâncias de `IconButton`**, mas apenas **44 instâncias de `Tooltip`** em todo o código.
* **Impacto:** Mais de 89% dos botões de ação (editar, excluir, duplicar, anexar, visualizar histórico) dependem de reconhecimento visual exclusivo do pictograma. Em tablets de campo ou operadores com baixa visão, isso gera hesitação e erros operacionais.

### 1.3 Contraste de Cores em Textos (WCAG 1.4.3)
* **Achado [HIGH]:** Foram identificados 14 arquivos utilizando tons de cinza claro (`Colors.grey[400]`, `Colors.grey[500]`, `#94A3B8`) para textos pequenos sobre fundos brancos ou cinzas claros (`#F1F5F9`, `Colors.grey[200]`).
* **Taxa de Contraste Medida:** Abaixo de 2.8:1 (o mínimo exigido por WCAG AA é 4.5:1 para texto normal e 3.0:1 para texto grande).

### 1.4 Dependência Exclusiva de Cor em Status
* **Achado [MEDIUM]:** Vários status em calendários e células de tabela usam apenas uma bolinha ou quadrado colorido para expressar status (ex: vermelho para pendente, verde para concluído).
* **Impacto:** Operadores com daltonismo (deuteranopia ou protanopia, presentes em cerca de 8% dos homens) não conseguem distinguir com precisão entre atividades pendentes e concluídas sem clicar.

---

## 2. Recomendações e Correções no Design System

1. **Parâmetro `tooltip` Obrigatório em `TFIconButton`**: Nenhum botão de ícone poderá ser criado sem texto acessível.
2. **Status Multi-Modal (`TFStatusBadge`)**: Todo status operacional obrigatoriamente terá:
   * Texto explícito do status (ex.: "Pendente", "Em Andamento").
   * Ícone distintivo (ex.: relógio para pendente, check para concluído, triângulo de alerta para bloqueado).
   * Cor semântica validada para contraste $\ge 4.5:1$.
3. **Alvos Mínimos de Toque**: Garantir que botões em mobile e tablet possuam área clicável efetiva de no mínimo $44 \times 44\text{ px}$ (via `HitTestBehavior` e padding invisível), mesmo que o ícone visual seja de 18px a 20px.
4. **Navegação por Teclado e Foco Visível**: Garantir que o anel de foco (`FocusNode` e `borderFocus = #3B82F6`) seja nítido ao navegar via `Tab` no Desktop/Web.
