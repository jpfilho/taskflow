# TaskFlow Design System — Responsividade & Breakpoints

> **Status:** Concluído  
> **Data:** Setembro de 2026

---

## 1. Auditoria da Responsividade Atual

Atualmente a responsividade do sistema está concentrada em [`lib/utils/responsive.dart`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/utils/responsive.dart):
* Breakpoint Mobile: `< 600 px`
* Breakpoint Tablet: `>= 600 px` e `< 1024 px`
* Breakpoint Desktop: `>= 1024 px`
* Breakpoint Especial Home Shortcuts: `< 768 px` (apenas para decidir tela inicial pós-login)
* `Responsive.getTableWidth(context)`: Retorna `1200 px` fixo no Desktop.

### 1.1 Diagnóstico de Problemas Identificados
1. **Quebra em Laptops Médios (1024px a 1280px)**: A fixação de `getTableWidth = 1200` faz com que telas de 1366x768 (muito comuns em ambientes corporativos e notebooks de campo) fiquem com barras de rolagem horizontal excessivas quando combinadas com a `Sidebar` expandida.
2. **Efeito "Desktop Espremido" no Mobile**: Diversas tabelas (como Notas SAP e Ordens) apenas aplicam `SingleChildScrollView(scrollDirection: Axis.horizontal)`, forçando o operador de smartphone a rolar horizontalmente por 15 colunas, em vez de exibir um formato adaptado em cards operacionais condensados.
3. **Falta de Breakpoint para Telas Ultrawide / Grandes Monitores**: Em monitores 1080p, 2K e 4K, formulários simples esticam excessivamente ou ficam com grandes vazios sem grid controlado.

---

## 2. Escala de Breakpoints Proposta (`TFBreakpoints`)

| Breakpoint | Faixa de Largura | Perfil de Dispositivo | Estratégia de Layout |
| :---: | :---: | :--- | :--- |
| **`xs`** | $< 480\text{ px}$ | Celulares compactos | Header compacto, menu inferior (BottomNav), listas em card único |
| **`sm`** | $480\text{ px}$ a $767\text{ px}$ | Celulares maiores | Filtros em BottomSheet, formulários em 1 coluna vertical |
| **`md`** | $768\text{ px}$ a $1023\text{ px}$ | Tablets em modo retrato | Sidebar recolhida (ícones), tabelas em densidade compacta |
| **`lg`** | $1024\text{ px}$ a $1365\text{ px}$ | Laptops padrão / Tablets modo paisagem | Layout dividido (Tabela + Gantt) com redimensionamento fluido |
| **`xl`** | $1366\text{ px}$ a $1919\text{ px}$ | Monitores Desktop padrão | Sidebar expandida, tabelas completas, painéis laterais fixos |
| **`xxl`** | $\ge 1920\text{ px}$ | Monitores Ultrawide / Centros de Controle | Layout multi-coluna, dashboards com 4 a 6 KPIs por linha |

---

## 3. Adaptação Comportamental por Plataforma

### 3.1 Tabelas de Dados
* **Desktop / Laptop (`lg`, `xl`, `xxl`)**: Renderizar `TFDataTable` com sticky headers, ordenação rápida e até 18 colunas.
* **Tablet (`md`)**: Manter `TFDataTable` com densidade `compact` ou `dense`, recolhendo colunas secundárias para um painel expansível de detalhes.
* **Mobile (`xs`, `sm`)**: Alternar automaticamente para visualização em lista de **Cards Operacionais** (`TFRecordCard`), destacando: Código da Atividade/Nota, Status em Badge, Data/Prazo e Responsável, com toque para abrir detalhes completos.

### 3.2 Barras de Filtros
* **Desktop**: Linha horizontal permanente com filtros rápidos mais usados (Status, Regional, Equipe, Período).
* **Mobile**: Botão compacto `[Filtros (N)]` que aciona um *Modal Bottom Sheet* com todos os critérios organizados verticalmente e botão inferior "Aplicar Filtros".
