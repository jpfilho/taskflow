# TaskFlow Design System — Espaçamento, Radius e Elevação

> **Status:** Concluído  
> **Data:** Setembro de 2026

---

## 1. Auditoria de Espaçamentos Existentes

O scan no código Flutter mapeou as seguintes ocorrências de espaçamentos uniformes (`EdgeInsets.all`):
* `16px`: 232 ocorrências (+ 54 com `16.0`) $\rightarrow$ **286 totais** (padrão predominante em telas)
* `8px`: 138 ocorrências (+ 9 com `8.0`) $\rightarrow$ **147 totais** (padrão de componentes)
* `12px`: 69 ocorrências (+ 11 com `12.0`) $\rightarrow$ **80 totais**
* `20px`: 48 ocorrências
* `4px`: 45 ocorrências
* `24px`: 22 ocorrências
* `32px`: 13 ocorrências
* Valores fracionados ou arbitrários (ex.: 2, 6, 10, 14, 15, 18): 37 ocorrências

---

## 2. Escala Oficial de Espaçamento Base 4px (`TFSpacing`)

| Token | Valor em Pixels | Aplicação Recomendada |
| :--- | :---: | :--- |
| **`spaceXxs`** | **2 px** | Gaps mínimos entre ícone e badge, divisores finos |
| **`spaceXs`** | **4 px** | Padding interno de micro-badges, espaçamento entre itens compactos |
| **`spaceSm`** | **8 px** | Padding padrão interno de células de tabela, gaps em toolbars |
| **`spaceMd`** | **12 px** | Padding de botões compactos, inputs compactos, cards densos |
| **`spaceLg`** | **16 px** | Padding padrão de containers, modais, cabeçalhos e páginas |
| **`spaceXl`** | **20 px** | Margens entre seções de dashboard |
| **`space2Xl`**| **24 px** | Gaps de grids em desktop |
| **`space3Xl`**| **32 px** | Margens externas em telas ultra-wide / diálogos largos |
| **`space4Xl`**| **48 px** | Espaçamento de grandes seções vazias |

---

## 3. Auditoria de Raios de Borda (`BorderRadius.circular`)

Foram encontrados 19 valores diferentes de raios no código:

| Raio | Ocorrências | Onde é Mais Utilizado | Decisão no Design System |
| :---: | :---: | :--- | :--- |
| **8 px** | **390** | Inputs, botões, cards, containers de diálogos | **`radiusSm` (Padrão corporativo)** |
| **12 px** | **256** | Badges de prazo, pílulas, cards destacados | **`radiusMd` (Pílulas & Cards)** |
| **4 px** | **165** | Checkboxes, tags, pequenos botões em tabelas | **`radiusXs` (Micro-elementos)** |
| **16 px** | **67** | Diálogos modernos (`ModernFormDialog`) | **`radiusLg` (Modais)** |
| **6 px** | **50** | Variação intermediária | **Descontinuar $\rightarrow$ Unificar em 8px** |
| **10 px** | **44** | Variação intermediária | **Descontinuar $\rightarrow$ Unificar em 8px ou 12px** |
| **20 px** | **39** | Badges circulares e `SyncStatusWidget` | **Unificar em `radiusFull` (999px)** |
| **999 px** | **15** | Pílulas e avatares redondos | **`radiusFull`** |

### Tokens Oficiais de Raio (`TFRadius`)
* **`none`**: `0 px` (Tabelas com bordas retas, dividers)
* **`xs`**: `4 px` (Tags técnicas, tooltips)
* **`sm`**: `8 px` (Botões, inputs, cards — **padrão do sistema**)
* **`md`**: `12 px` (Cards principais, drawers)
* **`lg`**: `16 px` (Diálogos de formulário, modais)
* **`full`**: `999 px` (Pills de status, chips, avatares)

---

## 4. Auditoria de Elevação e Sombras

Em sistemas corporativos densos, sombras excessivas criam poluição visual e cansaço ao operador. Identificamos 31 declarações manuais de `BoxShadow` com opacidades e raios de blur divergentes.

### Sistema Oficial de Elevação (`TFElevation`)
* **`flat`**: Sem sombra, apenas borda sutil (`borderSubtle`) — **padrão para 90% das tabelas e containers**.
* **`raised` (Nível 1)**: `BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))` (Cards de resumo, dropdown menus).
* **`overlay` (Nível 2)**: `BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4))` (Modais, Side Sheets e tooltips flutuantes).
