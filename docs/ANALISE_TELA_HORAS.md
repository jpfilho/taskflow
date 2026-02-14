# Análise completa da tela de Horas

## 1. Visão geral

A **tela de Horas** exibe apontamentos de horas SAP (lançamentos de trabalho real) e um dashboard de metas por empregado/mês. Ela é acessada pelo menu lateral (ícone "Horas", índice 20) e possui dois modos de visualização: **Tabela** e **Metas**, sincronizados com a footbar do app.

### Arquivos principais

| Arquivo | Função |
|--------|--------|
| `lib/widgets/horas_sap_view.dart` | Container da tela: header, alternância Tabela/Metas, refresh, conteúdo e paginação |
| `lib/widgets/horas_metas_view.dart` | Dashboard de metas: cards de estatísticas, filtros ano/mês/empregados, tabela por empregado/mês |
| `lib/services/hora_sap_service.dart` | Serviço: `getAllHoras`, `contarHoras`, `getHorasPorEmpregadoMes`, `_buscarHorasProgramadas` |
| `lib/models/hora_sap.dart` | Modelo de um registro de hora SAP |
| `lib/models/horas_empregado_mes.dart` | Modelo agregado por empregado/mês (horas apontadas, extras, programadas, meta, status) |

---

## 2. Estrutura da tela

### 2.1 HorasSAPView (container)

- **Estado:**
  - `_horas`: lista da página atual (modo Tabela).
  - `_totalHoras`: total de registros (para paginação).
  - `_paginaAtual`, `_itensPorPagina` (50): paginação.
  - `_modoVisualizacao`: `'tabela'` ou `'metas'` (inicial `'metas'`).
  - `_searchQuery`: termo de busca (vindo do `main.dart`).
  - `_metasViewKey`: key para forçar rebuild do `HorasMetasView` no refresh.

- **Layout:**
  - **Desktop/tablet:** header com título "Horas", `SegmentedButton` (Tabela / Metas), botão Atualizar.
  - **Mobile:** header não mostra esses controles; Tabela/Metas ficam na footbar.
  - Conteúdo: em "metas" → `HorasMetasView`; em "tabela" → loading, empty ou `_buildTabelaView()`.
  - Rodapé: paginação só no modo Tabela quando `_totalHoras > _itensPorPagina`.

- **Integração com Main:**
  - `main.dart` passa `searchQuery: _searchQuery`, `modoVisualizacao: _horasViewMode`, `onModoChange` e exibe na footbar os botões "Tabela" e "Metas" quando `_sidebarSelectedIndex == 20`.

### 2.2 Modo Tabela

- **Fonte de dados:** `HoraSAPService.getAllHoras()` com:
  - Janela fixa: **últimos 3 meses** (`dataLancamentoInicio` / `dataLancamentoFim`).
  - `limit` e `offset` para paginação (50 itens por página).
  - Filtros de perfil (centro de trabalho) aplicados no serviço.

- **Busca:** apenas **local** (client-side). Se `_searchQuery` não estiver vazio, filtra a página atual por:
  - ordem, nomeEmpregado, numeroPessoa, centroTrabalhoReal, tipoAtividadeReal, statusSistema (tudo em lowercase).

- **UI:** `DataTable` com scroll horizontal e colunas: Ações (ver detalhes), Data Lançamento, Ordem, Tipo Ordem, Operação, Trab. Real/Planejado/Restante, Tipo Atividade, Nome Empregado, Número Pessoa, Centro Trabalho, Status Sistema, Início Real, Fim Real, Hora Início. Botão "Visualizar" abre um `AlertDialog` com todos os campos da hora.

- **Paginação:** botões anterior/próximo e texto "Página X de Y".

### 2.3 Modo Metas (HorasMetasView)

- **Fonte de dados:** `HoraSAPService.getHorasPorEmpregadoMes(ano, mes)`:
  - Lista de executores conforme perfil (segmento/divisão ou todos se root).
  - Apenas executores com matrícula e empresa própria.
  - Horas lidas de `horas_sap` (filtradas por centros de trabalho do perfil e por matrículas dos executores).
  - Ano obrigatório; mês opcional (null = todos os meses do ano).
  - Metas mensais: dias úteis do mês (excluindo sábado, domingo e feriados) × 8h.
  - Horas extras: soma de `trabalho_real` onde `tipo_atividade_real` começa com "HHE".
  - Horas programadas: VIEW `horas_programadas_por_empregado_mes` (atividades, excluindo FÉRIAS e COMPENSAÇÃO).

