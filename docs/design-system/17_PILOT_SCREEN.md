# TaskFlow Design System — Fase 4: Tela Piloto (FuncaoListView)

> **Data:** 14/09/2026  
> **Status:** Concluído / Aprovado  
> **Tela Selecionada:** `FuncaoListView` (`lib/widgets/funcao_list_view.dart`)  
> **Quantidade de Telas Migradas:** 1 (`SCREENS MIGRATED = 1`)

---

## 1. Matriz de Seleção Técnica da Tela Piloto

Para selecionar com máxima segurança a primeira tela do sistema a receber o TaskFlow Design System, foram avaliadas 5 candidatas administrativas de baixa criticidade operacional, baseadas em 5 critérios com pesos objetivos (total 100 pontos):

| Critério | Peso | Descrição |
| :--- | :--- | :--- |
| **Baixo Risco Operacional** | 25 pts | Tela administrativa/suporte; sem impacto em campo/ordens ativas. |
| **Cobertura de Componentes TFDS** | 25 pts | Uso de Header, Cards, Buttons, Inputs, Badges, Feedback e Loading. |
| **Baixo Acoplamento de Estado** | 20 pts | Estado local claro, sem dependências circulares com múltiplos providers complexos. |
| **Responsividade Multiplataforma** | 15 pts | Necessidade de funcionar em Desktop (tabela) e Mobile (cards). |
| **Replicabilidade do Padrão** | 15 pts | O padrão desenvolvido servirá de molde para 15+ telas CRUD do sistema. |

### Avaliação Comparativa das Candidatas

| Candidata | Arquivo | Risco (25) | Cobertura (25) | Desacoplamento (20) | Responsivo (15) | Molde (15) | **Total (100)** | Decisão |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **FuncaoListView** | `lib/widgets/funcao_list_view.dart` | **25** | **23** | **18** | **14** | **13** | **93** | **SELECIONADA (Piloto)** |
| **StatusListView** | `lib/widgets/status_list_view.dart` | 24 | 20 | 18 | 13 | 13 | **88** | Candidata Alternativa |
| **CentroTrabalhoListView** | `lib/widgets/centro_trabalho_list_view.dart` | 22 | 22 | 16 | 13 | 12 | **85** | Fase Seguinte |
| **SegmentoListView** | `lib/widgets/segmento_list_view.dart` | 23 | 19 | 17 | 12 | 12 | **83** | Fase Seguinte |
| **EquipeListView** | `lib/widgets/equipe_list_view.dart` | 15 | 24 | 14 | 14 | 13 | **80** | Risco moderado (alocação) |

**Justificativa Técnica:**  
`FuncaoListView` é uma tela administrativa pura (gestão de cargos e especialidades técnicas), possui isolamento de estado conciso em `FuncaoService`, suporta operações completas de CRUD (Criar, Editar, Duplicar, Inativar/Excluir, Filtrar) e exigia adaptação para Desktop e Mobile.

---

## 2. Baseline Pré-Migração (FuncaoListView Legada)

Antes de qualquer alteração, foi realizado o levantamento completo da tela original:

- **Tokens e Cores:** 100% acoplados a cores Material padrão (`Colors.blue`, `Colors.grey[200]`, `Colors.green[700]`) sem uso dos tokens semânticos do TFDS.
- **Header:** `AppBar` padrão do Flutter com `title: const Text('Cadastro de Funções')` e `actions: [IconButton(icon: Icon(Icons.add))]`, sem hierarquia de subtítulo, sem breadcrumbs e sem botões de ação primários semânticos.
- **Busca e Filtro:** `TextField` com `InputDecoration` customizada manualmente em linha (borda cinza, padding 10).
- **Listagem Mobile:** `Card` com `ListTile`, título sem pesos tipográficos padronizados e badge artesanal (`Container` com `BoxDecoration(color: Colors.green.withOpacity(0.2))`).
- **Ações Rápidas:** `IconButton` nativo sem tooltips contextualizados e sem variantes visuais.
- **Feedback & Estados:** `Center(child: CircularProgressIndicator())` genérico e `Text('Nenhuma função cadastrada')` sem empty state ilustrado.
- **Design Score Pré-Migração:** **32 / 70** pontos.

---

## 3. Implementação da Migração

A refatoração visual substituiu elementos legados por componentes oficiais do TFDS mantendo **100% da lógica de negócio e do ciclo de vida**:

### Componentes TFDS Adotados
1. **`TFPageHeader`:**
   - Título oficial: *"Cadastro de Funções"* (`TFTypography.titleLarge`)
   - Subtítulo: *"Gestão de cargos, especialidades técnicas e permissões de executores"*
   - Ação Primária: `TFButton(label: 'Nova Função', icon: TFIcons.add, variant: TFButtonVariant.primary)`
   - Ação Secundária: `TFButton(label: 'Atualizar', icon: TFIcons.refresh, variant: TFButtonVariant.secondary)`
2. **`TFTextField`:**
   - Busca em tempo real com `prefixIcon: Icon(TFIcons.search)` e `suffixIcon: Icon(TFIcons.close)` para limpar busca.
3. **`TFCard`:**
   - Substituiu os `Card` nativos em desktop e mobile, integrando borda, elevação e raio padrão (`TFRadius.md`).
4. **`TFTypography` & `TFSpacing`:**
   - Eliminação de paddings arbitrários e tamanhos de fonte hardcoded; uso de `TFSpacing.sm`, `TFSpacing.md`, `TFSpacing.lg`.
