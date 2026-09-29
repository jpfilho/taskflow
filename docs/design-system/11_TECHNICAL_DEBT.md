# TaskFlow Design System — Mapa de Dívida Técnica Visual

> **Status:** Concluído  
> **Data:** Setembro de 2026

---

## 1. Classificação de Severidade

* **`P0 (CRITICAL)`**: Prejudica diretamente a operação diária, causa erros de renderização (*overflow*), bloqueia fluxos ou quebra a usabilidade em dispositivos móveis/desktop.
* **`P1 (HIGH)`**: Severa inconsistência visual entre módulos centrais, baixo contraste em textos importantes ou quebra de acessibilidade em ações críticas.
* **`P2 (MEDIUM)`**: Duplicações de widgets, estilos manuais repetidos, desalinhamento de espaçamentos e falta de padronização de botões.
* **`P3 (LOW / POLISH)`**: Polimento fino, animações de transição, refinamento de micro-espaçamentos.

---

## 2. Inventário de Dívida Técnica Visual

### 2.1 Severidade P0 (Crítica)

#### [P0-01] Arquivos Monolíticos de Interface com Alta Densidade
* **Arquivos Impactados:**
  * [`lib/widgets/notas_sap_view.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/notas_sap_view.dart) (3.914 linhas)
  * [`lib/widgets/ordem_view.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/ordem_view.dart) (3.263 linhas)
  * [`lib/widgets/task_table.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/task_table.dart) (3.795 linhas)
  * [`lib/widgets/task_form_dialog.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/task_form_dialog.dart) (282 KB)
  * [`lib/main.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/main.dart) (3.831 linhas)
* **Impacto:** Arquivos gigantes que misturam regras de UI, requisições de serviço e cálculos de layout. Dificulta manutenção e gera *rebuilds* desnecessários de telas inteiras a cada clique em filtros.
* **Recomendação:** Decompor em sub-widgets reutilizáveis de visualização (`TFDataTable`, `TFPageHeader`, `TFFilterBar`).

#### [P0-02] Largura Rígida de Tabela em Monitores Médios
* **Arquivo:** [`lib/utils/responsive.dart:58`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/utils/responsive.dart#L58) (`return 1200; // Desktop: largura fixa`)
* **Impacto:** Em laptops comuns de 1366x768 com a Sidebar expandida, gera corte de conteúdo e exige scroll horizontal desnecessário.
* **Recomendação:** Tornar a tabela fluida com flex e larguras mínimas baseadas em colunas (`minWidth` ponderado).

---

### 2.2 Severidade P1 (Alta)

#### [P1-01] Mais de 89% dos Botões de Ícone Sem Rótulo Acessível (Tooltip)
* **Evidência:** 413 instâncias de `IconButton` vs apenas 44 instâncias de `Tooltip`.
* **Impacto:** Violação de acessibilidade e hesitação operacional de operadores novatos ou que atuam em campo sob luz solar forte.
* **Recomendação:** Adoção de `TFIconButton` com tooltip tipado como obrigatório.

#### [P1-02] 34 Implementações Divergentes de Status Badges
* **Evidência:** Funções como `_getStatusColor`, `_buildStatusBadge`, `_buildPrazoBadge` espalhadas em mais de 30 arquivos. Cada uma aplica suas próprias cores (`Colors.black` para cancelado em um arquivo vs `Colors.grey` em outro; `Colors.amber` para análise vs `Colors.orange`).
* **Impacto:** Falta de clareza semântica: o mesmo status tem cores e formatos diferentes conforme a tela onde é visualizado.
* **Recomendação:** Centralizar em `TFStatusBadge` com o enum `TaskFlowStatusStyle`.

#### [P1-03] Quebra Visual do Modo Escuro (Dark Mode)
* **Evidência:** Telas legadas utilizam `Colors.white` rígido como fundo de containers e `Colors.black87` em textos. Ao alternar para o tema Dark, o `scaffoldBackgroundColor` fica escuro, mas os cards permanecem brancos com bordas duras e textos apagados.
* **Recomendação:** Substituir literais por tokens semânticos (`tokens.colors.surface`, `tokens.colors.textPrimary`).

---

### 2.3 Severidade P2 (Média)

#### [P2-01] 2.134 Estilos de Texto (`TextStyle`) Hardcoded
* **Evidência:** 22 tamanhos diferentes de fonte espalhados pelo código.
* **Impacto:** Dificuldade para alterar a escala de densidade do aplicativo de forma global.
* **Recomendação:** Migração gradual para a escala `TFTypography`.

#### [P2-02] 19 Raios de Borda Distintos
* **Evidência:** Raios variando entre 2px, 3px, 4px, 6px, 8px, 10px, 12px, 16px, 20px, 24px.
* **Recomendação:** Unificar na escala `TFRadius` (predomínio de 8px e 12px).
