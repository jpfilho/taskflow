# 14 — Foundations & Tokens Implementation (Fase 1)

## Resumo Executivo
A **Fase 1 do TaskFlow Design System (TFDS)** foi executada com sucesso absoluto, estabelecendo a fundação formal de design tokens, escala tipográfica, espaçamentos, raios, bordas, sombras, densidade, breakpoints, aliases de ícones e arquitetura de temas (Light, Dark e Axia) via `ThemeExtension`.

**Importante:** Nesta etapa, nenhuma tela produtiva foi alterada (`PRODUCTION SCREENS MIGRATED = 0`), nenhum componente visual legado foi substituído e nenhuma regra de negócio, banco ou serviço de sincronização foi modificado.

---

## 1. Estrutura de Diretórios e Arquivos Criados

```text
lib/design_system/
├── foundations/
│   ├── tf_colors.dart         # Paleta primitiva e tokens semânticos (Light, Dark, Axia)
│   ├── tf_typography.dart     # Escala tipográfica formal de 12 níveis
│   ├── tf_spacing.dart        # Escala geométrica base 4px (2 a 48)
│   ├── tf_radius.dart         # Escala de raios de curvatura (none a full)
│   ├── tf_borders.dart        # Espessuras e geradores padronizados de borda
│   ├── tf_elevation.dart      # Sistema flat + border e elevações raised/overlay
│   ├── tf_breakpoints.dart    # Breakpoints de viewport e helpers responsivos
│   ├── tf_density.dart        # 3 modos operacionais: comfortable, compact, dense
│   ├── tf_motion.dart         # Tokens de duração (fast, normal, slow) e curvas
│   └── tf_icons.dart          # Aliases para as 23 intenções de ação mais frequentes
│
├── theme/
│   ├── taskflow_theme.dart            # Ponto único de fábrica para os temas
│   ├── taskflow_theme_extension.dart  # ThemeExtension<TaskFlowThemeExtension> + BuildContext helpers
│   ├── taskflow_light_theme.dart      # ThemeData Light composto com tokens TF
│   ├── taskflow_dark_theme.dart       # ThemeData Dark sem inversão automática
│   └── taskflow_axia_theme.dart       # ThemeData Axia preservando identidade de marca
│
└── taskflow_design_system.dart        # Export central da biblioteca
```

---

## 2. Inventário de Tokens Implementados

