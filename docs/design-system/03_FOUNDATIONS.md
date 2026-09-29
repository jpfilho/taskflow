# TaskFlow Design System — Foundations

> **Status:** Proposta de Arquitetura  
> **Data:** Setembro de 2026

---

## 1. Arquitetura de Design Tokens

O **TaskFlow Design System (TFDS)** adotará uma arquitetura de tokens em 3 níveis:

```text
Nível 1: Tokens Globais (Primitivos)
├── Valores brutos de cor (hexadecimais da paleta de marca, slate, feedback)
├── Valores numéricos de escala tipográfica (10, 12, 14, 16, 18, 20, 24, 30, 36)
├── Valores numéricos de espaçamento base 4px (2, 4, 8, 12, 16, 20, 24, 32, 48)
└── Valores de raio de borda (2, 4, 6, 8, 12, 16, 999)

Nível 2: Tokens Semânticos (Decisões de Design)
├── Superfícies: surface, surfaceContainer, surfaceSubtle, surfaceElevated
├── Textos: textPrimary, textSecondary, textMuted, textOnColor
├── Bordas: borderSubtle, borderDefault, borderStrong, borderFocus
├── Feedback: success, warning, danger/error, info
└── Status Operacional: statusPlanned, statusProgress, statusDone, statusBlocked

Nível 3: Tokens de Componentes (Densidade & Estados)
├── tfButtonPadding, tfButtonHeight, tfButtonRadius
├── tfTableRowHeight (comfortable: 48px, compact: 38px, dense: 30px)
├── tfTableHeaderHeight
└── tfInputFieldHeight
```

---

## 2. Níveis de Densidade Informacional (`TaskFlowDensity`)

Como o TaskFlow opera em cenários que variam de tablets de eletricistas em campo a monitores ultrawide em centros de operação e controle de manutenção (CCO/GPM), estabelecemos três densidades formais:

| Densidade | Altura de Linha (Tabela) | Altura de Campo | Padding Padrão | Cenário de Aplicação |
| :--- | :---: | :---: | :---: | :--- |
| **`Dense`** | **30 px** | 34 px | 6 px | Telas de alta carga informacional (Gantt, Notas SAP, Apropriação de Horas) |
| **`Compact` (Padrão)** | **38 px** | 40 px | 8 px | Uso diário no Desktop/Web (Tabelas gerenciais, listas de tarefas) |
| **`Comfortable`** | **48 px** | 48 px | 12 px | Telas voltadas a toque (Tablet, Mobile, Diálogos e Modais de Confirmação) |

---

## 3. Estrutura de Código em Flutter

O acesso aos tokens em código Flutter será fortemente tipado através de `ThemeExtension` nativa do Flutter, garantindo suporte pleno a Hot Reload, tipagem estática e alternância fluida entre temas:

```dart
// Exemplo de uso em qualquer widget:
final tokens = Theme.of(context).extension<TaskFlowThemeExtension>()!;

Container(
  padding: EdgeInsets.all(tokens.space.md),
  decoration: BoxDecoration(
    color: tokens.colors.surfaceContainer,
    borderRadius: BorderRadius.circular(tokens.radius.sm),
    border: Border.all(color: tokens.colors.borderSubtle),
  ),
  child: Text(
    'Operação',
    style: tokens.typography.bodySmall.copyWith(
      color: tokens.colors.textPrimary,
    ),
  ),
);
```
