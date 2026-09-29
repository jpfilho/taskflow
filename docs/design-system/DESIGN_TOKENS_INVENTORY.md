# TaskFlow Design System — Design Tokens Inventory

> **Status:** Mapeamento Concluído  
> **Data:** Setembro de 2026

---

## 1. Mapeamento de Cores (Atual $\rightarrow$ Tokenizado)

| Valor Atual no Código | Ocorrências | Token TFDS | Valor Light | Valor Dark |
| :--- | :---: | :--- | :--- | :--- |
| `Color(0xFF0F172A)` | 55 | `tokens.colors.backgroundDark` / `surfaceDeep` | `#F8FAFC` | `#0F172A` |
| `Color(0xFF1E293B)` | 178 | `tokens.colors.surfaceContainer` / `textPrimary` | `#0F172A` (Texto) | `#1E293B` (Superfície) |
| `Color(0xFF334155)` | 88 | `tokens.colors.borderStrong` | `#CBD5E1` | `#334155` |
| `Color(0xFF475569)` | 101 | `tokens.colors.textSecondary` | `#475569` | `#94A3B8` |
| `Color(0xFF94A3B8)` | 76 | `tokens.colors.textMuted` / `borderSubtle` | `#64748B` | `#94A3B8` |
| `Color(0xFFCBD5E1)` | 78 | `tokens.colors.borderDefault` | `#CBD5E1` | `#334155` |
| `Color(0xFFE2E8F0)` | 83 | `tokens.colors.borderSubtle` | `#E2E8F0` | `#1E293B` |
| `Color(0xFFF1F5F9)` | 71 | `tokens.colors.surfaceSubtle` / `zebraRow` | `#F1F5F9` | `#162032` |
| `Color(0xFFF8FAFC)` | 49 | `tokens.colors.background` | `#F8FAFC` | `#0B0F17` |
| `Color(0xFF1E3A5F)` | 79 | `tokens.colors.brandNavy` | `#1E3A5F` | `#0D1B2A` |
| `Color(0xFF3B82F6)` / `Colors.blue` | 402 | `tokens.colors.primary` | `#2563EB` | `#3B82F6` |
| `Colors.white` | 991 | `tokens.colors.surface` | `#FFFFFF` | `#131B2E` |
| `Colors.green` / `green[700]` | 265 | `tokens.colors.success` | `#16A34A` | `#22C55E` |
| `Colors.orange` / `amber` | 238 | `tokens.colors.warning` | `#D97706` | `#F59E0B` |
| `Colors.red` / `red[700]` | 533 | `tokens.colors.danger` | `#DC2626` | `#EF4444` |

---

## 2. Mapeamento de Tipografia (Atual $\rightarrow$ Tokenizado)

| `fontSize` Atual | Peso Atual | Token TFDS | Tamanho Padronizado | Peso Padronizado |
| :---: | :---: | :--- | :---: | :--- |
| `24px` | Bold / w600 | `tokens.typography.titlePage` | **22 px** | SemiBold (`w600`) |
| `20px` | Bold | `tokens.typography.titleSection` | **18 px** | SemiBold (`w600`) |
| `16px` | Bold / Medium | `tokens.typography.titleSection` | **16 px** | SemiBold (`w600`) |
| `14px` | Regular / Bold | `tokens.typography.bodyLarge` | **14 px** | Regular / Medium |
| `13px` | Regular | `tokens.typography.bodyMedium` | **13 px** | Regular (`w400`) |
| `12px` | Regular / Bold | `tokens.typography.bodySmall` | **12 px** | Regular / Medium |
| `11px` | Regular / Bold | `tokens.typography.caption` | **11 px** | Regular / SemiBold |
| `10px` | Bold | `tokens.typography.micro` | **10 px** | Bold (`w700`) |
| `9px` | Regular | `tokens.typography.micro` | **10 px** (ajustado p/ legibilidade) | Bold (`w700`) |

---

## 3. Mapeamento de Espaçamento e Raios (Atual $\rightarrow$ Tokenizado)

| Valor Numérico Atual | Tipo de Uso | Token TFDS | Valor em Pixels |
| :---: | :--- | :--- | :---: |
| `2px` | SizedBox / padding mínimo | `tokens.space.xxs` | **2 px** |
| `4px` | SizedBox / padding badge | `tokens.space.xs` | **4 px** |
| `8px` | Padding interno de célula / gap | `tokens.space.sm` | **8 px** |
| `12px` | Padding botão compacto / input | `tokens.space.md` | **12 px** |
| `16px` | Padding padrão de página / card | `tokens.space.lg` | **16 px** |
| `20px` | Margem de seção | `tokens.space.xl` | **20 px** |
| `24px` | Gaps de grids em desktop | `tokens.space.xxl` | **24 px** |
| `32px` | Padding modal amplo | `tokens.space.xxxl` | **32 px** |
| `4px` | Raio de borda | `tokens.radius.xs` | **4 px** |
| `8px` | Raio de borda padrão | `tokens.radius.sm` | **8 px** |
| `12px` | Raio de cards | `tokens.radius.md` | **12 px** |
| `16px` | Raio de modais | `tokens.radius.lg` | **16 px** |
| `20px` / `999px` | Raio de pílulas e badges | `tokens.radius.full` | **999 px** |
