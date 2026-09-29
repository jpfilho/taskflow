# 15 — Base Components Implementation (Fase 2)

## Resumo Executivo
A **Fase 2 do TaskFlow Design System (TFDS)** implementou os componentes base reutilizáveis fundamentais do sistema, consumindo exclusivamente a infraestrutura de tokens e temas estabelecida na Fase 1.

**Critério de Segurança:** Nenhuma tela produtiva do TaskFlow foi alterada (`PRODUCTION SCREENS MIGRATED = 0`), nenhuma substituição em massa de widgets legados foi feita e nenhuma regra de negócio, modelo, banco SQLite ou sincronização com o Supabase foi tocada.

---

## 1. Estrutura de Componentes Criada

```text
lib/design_system/components/
├── buttons/
│   ├── tf_button.dart          # Botão de ação oficial com 5 variantes e 3 tamanhos
│   └── tf_icon_button.dart     # Botão de ícone compacto com touch target acessível (min 40x40)
│
├── inputs/
│   └── tf_text_field.dart      # Entrada de texto com estados de validação, erro e densidade
│
├── status/
│   └── tf_status_badge.dart    # Badge de severidade desacoplado de domínio (cor + texto + ícone)
│
├── cards/
│   └── tf_card.dart            # Superfície padronizada (flat + border) com variantes
│
├── layout/
│   └── tf_page_header.dart     # Cabeçalho de página responsivo (Desktop/Tablet/Mobile)
│
├── feedback/
│   ├── tf_empty_state.dart     # Estado vazio para ausência de registros (inline/fullPage)
│   └── tf_loading.dart         # Indicador de carregamento padronizado (inline/section/page)
│
└── sync/
    └── tf_sync_indicator.dart  # Indicador visual de conectividade e sincronização offline-first
```

---

## 2. Detalhamento dos Componentes

### 2.1 `TFButton`
- **Variantes (`TFButtonVariant`):** `primary`, `secondary`, `tertiary`, `danger`, `ghost`.
- **Tamanhos (`TFButtonSize`):** `small` (28-32px), `medium` (34-40px), `large` (40-48px), calibrados de acordo com a densidade ativa (`TFDensityMode`).
- **Estados Suportados:** default, hover, pressed, focus (anel com `colors.focus`), disabled e loading.
- **Acessibilidade:** Spinner integrado não distorce a largura nem causa deslocamento de layout; o estado de loading desabilita cliques múltiplos e expõe semântica para leitores de tela.

### 2.2 `TFIconButton`
- **Variantes (`TFIconButtonVariant`):** `standard`, `subtle`, `danger`.
- **Parâmetro Obrigatório:** `tooltip` é requerido por tipagem estrita para assegurar acessibilidade universal.
- **Touch Target:** Dimensão mínima clicável garantida de 40x40px, mesmo quando o pictograma visual é compacto (18px a 20px).

### 2.3 `TFStatusBadge`
- **Severidades (`TFStatusSeverity`):** `neutral`, `info`, `success`, `warning`, `danger`.
- **Arquitetura Visual:** Desacoplado de regras de negócio (SAP, Ordens, Tarefas). Combina texto semântico, cor de fundo, borda suave e ícone opcional para que pessoas daltônicas não dependam exclusivamente de matizes de cor. Suporta modo `compact: true` para grades de alta densidade.

### 2.4 `TFTextField`
- **Estados:** default, hover, focus (borda 2px `colors.borderFocus`), error (`colors.danger`), disabled e readOnly.
- **Recursos:** Suporte a label superior com indicador de obrigatoriedade `*`, prefixIcon, suffixIcon, mensagem de ajuda (`helperText`) e mensagem de validação (`errorText`). Integrado aos modos de densidade para espaçamento vertical e horizontal.

### 2.5 `TFCard`
- **Variantes (`TFCardVariant`):** `defaultCard` (flat + border sutil), `interactive` (hover sutil e clique), `highlighted` (elevação e borda temática).
- **Diretriz:** Mantido enxuto e conciso, evitando torná-lo um componente monolítico.

### 2.6 `TFPageHeader`
- **Recursos:** Título principal de página, subtítulo operacional, trilha de navegação (*breadcrumb*), ação primária e lista de ações secundárias.
- **Responsividade:** Em telas Desktop e Tablet, organiza título à esquerda e ações alinhadas à direita. Em telas Mobile (conforme `TFBreakpoints.isMobile`), empilha verticalmente o bloco de título e estica a ação primária (`fullWidth`).

### 2.7 `TFEmptyState`
- **Recursos:** Ícone contextual em círculo de superfície neutra, título da mensagem, descrição amigável e botão opcional de ação sugerida (ex.: "Limpar Filtros" ou "Nova Ordem").
- **Apresentação:** Suporta uso embutido (*inline*) dentro de tabelas/painéis e em tela cheia (*fullPage*).

