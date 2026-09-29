# TaskFlow Design System — Cores e Paleta Semântica

> **Status:** Concluído  
> **Data:** Setembro de 2026

---

## 1. Auditoria de Cores Existentes

O scan estático completo no código-fonte revelou:
* **116 cores hexadecimais distintas** declaradas como `Color(0x...)` em 1.187 ocorrências.
* **127 cores Material distintas** declaradas como `Colors.*` em 5.405 ocorrências.

### 1.1 Cores Hexadecimais Mais Frequentes

| HEX | Valor RGB | Ocorrências | Arquivos | Contexto Atual de Uso | Papel no Design System |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `#1E293B` | `rgb(30, 41, 59)` | **178** | 29 | Fundo escuro em diálogos e texto em light mode | `slate.800` (Texto Dark / Superfície Escura) |
| `#475569` | `rgb(71, 85, 105)` | **101** | 21 | Bordas e textos secundários | `slate.600` (Bordas fortes / Texto Muted) |
| `#334155` | `rgb(51, 65, 85)` | **88** | 27 | Bordas em dark mode | `slate.700` (Bordas em tema escuro) |
| `#E2E8F0` | `rgb(226, 232, 240)` | **83** | 27 | Linhas divisórias e bordas de cards | `slate.200` (Border Subtle Light) |
| `#1E3A5F` | `rgb(30, 58, 95)` | **79** | 24 | Azul-marinho do HeaderBar / Sidebar legado | `brand.primaryNavy` (Identidade corporativa) |
| `#CBD5E1` | `rgb(203, 213, 225)` | **78** | 16 | Bordas de inputs e caixas de diálogo | `slate.300` (Bordas de input) |
| `#94A3B8` | `rgb(148, 163, 184)` | **76** | 18 | Ícones inativos e placeholders | `slate.400` (Placeholders / Icons Muted) |
| `#F1F5F9` | `rgb(241, 245, 249)` | **71** | 21 | Fundo de tabelas e containers | `slate.100` (Fundo de tabelas e zebra rows) |
| `#3B82F6` | `rgb(59, 130, 246)` | **68** | 17 | Azul primário de botões em dialogs modernos | `primary.default` (Ação primária moderna) |
| `#0F172A` | `rgb(15, 23, 42)` | **55** | 26 | Fundo profundo de telas escuras | `slate.900` (Background Dark Profundo) |
| `#F8FAFC` | `rgb(248, 250, 252)` | **49** | 25 | Fundo geral da aplicação e cards | `slate.50` (Background App Light) |

### 1.2 Dispersão de Cores Material

O uso de `Colors.*` ocorre em 5.405 locais sem tokens:
* `Colors.white`: 991 vezes.
* `Colors.red`: 533 vezes (usado indiscriminadamente para erros, exclusão, prazos críticos, notas urgentes e avisos).
* `Colors.grey`: 358 vezes + variantes (`grey[600]` 294 vezes, `grey[300]` 230 vezes, `grey[700]` 177 vezes, `grey[400]` 139 vezes, `grey[200]` 130 vezes, `grey[500]` 96 vezes).
* `Colors.blue`: 334 vezes + `blue[700]` 86 vezes.
* `Colors.green`: 265 vezes.
* `Colors.orange`: 238 vezes.

---

## 2. Paleta Semântica Proposta (`TFColors`)

A paleta recomendada consolida a tendência técnica já iniciada em `form_dialog_helpers.dart` e nas novas features (baseada na escala corporativa Slate + Brand Navy) com tokens semânticos completos:

```text
TFColors
│
├── Brand
│   ├── navyDeep: #0F172A (Azul corporativo profundo)
│   ├── navyDefault: #1E3A5F (Azul do Header e Sidebar)
│   └── primaryBlue: #2563EB (Azul de ação primária WCAG AAA)
│
├── Superfícies (Light Mode / Dark Mode)
│   ├── background: #F8FAFC / #0B0F17
│   ├── surface: #FFFFFF / #131B2E
│   ├── surfaceContainer: #F1F5F9 / #1E293B
│   └── surfaceElevated: #FFFFFF / #26334D
│
├── Bordas & Divisores
│   ├── borderSubtle: #E2E8F0 / #1E293B
│   ├── borderDefault: #CBD5E1 / #334155
│   ├── borderStrong: #94A3B8 / #475569
│   └── borderFocus: #3B82F6 / #60A5FA
│
├── Tipografia
│   ├── textPrimary: #0F172A / #F8FAFC
│   ├── textSecondary: #475569 / #CBD5E1
│   ├── textMuted: #64748B / #94A3B8
│   └── textOnPrimary: #FFFFFF / #FFFFFF
│
├── Feedback Operacional
│   ├── success: #16A34A (Verde operacional)
│   ├── successSubtle: #DCFCE7
│   ├── warning: #D97706 (Âmbar/Laranja de alerta)
│   ├── warningSubtle: #FEF3C7
│   ├── danger: #DC2626 (Vermelho de erro/crítico)
│   ├── dangerSubtle: #FEE2E2
│   ├── info: #2563EB (Azul informativo)
│   └── infoSubtle: #DBEAFE
│
└── Status de Sincronização & Conexão
    ├── online: #16A34A
    ├── offline: #EA580C
    ├── syncing: #2563EB
    └── syncConflict: #DC2626
```
