# TaskFlow Design System — Componentes Base Propostos

> **Status:** Proposta Técnica Detalhada  
> **Data:** Setembro de 2026

---

## 1. Critério de Inclusão no Design System

Seguindo o princípio de **não criar overengineering**, um componente só é promovido a componente base do TaskFlow Design System se atender cumulativamente a:
1. **Reutilização comprovada:** utilizado em pelo menos 3 módulos distintos.
2. **Impacto na consistência:** elimina estilos ou comportamentos divergentes.
3. **Custo justificável de manutenção:** abstrai complexidade sem engessar customizações legítimas de domínio.

Componentes ultrassensíveis ao domínio (como o algoritmo de desenho de barras do Gantt ou visualizadores KMZ de linhas de transmissão) **permanecem em seus respectivos módulos**, consumindo apenas os tokens de fundação (`TFColors`, `TFTypography`, `TFSpacing`).

---

## 2. Catálogo dos Componentes Base (`TF*`)

### 2.1 Ações & Botões

#### `TFButton`
Substitui as dezenas de `ElevatedButton`, `FilledButton`, `TextButton` e `OutlinedButton` manuais.
* **Variantes:**
  * `primary`: Fundo azul de marca (`primaryBlue`), texto branco. Usado para a ação principal da tela/modal (Salvar, Confirmar).
  * `secondary`: Fundo neutro sutil ou borda (`borderDefault`). Ações secundárias.
  * `ghost` / `tertiary`: Sem fundo e sem borda. Usado em "Cancelar", "Voltar".
  * `danger`: Fundo vermelho (`danger`). Exclusão, cancelamento de ordem, estorno.
* **Tamanhos:**
  * `sm` (32px altura - ideal para toolbars de tabela), `md` (40px altura - padrão), `lg` (48px altura - diálogos e mobile).
* **Recursos nativos:** Suporte a `isLoading: true` (com spinner integrado que não deforma a largura do botão) e `iconLeading` / `iconTrailing`.

#### `TFIconButton`
Substitui os 413 `IconButton` do sistema.
* **Obrigatório:** Parâmetro `tooltip` requerido por tipagem para garantir acessibilidade.
* **Dimensão mínima de toque:** 40x40px (em conformidade com diretrizes operacionais), mantendo o pictograma no tamanho compacto desejado (18px a 20px).

---

### 2.2 Formulários & Entradas

#### `TFTextField`
Consolida o padrão de `FloatingLabelTextField` e `TextFormField`.
* **Estados:** default, hover, focus, disabled, readOnly, error.
* **Recursos:** Suporte a sufixo com botão de limpar (`clearable: true`), prefixos com ícone semântico, mensagens de erro que não causam "pulo" no layout vertical.

#### `TFDropdown<T>` / `TFSelect<T>`
Padroniza os 93 dropdowns do sistema.
* Suporte nativo a carregamento assíncrono (`isLoading: true`), busca rápida interna quando a lista possui mais de 8 itens e botão de limpar seleção.

#### `TFSearchField`
Especialização do campo de texto para buscas em tempo real em tabelas e listagens, com ícone de lupa fixo, debounce configurável e tecla de atalho de limpeza rápida (`Esc`).

---

### 2.3 Visualização de Dados & Tabelas

#### `TFStatusBadge`
O componente mais importante para unificar a identidade operacional do TaskFlow. Substitui as 34 funções locais identificadas (`_buildStatusBadge`, `_buildPrazoBadge`, etc.).
* **Parâmetros:**
  * `status`: Instância de `TaskFlowStatus` ou código da regra.
  * `label`: Texto explícito do status.
  * `icon`: Ícone associado ao status.
  * `severity`: `neutral`, `info`, `success`, `warning`, `critical`.
  * `diasRestantes`: Suporte a exibição de contagem regressiva de prazos SAP.

#### `TFDataTable<T>`
Componente base que resolve a heterogeneidade das 28 implementações de `DataTable`:
* Suporte nativo a 3 densidades (`dense` 30px, `compact` 38px, `comfortable` 48px).
* Cabeçalho fixo com suporte a ordenação por clique na coluna.
* Zebra striping opcional com cor sutil (`surfaceContainer`).
* Estado de carregamento integrado (skeleton shimmer) e estado vazio integrado (`TFEmptyState`).

#### `TFKpiCard`
Consolida os cards de métricas usados em `comprehensive_dashboard.dart`, `analytics_view.dart` e nos resumos de ordens e notas:
* Estrutura: Ícone no canto superior direito, título em `caption`, valor grande em `display` ou `titlePage`, indicador de tendência ou comparativo de período.

---

### 2.4 Navegação, Filtros & Layout

#### `TFPageHeader`
Componente obrigatório para o topo de todas as páginas:
* Título da página + Subtítulo operacional opcional.
* Trilha de navegação (*breadcrumbs*) quando houver hierarquia.
* Área reservada para ações primárias e secundárias à direita (`actions`).

#### `TFFilterBar`
Barra de filtros unificada e responsiva:
* No **Desktop/Web**: exibe busca rápida + 3 a 4 seletores principais em linha + botão "Mais filtros" que abre painel lateral (*Side Sheet*).
* No **Mobile**: exibe campo de busca condensado + botão flutuante/ícone com contador de filtros ativos (`[Filtros (3)]`) que abre um *Bottom Sheet*.

#### `TFDialog` & `TFConfirmDialog`
Padroniza os diálogos do sistema (atualmente 276 chamadas de `showDialog` e 118 `AlertDialog`):
* `TFConfirmDialog`: Modal específico para exclusão, cancelamento e ações destrutivas (com título claro, aviso das consequências, botão "Cancelar" e botão destrutivo em vermelho).
* `TFFormDialog`: Container com largura máxima de 512px ou 768px, área rolável protegida e rodapé fixo de ações.

#### `TFEmptyState`
Componente para quando não há registros:
* Ícone contextual estilizado.
* Frase explicativa ("Nenhuma atividade encontrada para os filtros selecionados").
* Ação sugerida ("Limpar filtros" ou "Nova Tarefa").