### 2.8 `TFLoading`
- **Modos (`TFLoadingMode`):** `inline` (16px), `section` (32px) e `page` (44px).
- **Recursos:** Mensagem de status opcional centralizada abaixo do spinner, utilizando a cor primária dinâmica do tema ativo.

### 2.9 `TFSyncIndicator`
- **Estados (`TFSyncState`):** `online`, `offline`, `syncing`, `pending`, `synced`, `error`, `conflict`.
- **Apresentação:** Pílula visual com ícone representativo, rótulo textual e suporte a modo `compact: true` (ícone com tooltip e toque interativo). Desacoplado da camada de dados nesta etapa.

---

## 3. Exemplos de Uso das APIs

### 3.1 Exemplo: TFButton
```dart
TFButton(
  label: 'Salvar alterações',
  leadingIcon: TFIcons.save,
  variant: TFButtonVariant.primary,
  size: TFButtonSize.medium,
  onPressed: () => salvarDados(),
)
```

### 3.2 Exemplo: TFIconButton
```dart
TFIconButton(
  icon: TFIcons.edit,
  tooltip: 'Editar atividade',
  variant: TFIconButtonVariant.standard,
  onPressed: () => abrirEditor(),
)
```

### 3.3 Exemplo: TFStatusBadge
```dart
TFStatusBadge(
  label: 'Em execução',
  severity: TFStatusSeverity.info,
  icon: TFIcons.sync,
)
```

### 3.4 Exemplo: TFTextField
```dart
TFTextField(
  controller: _descricaoController,
  label: 'Descrição da Demanda',
  hint: 'Informe os detalhes técnicos',
  required: true,
  errorText: _erroValidacao,
  onChanged: (texto) => validar(texto),
)
```

### 3.5 Exemplo: TFPageHeader
```dart
TFPageHeader(
  title: 'Ordens de Manutenção',
  subtitle: 'Visão consolidada SAP PM',
  primaryAction: TFButton(
    label: 'Nova Ordem',
    leadingIcon: TFIcons.add,
    onPressed: () => criarOrdem(),
  ),
  secondaryActions: [
    TFIconButton(
      icon: TFIcons.refresh,
      tooltip: 'Recarregar dados',
      onPressed: () => recarregar(),
    ),
  ],
)
```

---

## 4. Regras de Desenvolvimento (DO & DON'T)

### DO (Boas Práticas)
- ✅ **Usar sempre os componentes `TF*`** para novos fluxos ou telas autorizadas.
- ✅ **Passar sempre `tooltip`** descritivo e claro no `TFIconButton`.
- ✅ **Usar `TFStatusSeverity`** pura; mapeie códigos de domínio em camadas de adaptação.
- ✅ **Respeitar os tamanhos padrão** (`small`, `medium`, `large`) em vez de definir dimensões arbitrárias.
- ✅ **Validar a renderização nos 3 temas** (`Light`, `Dark` e `Axia`).

### DON'T (Antipadrões Proibidos)
- ❌ **Não criar outro botão** apenas porque precisa de uma cor diferente; utilize as variantes semânticas.
- ❌ **Não passar `Color(...)` diretamente** para dentro dos componentes; as cores derivam do tema.
- ❌ **Não colocar lógica de regras SAP ou backend** dentro de `TFStatusBadge` ou `TFSyncIndicator`.
- ❌ **Não usar `TFCard` como container genérico** para tudo; ele é destinado a agrupamentos coesos de superfície.
- ❌ **Não duplicar spinners de loading** nas telas; use `TFLoading`.
- ❌ **Não migrar telas produtivas** sem o plano formal de migração aprovado.

---

## 5. Qualidade, Testes e Análise Estática

- **Análise Estática (`flutter analyze lib/design_system test/design_system`):**
  - **0 erros, 0 avisos**.
- **Suíte de Testes Unitários (`flutter test test/design_system/`):**
  - **23 testes executados, 23 aprovados (100% de sucesso)**.
  - Testes cobrem:
    - Renderização e callbacks de clique do `TFButton`;
    - Estados `disabled` e `loading` (sem múltiplos cliques);
    - Compatibilidade do `TFButton` nos 3 temas (Light, Dark e Axia);
    - Tooltip obrigatório e acessibilidade do `TFIconButton`;
    - Severidades visuais do `TFStatusBadge`;
    - Validação e entrada de texto do `TFTextField`;
    - Interatividade e variantes do `TFCard`;
    - Comportamento de layout do `TFPageHeader`;
    - Ações do `TFEmptyState`;
    - Modos de carregamento do `TFLoading`;
    - Estados de sincronização do `TFSyncIndicator`.
