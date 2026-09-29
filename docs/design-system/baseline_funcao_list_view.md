# Baseline — Estado Inicial de `lib/widgets/funcao_list_view.dart` (Antes da Migração)

## 1. Identificação do Arquivo
- **Arquivo:** `lib/widgets/funcao_list_view.dart`
- **Módulo:** Administração / Configurações
- **Linhas originais:** 423 linhas
- **Objetivo:** Cadastro, listagem, pesquisa, duplicação e exclusão de Funções/Cargos do sistema TaskFlow.

---

## 2. Diagnóstico Visual e Técnico Inicial

### 2.1 Layout & Shell
- Utiliza `Scaffold` com `AppBar` padrão do Flutter.
- O título é um `Text('Cadastro de Funções')` estático sem subtítulo explicativo.
- As ações no AppBar utilizam `IconButton(icon: Icon(...))` soltos sem padronização de tamanho ou touch target.

### 2.2 Busca e Filtros
- Utiliza `TextField` padrão do Flutter envolto em `Padding(padding: EdgeInsets.all(16.0))` com magic number.
- `OutlineInputBorder()` sem vinculação às cores de borda (`borderDefault`, `borderFocus`) do Design System.

### 2.3 Visualização em Lista (Cards)
- Utiliza `Card` do Material Design com `ListTile`.
- Cores hardcoded: `Colors.green` e `Colors.red` diretamente em `Icon(Icons.check_circle, color: Colors.green)`.
- Ações no trailing: 3 `IconButton` com cores soltas (`Colors.orange`, `Colors.red`).

### 2.4 Visualização em Tabela (DataTable)
- `DataTable` legado com `headingRowColor: WidgetStateProperty.all(Colors.blue[50])` (quebra em Dark Mode e Axia).
- Badge de status construído manualmente com `Container(color: funcao.ativo ? Colors.green[100] : Colors.red[100])` e texto `funcao.ativo ? Colors.green[800] : Colors.red[800]`.
- Magic numbers: `BorderRadius.circular(12)`.
- Ações na célula: `IconButton` com `padding: EdgeInsets.zero`, `constraints: BoxConstraints()`, cores hardcoded (`Colors.blue`, `Colors.orange`, `Colors.red`).

### 2.5 Estados de Feedback
- `CircularProgressIndicator()` genérico centralizado, sem escala nem mensagem explicativa.
- Empty state: `Center(child: Text('Nenhuma função encontrada.'))` texto cru e simples, sem ícone, descrição ou botão de ação orientativo.

### 2.6 Acessibilidade & Temas
- Cores hardcoded (`Colors.blue[50]`, `Colors.green[100]`, `Colors.red[100]`) sem contraste calibrado para Dark Mode.
- Tooltips genéricos ("Editar", "Duplicar", "Excluir") sem contextualização com o registro ("Editar função", "Duplicar função").

---

## 3. Plano de Migração Piloto com Componentes TFDS

| Elemento Legado | Componente TFDS Alvo | Melhoria Realizada |
| :--- | :--- | :--- |
| `AppBar` padrão | `TFPageHeader` | Título estruturado, subtítulo explicativo, botões de ação organizados |
| Botão "Nova Função" no AppBar | `TFButton(variant: primary, leadingIcon: add)` | Ação de criação destacada com hierarquia primária clara |
| Toggle Tabela / Lista | `TFIconButton(variant: subtle)` | Touch target mínimo 40x40, tooltip contextualizado |
| `TextField` de busca | `TFTextField` com `TFIcons.search` | Borda dinâmica (`borderDefault`/`borderFocus`), altura por densidade |
| `Card` + `ListTile` | `TFCard(variant: defaultCard)` | Borda flat + border, espaçamento com `TFSpacing`, tipografia `TFTypography` |
| Badge manual `green[100]` / `red[100]` | `TFStatusBadge` (adapter local) | `TFStatusSeverity.success` / `TFStatusSeverity.neutral` com ícone + cor + texto |
| `IconButton` de ação | `TFIconButton` | Tooltip com contexto ("Editar função", "Duplicar função", "Excluir função") |
| `Text('Nenhuma função encontrada.')` | `TFEmptyState` | Ícone `TFIcons.search`, mensagem de orientação e botão "Nova Função" ou "Limpar busca" |
| `CircularProgressIndicator()` | `TFLoading(mode: section)` | Spinner padronizado com mensagem contextual |
| `DataTable` legado | Preservado temporariamente | Estilizado com tokens de superfície e texto sem criar `TFDataTable` precoce |

---

## 4. Preservação Estrita de Comportamento
- `_loadFuncoes()`, `_searchFuncoes()`, `_createFuncao()`, `_duplicateFuncao()`, `_editFuncao()`, `_deleteFuncao()` permanecem **100% inalterados**.
- Nenhuma chamada ao `FuncaoService`, Supabase ou SQLite será modificada.