- **Modelo exibido:** `HorasEmpregadoMes`: numeroPessoa, nomeEmpregado, matricula, ano, mes, horasApontadas, horasFaltantes, semApontamento, horasExtras, tiposAtividade, metaMensal, horasProgramadas.

- **Filtros na tela:**
  - **Ano:** dropdown (atual −2 até atual +2).
  - **Mês:** dropdown (Todos + Janeiro–Dezembro).
  - **Empregados:** multi-seleção via `MultiSelectFilterDialog` (lista = "Nome (Matrícula)").

- **Dashboard (cards):**
  - Total de Colaboradores (únicos no resultado filtrado).
  - Horas Totais Registradas.
  - Status das Metas: metas atingidas vs pendentes e percentual (gráfico circular).

- **Tabela:** uma linha por combinação empregado/mês (agrupado por `nomeEmpregado_matricula`), com:
  - Empregado, Matrícula, Mês, Horas Apontadas (com barra de progresso e indicação de Prog./HHE), Horas Faltantes, Status (Sem Apontamento / Abaixo da Meta / Em Risco / Meta Atingida), **Ordens** (botão "Ver").
  - Cores de status: verde (≥ meta), laranja (≥ 75% da meta), vermelho (< 75% ou sem apontamento).
  - Duas barras por linha: horas programadas (azul) e horas apontadas (verde/laranja/vermelho) + horas extras (laranja).
  - **Ordens:** ao clicar em "Ver" abre um dialog com: (1) **Ordens programadas** (atribuídas nas tarefas ao empregado naquele mês) e quantas horas ele já apontou em cada uma; (2) **Ordens não programadas** (apontou horas em ordens que não estavam nas tarefas dele), com as horas apontadas. Fonte: VIEWs `ordens_programadas_por_empregado_mes` e `horas_apontadas_por_empregado_ordem_mes`.

- **Comportamento:** Um único empregado disponível é auto-selecionado no filtro. Refresh via `onRefresh` (botão na tela e callback do pai).

---

## 3. Serviço (HoraSAPService)

### 3.1 Perfil e segurança

- **Root:** sem filtro de centro de trabalho; vê todos os dados dentro da janela de datas.
- **Usuário com perfil:** filtro por centros de trabalho permitidos (regional, divisão, segmento). Se tem perfil mas nenhum centro permitido → lista vazia / zero.
- **Metas:** lista de executores por segmento (ou divisão, ou todos ativos); apenas ativos, com matrícula e empresa própria. Horas e horas programadas restritas às matrículas e aos centros do perfil.

### 3.2 getAllHoras / contarHoras

- Tabela: `horas_sap`.
- Janela padrão: últimos 3 meses por `data_lancamento`.
- Filtros opcionais: tipo_ordem, ordens, operações, tipo_atividade_real, numero_pessoa, nome_empregado, status_sistema, centro_trabalho_real (com `ilike` quando aplicável).
- Ordenação: `data_lancamento` descendente.
- `contarHoras` usa os mesmos filtros e retorna quantidade (select em `id`).

### 3.3 getHorasPorEmpregadoMes

- Obtém executores do perfil (segmento/divisão ou todos).
- Busca em `horas_sap` com filtro de centros e matrículas; ano/mês ou janela de 12 meses.
- Agrupa por numero_pessoa e ano-mês; calcula totais, HHE e tipos de atividade.
- Para cada executor/mês: calcula dias úteis (com `FeriadoService`), meta = dias úteis × 8, horas faltantes, semApontamento.
- Chama `_buscarHorasProgramadas(ano, mes, matriculas)` na VIEW `horas_programadas_por_empregado_mes` e preenche `horasProgramadas` em cada `HorasEmpregadoMes`.

### 3.4 _buscarHorasProgramadas

