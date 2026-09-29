# 16 — Design System Gallery & Visual Playground (Fase 3)

## Resumo Executivo
A **Fase 3 do TaskFlow Design System (TFDS)** implementou com sucesso a **Design System Gallery / Visual Playground** interna, permitindo inspecionar e validar interativamente todos os tokens de fundação, componentes base, temas (Light, Dark e Axia), modos de densidade (Comfortable, Compact e Dense) e adaptações de responsividade.

**Segurança e Integridade do Projeto:**
- A Gallery é de uso estritamente interno e protegida por `kDebugMode`.
- **0 telas produtivas foram migradas** (`PRODUCTION SCREENS MIGRATED = 0`).
- Nenhuma regra de negócio, navegação de produção (`AppMenuConfig`, `Sidebar`, `HomeShortcuts`), SQLite ou Supabase foi alterada.

---

## 1. Estrutura Criada na Gallery

```text
lib/design_system/gallery/
├── design_system_gallery.dart         # Entrypoint protegido com restrição kDebugMode
├── gallery_shell.dart                 # Shell responsivo com seletores de Tema e Densidade
├── gallery_navigation.dart            # Barra lateral organizada por grupos semânticos
├── gallery_section.dart               # Cards de preview e moldura estrutural
└── sections/
    ├── overview_section.dart          # Visão geral, métricas e arquitetura de resolução
    ├── colors_section.dart            # Swatches de tokens semânticos com Hex em tempo real
    ├── typography_section.dart        # 12 níveis com specs tipográficas e exemplos do domínio
    ├── spacing_section.dart           # Grid 4px com representação em barras
    ├── radius_section.dart            # Amostras de curvatura (none a full)
    ├── elevation_section.dart         # Comparativo flat, raised e overlay
    ├── icons_section.dart             # Catálogo de 29 aliases semânticos de TFIcons
    ├── buttons_section.dart           # Matriz de TFButton (variantes, tamanhos, estados)
    ├── icon_buttons_section.dart      # TFIconButton com tooltips e touch target (min 40x40)
    ├── inputs_section.dart            # TFTextField em estados reais de formulário
    ├── status_section.dart            # TFStatusBadge (cor + texto + ícone) e modo compacto
    ├── cards_section.dart             # TFCard (default, interactive, highlighted)
    ├── page_header_section.dart       # TFPageHeader com breadcrumbs e ações responsivas
    ├── feedback_section.dart          # TFEmptyState e TFLoading (inline, section, page)
    ├── sync_section.dart              # TFSyncIndicator em todos os estados de conectividade
    ├── responsive_section.dart        # Simulação em viewports de 360px, 768px e 1024px
    └── density_validation_section.dart# Comparativo lado a lado dos 3 modos de densidade
```

---

## 2. Forma de Acesso e Proteção

A Gallery está protegida e só pode ser acessada em ambiente de desenvolvimento (`kDebugMode`):

### 2.1 Acesso via Rota de Debug
No navegador ou deep-link de desenvolvimento:
```text
/debug/design-system
```
Configurado em `MaterialApp.onGenerateRoute` com guarda condicional `if (kDebugMode && settings.name == '/debug/design-system')`.

### 2.2 Acesso Programático Seguro
Para disparar via botões temporários de desenvolvimento ou menus de debug:
```dart
import 'package:task2026/design_system/gallery/design_system_gallery.dart';

DesignSystemGallery.open(context, themeProvider: themeProvider);
```

---

## 3. Controles Interativos da Gallery

1. **Theme Switcher Real:**
   - Alterna instantaneamente entre **Light**, **Dark** e **AXIA**.
   - Conectado diretamente ao `ThemeProvider` e `ThemeService` oficial da aplicação. Não há "mock" ou simulação de cores locais; a árvore inteira reage aos tokens reais.
2. **Density Switcher Dinâmico:**
   - Alterna entre **Comfortable** (48px), **Compact** (40px) e **Dense** (34px).
   - Injeta dinamicamente a `TaskFlowThemeExtension` atualizada na subárvore da Gallery para validar o comportamento dos controles.

---

## 4. Achados Visuais e Ajustes Realizados (`VISUAL FINDINGS`)

Durante a validação prática e testes de renderização da Gallery, identificamos e solucionamos preventivamente os seguintes pontos:

### 4.1 Ajuste em TFButton: Overflow com Labels Longos em Telas Apertadas
- **Severidade:** `MEDIUM`
- **Problema:** Quando `TFButton` estava contido em uma largura restrita com `fullWidth: true` e ícones laterais, o texto poderia causar overflow de pixels se não estivesse envolto em um widget flexível.
- **Ajuste Aplicado:** O texto do `TFButton` agora está envolto em `Flexible` com `TextOverflow.ellipsis`, garantindo que botões em caixas de diálogo ou layouts móveis nunca estourem o layout.

### 4.2 Ajuste no AppBar da Gallery: Adaptação em Viewports Compactas
- **Severidade:** `LOW`
- **Problema:** Em resoluções intermediárias (ex: 768px a 800px), a combinação de título extenso + seletor de tema + seletor de densidade no AppBar poderia exceder a largura horizontal.
- **Ajuste Aplicado:** Os segmented buttons foram otimizados (`showSelectedIcon: false`), rótulos condensados e título resumido para 'TF Design System', preservando conforto visual em qualquer monitor.

---

## 5. Como Adicionar Novas Seções à Gallery

Para registrar um novo componente ou validação futura na Gallery:
1. Crie o arquivo da seção em `lib/design_system/gallery/sections/<novo_componente>_section.dart` herdando de `GallerySection`.
2. Em `lib/design_system/gallery/gallery_shell.dart`, adicione o `GalleryNavItem` correspondente na lista `_navItems`.
3. No método `_buildActiveSection()`, adicione o case correspondente retornando a sua seção.

---

## 6. Qualidade, Testes e Análise Estática

- **Análise Estática (`flutter analyze lib/design_system test/design_system`):**
  - **0 erros, 0 avisos**.
- **Suíte de Testes Automatizados (`flutter test test/design_system/`):**
  - **27 testes executados, 27 aprovados (100% de sucesso)**.
  - Cobertura completa:
    - 11 testes de Foundations (Cores, Tipografia, Spacing, Radius, Densidade, Ícones);
    - 12 testes de Componentes (TFButton, TFIconButton, TFTextField, TFStatusBadge, TFCard, TFPageHeader, TFEmptyState, TFLoading, TFSyncIndicator);
    - 4 testes da Gallery (renderização, navegação lateral, alternância de densidade e abertura de rota protegida).