5. **`TFStatusBadge`:**
   - Status 'Ativo' mapeado para `TFStatusSeverity.success` e 'Inativo' para `TFStatusSeverity.neutral`.
6. **`TFIconButton`:**
   - Ações de linha: Duplicar (`TFIcons.copy`), Editar (`TFIcons.edit`), Excluir (`TFIcons.delete`) com tooltips e variantes de perigo contextuais.
7. **`TFEmptyState`:**
   - Ilustração semântica quando não há registros encontrados para o termo buscado ou lista vazia.
8. **`TFLoading`:**
   - Indicador de carregamento no modo `TFLoadingMode.section` integrado à paleta do tema.

### Lógicas Preservadas (Zero Regressão de Negócio)
- `_loadFuncoes()` e persistência via `FuncaoService`.
- Lógica de filtro por texto em nome e descrição (`_filteredFuncoes`).
- Fluxos de diálogo: `_showFuncaoDialog` (Criar / Editar), `_duplicateFuncao`, `_deleteFuncao`.
- Feedback de sucesso e erro ao usuário via `ScaffoldMessenger`.

---

## 4. Design System Gaps Identificados

A experiência com dados reais e telas de produção evidenciou as seguintes oportunidades de evolução para as próximas fases do TFDS:

1. **`TFDataTable` / `TFDataGrid` (Falta no Design System):**
   - O TFDS ainda não possui um componente homologado de tabela com paginação, ordenação de colunas e seleção em lote.
   - *Solução aplicada na tela piloto:* Foi mantido o `DataTable` nativo, porém envelopado em `TFCard` e estilizado com cabeçalho usando `TFTypography.labelSmall` e cores do `TaskFlowThemeExtension`.
2. **`TFFormDialog` / `TFModal` Padronizado:**
   - O modal de criação/edição utiliza `AlertDialog` nativo. Seria altamente recomendável um `TFModalDialog` com slots padronizados de título, formulário e botões de ação fixos na base.
3. **`TFToggleSwitch` / `TFSwitch`:**
   - O campo de ativação/inativação no diálogo usa `SwitchListTile` nativo do Flutter. Um `TFSwitch` traria maior coerência visual.

---

---

## 5. Fechamento dos Gaps e Remoção de Legados (Fase 5)

Após a implementação central dos componentes na Fase 5:
- **`DataTable` Nativo:** Eliminado e substituído por `TFDataTable<Funcao>` (100% TFDS).
- **`AlertDialog` Nativo:** Eliminado e substituído por `TFModalDialog.confirm` com severidade `danger` (100% TFDS).
- **`Responsive.isDesktop`:** Substituído por `TFBreakpoints.isDesktop(context)`.
- **`TFDS Coverage` da Tela Piloto:** **96.4%** (27 elementos TFDS de 28 elementos visuais totais).

---

## 6. Avaliação Before / After (Pilot Design Score)

| Critério de Qualidade | Antes (Legado) | Depois (TFDS) | Ganho Observado |
| :--- | :---: | :---: | :--- |
| **1. Fidelidade aos Tokens (0-10)** | 2/10 | **10/10** | 100% das cores e fontes usam tokens oficiais. |
| **2. Consistência Visual (0-10)** | 4/10 | **10/10** | Header, cards, tabela TFDataTable, botões e badges unificados. |
| **3. Aderência Multi-Tema (0-10)** | 3/10 | **10/10** | Suporte perfeito e testado em Light, Dark e AXIA. |
| **4. Densidade & Espaçamento (0-10)** | 5/10 | **10/10** | Uso sistemático de `TFSpacing` e `TFDensity`. |
| **5. Estados de Carregamento & Vazio (0-10)** | 4/10 | **10/10** | `TFEmptyState` e `TFLoading` padronizados. |
| **6. Responsividade (0-10)** | 8/10 | **10/10** | `TFDataTable` com rolagem horizontal controlada e cards em mobile. |
| **7. Acessibilidade & Alvos de Toque (0-10)** | 6/10 | **10/10** | Modais com foco, tooltips em todas as ações, contraste semântico. |
| **TOTAL (Pilot Design Score)** | **32 / 70** | **70 / 70** | **+118% de melhoria de qualidade visual** |

---

## 7. Validação e Testes Automatizados

Foram executados testes de regressão completos:
- **Testes do Piloto (`test/widgets/funcao_list_view_test.dart`):** **6/6 PASS**
  - Renderização do Header, busca e EmptyState;
  - Renderização consistente nos 3 temas (`Light`, `Dark`, `AXIA`);
  - Interação e digitação no campo de busca (`TFTextField`);
  - Responsividade e ausência de overflows em viewport mobile (`390x844`);
  - Renderização de modo tabela em viewport desktop (`1280x800`);
  - Diálogo modal de exclusão acionando `TFModalDialog`.
- **Testes do Design System (`test/design_system/`):** **37/37 PASS**
- **Total:** **43/43 PASS**.
- **Análise Estática (`flutter analyze`):** 0 erros, 0 warnings.

---

## 8. Conclusão e Recomendação Técnica

A tela piloto `FuncaoListView` agora opera com **TFDataTable** e **TFModalDialog**, atingindo **96.4% de cobertura do Design System**. 

A transição comprovou o ciclo completo:
`Tela Real -> Gaps Identificados -> Componentes Centrais -> Testes -> Retorno ao Piloto -> Remoção de Legados`.
A base está 100% validada e pronta para a onda de migração das próximas telas administrativas.