- VIEW: `horas_programadas_por_empregado_mes` (matricula, ano, mes, ano_mes, regional_id, divisao_id, segmento_id, horas_programadas).
- Filtra por ano/mês ou último ano; por matrículas; e por regional/divisão/segmento do usuário (com filtro adicional em memória para garantir AND entre dimensões).

---

## 4. Pontos de atenção e melhorias sugeridas

### 4.1 Busca no modo Tabela

- A busca é **somente na página atual** (50 itens). Para muitas horas, o usuário pode não ver resultados que estão em outras páginas.
- **Sugestão:** enviar `_searchQuery` ao backend (ex.: parâmetros no `getAllHoras`/`contarHoras`) para filtrar no servidor e paginar sobre o resultado filtrado.

### 4.2 Janela de datas fixa (3 meses)

- A tabela não permite o usuário escolher período; sempre últimos 3 meses.
- **Sugestão:** filtros opcionais de data inicial/final (ou presets: último mês, 3 meses, 6 meses, ano) no header da tela de Horas.

### 4.3 Consistência da busca global

- A barra de busca do app passa `searchQuery` para a tela de Horas, mas só o modo Tabela usa; o modo Metas ignora.
- **Sugestão:** documentar esse comportamento ou, se desejado, aplicar o termo no modo Metas (ex.: filtrar por nome/matrícula na lista de empregados).

### 4.4 Performance

- `getHorasPorEmpregadoMes` pode carregar muitos registros de `horas_sap` e depois agregar em memória; `_buscarHorasProgramadas` faz outra ida ao Supabase.
- Já existem índices (ex.: `otimizar_horas_sap_indices_v2.sql`). Manter índices em `data_lancamento`, `numero_pessoa`, `centro_trabalho_real` e na VIEW de horas programadas.
- **Sugestão:** para perfis grandes, considerar agregar no backend (view/materialized view ou RPC) em vez de trazer todas as linhas.

### 4.5 UX mobile

- No mobile o header da tela de Horas não mostra Tabela/Metas nem refresh; dependem da footbar.
- **Sugestão:** garantir que na footbar, quando índice 20 está selecionado, os dois botões (Tabela e Metas) estejam sempre visíveis e claros.

### 4.6 Tratamento de erros

- Erros em `_loadHoras` e `_carregarDados` mostram SnackBar vermelho; em `getHorasPorEmpregadoMes` há vários `print` de debug.
- **Sugestão:** manter mensagens amigáveis na UI e concentrar logs técnicos (ou remover em produção).

### 4.7 Tema

- Cores fixas (ex.: `Colors.blue[50]`, `Colors.white`, `Colors.grey`) em vez de `Theme.of(context)`.
- **Sugestão:** usar cores do tema (e `ColorScheme`) para suportar dark mode e consistência com o resto do app.

---

## 5. Fluxo de dados (resumo)

```
Main (índice 20, _horasViewMode, _searchQuery)
  → HorasSAPView(searchQuery, modoVisualizacao, onModoChange)
       │
       ├─ modo "tabela"
       │     → _loadHoras() → getAllHoras(limit, offset, últimos 3 meses)
       │     → contarHoras(últimos 3 meses)
       │     → filtro local por _searchQuery
       │     → _buildTabelaView() → DataTable + dialog de detalhes
       │     → paginação (offset/limit)
       │
       └─ modo "metas"
             → HorasMetasView(onRefresh)
                   → _carregarDados() → getHorasPorEmpregadoMes(ano, mes)
                   → filtros: ano, mês, multi empregados
                   → _calcularEstatisticas() sobre _dadosFiltrados
                   → _buildTabelaCompacta() → DataTable com barras e status
```

---

## 6. Dependências

- **Supabase:** tabela `horas_sap`, VIEW `horas_programadas_por_empregado_mes`.
- **Serviços:** `AuthServiceSimples`, `CentroTrabalhoService`, `ExecutorService`, `FeriadoService`.
- **Widgets:** `MultiSelectFilterDialog` (em `horas_metas_view.dart`).
- **Modelos:** `HoraSAP`, `HorasEmpregadoMes`, `Executor`.

---

*Documento gerado com base no código em fev/2026.*
