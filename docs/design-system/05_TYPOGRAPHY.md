# TaskFlow Design System — Tipografia

> **Status:** Concluído  
> **Data:** Setembro de 2026

---

## 1. Auditoria de Tipografia Atual

O scan estático identificou **2.134 declarações manuais de `TextStyle(...)`** no código, dispersas em 22 tamanhos diferentes de fonte (`fontSize`):

| `fontSize` | Ocorrências | Contextos Predominantes de Uso |
| :---: | :---: | :--- |
| **12px** | **386** | Células de tabela, badges, chips de status, legendas de gráficos |
| **14px** | **266** | Textos de corpo, inputs de texto, botões de ação padrão |
| **11px** | **156** | Textos secundários em tabelas densas, badges de prazo SAP |
| **16px** | **122** | Títulos de seções, cabeçalhos de cards |
| **10px** | **102** | Dias restantes em badges, micro-rótulos no Gantt |
| **13px** | **75** | Textos intermediários em menus e listas |
| **18px** | **55** | Títulos de diálogos e telas secundárias |
| **20px** | **40** | Títulos de páginas e números de KPI cards |
| **9px** | **38** | Micro-rótulos em escalas do Gantt e horários |
| **24px** | **25** | Títulos principais de páginas e modais modernos |
| **Outros (8, 15, 17, 22, 28, 32, 36)** | **34** | Casos isolados de tamanhos arbitrários |

### 1.1 Pesos de Fonte (`FontWeight`)

* `FontWeight.bold` / `w700`: 732 ocorrências
* `FontWeight.w500` / `w600` (Medium/SemiBold): 485 ocorrências
* `FontWeight.normal` / `w400`: 210 ocorrências

---

## 2. Escala Tipográfica Proposta (`TFTypography`)

Para atender à necessidade de densidade sem perder a hierarquia, a escala oficial do TaskFlow é:

| Token | Tamanho (`fontSize`) | Peso (`fontWeight`) | Altura (`lineHeight`) | Aplicação |
| :--- | :---: | :---: | :---: | :--- |
| **`display`** | 28 px | Bold (`700`) | 1.2 | Grandes números de KPIs em Dashboards |
| **`titlePage`** | 22 px | SemiBold (`600`) | 1.25 | Título de página no Page Header |
| **`titleSection`** | 16 px | SemiBold (`600`) | 1.3 | Cabeçalho de seções, títulos de modais e cards |
| **`bodyLarge`** | 14 px | Regular (`400`) / Medium (`500`) | 1.4 | Inputs, botões de ação primária |
| **`bodyMedium`** | 13 px | Regular (`400`) / Medium (`500`) | 1.35 | Textos padrão de interface e listas |
| **`bodySmall`** | 12 px | Regular (`400`) / Medium (`500`) | 1.3 | Células de tabelas de dados, formulários compactos |
| **`caption`** | 11 px | Regular (`400`) / Medium (`500`) | 1.25 | Textos auxiliares, timestamps de chat, metadados |
| **`micro`** | 10 px | Bold (`700`) | 1.2 | Badges de status, pílulas de prazo, escalas do Gantt |

---

## 3. Diretrizes de Legibilidade em Dados Densos

* **Tabelas Operacionais**: Proibir o uso de `fontSize > 13px` em tabelas de alta densidade (como `NotaSAPView` e `TaskTable`). O padrão obrigatório é `bodySmall` (12px) com peso `500` para chaves/códigos e `400` para descrições.
* **Badges e Pílulas**: Utilizar sempre `micro` (10px) ou `caption` (11px) com peso `Bold` (`w700`) para manter a nitidez em fundos coloridos.
* **Números e Valores**: Aplicar fonte mono-espaçada ou com alinhamento tabular (`fontFeatures: [FontFeature.tabularFigures()]`) em colunas numéricas de horas, custos e datas.