### 2.1 Cores (`TFPrimitiveColors` & `TFSemanticColors`)
- **Primitivas:**
  - `blue50` a `blue900`
  - `slate50` a `slate900`
  - `emerald50` a `emerald700` (Success)
  - `amber50` a `amber700` (Warning)
  - `rose50` a `rose700` (Danger / Error)
  - `sky50` a `sky700` (Info)
  - Identidade Axia: `axiaNavy` (#0A192F), `axiaBlue` (#0052CC), `axiaGray` (#8892B0), `axiaOffWhite` (#F4F6F8).
- **Semânticas (Light, Dark e Axia):**
  - **Brand & Interaction:** `primary`, `primaryHover`, `primaryPressed`, `primaryForeground`.
  - **Superfícies:** `background`, `surface`, `surfaceSecondary`, `surfaceElevated`.
  - **Tipografia:** `textPrimary`, `textSecondary`, `textMuted`, `textDisabled`, `textInverse`.
  - **Bordas:** `borderSubtle`, `borderDefault`, `borderStrong`, `borderFocus`.
  - **Feedback:** `success`, `successForeground`, `successBackground`, `warning`, `warningForeground`, `warningBackground`, `danger`, `dangerForeground`, `dangerBackground`, `info`, `infoForeground`, `infoBackground`.
  - **Estados:** `hover`, `selected`, `focus`, `disabled`.

### 2.2 Tipografia (`TFTypography`)
Escala padronizada com pesos definidos, line-heights e letter-spacings adequados a sistemas operacionais:
1. `display` (32px, bold, 1.25)
2. `pageTitle` (24px, bold, 1.3)
3. `sectionTitle` (20px, w600, 1.35)
4. `cardTitle` (16px, w600, 1.4)
5. `bodyLarge` (16px, normal, 1.5)
6. `bodyMedium` (14px, normal, 1.45)
7. `bodySmall` (12px, normal, 1.4)
8. `labelLarge` (14px, w600, 1.2)
9. `labelMedium` (12px, w600, 1.2)
10. `labelSmall` (11px, w600, 1.15)
11. `caption` (12px, normal, 1.35)
12. `micro` (10px, w500, 1.2)
- Suporte nativo a `tabularFigures` para colunas numéricas de tabelas financeiras/SAP.

### 2.3 Espaçamento (`TFSpacing`)
Escala pura baseada no grid de 4px:
- `xxs`: 2px
- `xs`: 4px
- `sm`: 8px
- `md`: 12px
- `base`: 16px
- `lg`: 20px
- `xl`: 24px
- `xxl`: 32px
- `xxxl`: 48px

### 2.4 Raios (`TFRadius`)
- `none`: 0px
- `xs`: 4px (badges, micro tags)
- `sm`: 8px (padrão de inputs, botões, containers)
- `md`: 12px (cards, modais compactos)
- `lg`: 16px (diálogos modais, painéis flutuantes)
- `full`: 999px (pills, avatares circulares)

### 2.5 Bordas & Elevações (`TFBorders` & `TFElevation`)
- **Bordas:**
  - `widthSubtle`: 1.0px
  - `widthDefault`: 1.0px
  - `widthStrong`: 1.5px
  - `widthFocus`: 2.0px
  - Métodos utilitários: `all()`, `bottom()`, `focus()`.
- **Elevações:**
  - `flat`: Elevação 0 (estratégia preferida do TaskFlow: flat + border).
  - `raised`: Elevação 2 (cards flutuantes, popovers).
  - `overlay`: Elevação 4 (diálogos modais, menus suspensos, sidebars sobrepostas).

### 2.6 Modos de Densidade (`TFDensity`)
- `comfortable`: Altura de controle 48px, linha 52px, padding horizontal 16px (Mobile/Tablet).
- `compact`: Altura de controle 40px, linha 40px, padding horizontal 12px (Desktop operacional).
- `dense`: Altura de controle 32px, linha 32px, padding horizontal 8px (Tabelas de notas e ordens SAP).

### 2.7 Breakpoints (`TFBreakpoints`)
- `xs`: < 600px (Mobile portrait)
- `sm`: 600px - 839px (Mobile landscape / Small tablet)
- `md`: 840px - 1023px (Tablet portrait)
- `lg`: 1024px - 1439px (Desktop padrão / Tablet landscape)
- `xl`: 1440px - 1919px (Desktop wide)
- `xxl`: ≥ 1920px (Ultra wide)
- Helpers reativos: `TFBreakpoints.isMobile(context)`, `isTablet(context)`, `isDesktop(context)`, `isLargeDesktop(context)`.

### 2.8 Ícones (`TFIcons`)
23 aliases para as intenções do sistema:
`add`, `edit`, `delete`, `save`, `cancel`, `close`, `search`, `filter`, `refresh`, `sync`, `chat`, `attachment`, `upload`, `download`, `calendar`, `history`, `settings`, `more`, `warning`, `error`, `success`, `info`, `ai`.

---

## 3. Integração com a Arquitetura de Temas Existente

A integração foi feita diretamente no `lib/services/theme_service.dart`, mantendo o fluxo existente de `ThemeProvider`:

```text
ThemeProvider
     ↓
ThemeService.getThemeData(currentTheme)
     ↓
TaskFlowTheme.light() / dark() / axia()
     ↓
ThemeData (Material 3) + TaskFlowThemeExtension
```

Todos os métodos legados de `ThemeService` continuam idênticos e o tema Axia original preserva suas cores características.

---

## 4. API de Consumo do Design System

Para acessar os tokens em qualquer Widget Flutter, utilize as extensões convenientes de `BuildContext`:

### 4.1 Acesso a Cores Semânticas
```dart
final colors = context.tfColors;

Container(
  decoration: BoxDecoration(
    color: colors.surface,
    border: Border.all(color: colors.borderDefault),
    borderRadius: TFRadius.borderRadiusSm,
  ),
  child: Text(
    'Nota de Manutenção',
    style: context.tfTypography.bodyMedium.copyWith(
      color: colors.textPrimary,
    ),
  ),
)
```

### 4.2 Acesso a Espaçamentos e Tipografia
```dart
Padding(
  padding: EdgeInsets.symmetric(
    horizontal: context.tfSpacing.base,
    vertical: context.tfSpacing.sm,
  ),
  child: Text(
    'Título da Seção',
    style: context.tfTypography.sectionTitle,
  ),
)
```

### 4.3 Acesso a Responsividade e Densidade
```dart
if (context.isMobile) {
  // layout em coluna para smartphone
} else {
  // layout em tabela para desktop
}

// Densidade ativa do tema
final density = context.tfDensity;
final double rowHeight = density.rowHeight;
```

---

## 5. Regras de Desenvolvimento (DO & DON'T)

### DO (Boas Práticas)
- ✅ **Usar sempre semantic tokens** (`context.tfColors.primary`, `surface`, `borderDefault`, etc.) em vez de cores hexadecimais fixas.
- ✅ **Usar `TFTypography`** para todos os textos da aplicação.
- ✅ **Usar `TFSpacing`** para margens, paddings e `SizedBox` de separação.
- ✅ **Usar `TFRadius`** para arredondamentos de cantos.
- ✅ **Usar `TFIcons`** para botões de ação e ícones recorrentes.
- ✅ **Respeitar os modos de densidade** (`context.tfDensity`) em componentes de dados (tabelas e listas).
- ✅ **Garantir funcionamento nos 3 temas** (Light, Dark e Axia) sem referenciar o nome do tema ativo no widget.

### DON'T (Proibições Estritas)
- ❌ **Não utilizar cores hardcoded** (`Color(0xFF...)` ou `Colors.blue`) diretamente no código de apresentação.
- ❌ **Não inventar valores mágicos de espaçamento** (`EdgeInsets.all(13)` ou `SizedBox(height: 7)`).
- ❌ **Não inventar raios arbitrários** (`BorderRadius.circular(9)`).
- ❌ **Não definir tamanhos de fonte soltos** (`TextStyle(fontSize: 15.3)`).
- ❌ **Não acoplar regras de domínio SAP no Design System** (ex: não criar `sapOkColor` no foundation; usar `colors.success`).
- ❌ **Não migrar telas existentes sem autorização** prévia do plano de migração.

---

## 6. Validação e Qualidade

- **Compilação e Lints:**
  - `flutter analyze lib/design_system test/design_system`: **0 erros, 0 avisos**.
- **Testes Unitários:**
  - `flutter test test/design_system/foundations_test.dart`: **11 testes executados, 11 aprovados (100% sucesso)**.
  - Cobertura dos testes:
    - Validação de tokens semânticos Light, Dark e Axia;
    - Ausência de nulos em tokens críticos;
    - Distinção e contraste entre superfícies e textos;
    - Testes de `copyWith` e interpolação `lerp` da `TaskFlowThemeExtension`;
    - Integridade da escala tipográfica, espaçamento e raios;
    - Modos de densidade e aliases de ícones.
- **Isolamento de Escopo:**
  - Nenhuma regra de negócio, modelo, sincronização ou banco de dados foi modificada.
