# TaskFlow Design System — Component Inventory

| Componente Conceitual | Implementações Atuais no Código | Arquivos Principais | Variações Observadas | Componente Proposto | Ação Recomendada |
| :--- | :---: | :--- | :--- | :--- | :--- |
| **Botão de Ação Primária** | 295 | `ElevatedButton`, `FilledButton`, `CustomButton` | Cores azuis (#3B82F6, Colors.blue, Colors.blue[700]), paddings arbitrários | `TFButton.primary` | **Consolidar** |
| **Botão Secundário / Cancelar** | 351 | `TextButton`, `OutlinedButton` | Textos cinzas variados, sem borda vs com borda fina | `TFButton.secondary` / `TFButton.ghost` | **Consolidar** |
| **Botão de Ícone** | 413 | `IconButton` direto | 89% sem tooltip, tamanhos de 16px a 28px, hit targets menores que 40px | `TFIconButton` | **Consolidar (Obrigatório Tooltip)** |
| **Status Operacional / Badge** | 34 | `_buildStatusBadge`, `_buildPrazoBadge`, `_buildInfoChip` em 30+ arquivos | Cores manuais (Colors.green, red, orange, black), opacidades variadas (0.1 a 0.3) | `TFStatusBadge` | **Consolidar** |
| **Campo de Texto** | 211 | `FloatingLabelTextField`, `TextFormField`, `TextField` | Floating label em alguns dialogs; bordas manuais; underlines legados | `TFTextField` | **Consolidar** |
| **Seletor Dropdown** | 93 | `FloatingLabelDropdown`, `DropdownButtonFormField`, `DropdownButton` | Menus com fundo transparente, estilos de texto inline, validações manuais | `TFDropdown` | **Consolidar** |
| **Campo de Busca Rápida** | 42 | `TextField` com prefixIcon `Icons.search` | Alturas e decorações distintas em cada tela | `TFSearchField` | **Consolidar** |
| **Barra de Filtros** | 6 | `filter_bar.dart`, barras internas em Notas, Ordens, Mídia, Documentos | Linhas de 1.300+ linhas misturando lógica com UI | `TFFilterBar` | **Consolidar** |
| **Tabela de Dados** | 28 | `DataTable` em 28 arquivos + `TaskTable` (3.795 lin) | Alturas de linha variando de 30px a 56px, zebra striping manual | `TFDataTable` | **Consolidar** |
| **Card de Indicador (KPI)** | 18 | Containers em `comprehensive_dashboard.dart`, `dashboard.dart`, `analytics_view.dart` | Layouts de ícone + número + rótulo recriados do zero | `TFKpiCard` | **Consolidar** |
| **Diálogo de Confirmação** | 118 | `AlertDialog` direto com botões `TextButton` | Textos de confirmação inconsistentes ("OK", "Sim", "Confirmar") | `TFConfirmDialog` | **Consolidar** |
| **Diálogo de Formulário** | 54 | `ModernFormDialog`, `Dialog`, `SimpleDialog` | Larguras entre 400px e 800px, headers manuais | `TFFormDialog` | **Consolidar** |
| **Estado Vazio (Empty State)**| 36 | `Center(child: Text('Nenhum registro...'))` | Mensagens frias sem instrução de desbloqueio ou ação | `TFEmptyState` | **Consolidar** |
| **Indicador de Carregamento** | 48 | `CircularProgressIndicator()` solto | Ausência de Skeletons para tabelas e cards | `TFLoading` / `TFSkeleton` | **Criar e Padronizar** |
| **Status de Sincronização** | 1 | `SyncStatusWidget` | Restrito a telas não-web, sem badges em itens individuais | `TFSyncIndicator` | **Evoluir** |
| **Painel Redimensionável** | 1 | `ResizablePanel` | Bem implementado em Programação de Atividades | `TFResizablePanel` | **Preservar** |
