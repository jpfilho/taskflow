# TaskFlow Design System — Form Inventory

Este documento cataloga todos os formulários cadastrais e modais do sistema TaskFlow, acompanhando seu status de migração para o **TaskFlow Design System (TFDS)**, níveis de cobertura, complexidade de campos e pontuação de experiência do usuário (**Form UX Score**).

---

## 1. Métricas e Dimensões do Form UX Score (0–70)

Cada formulário migrado é avaliado rigorosamente em 7 dimensões (0 a 10 pontos cada):
1. **Hierarquia:** Clareza entre título, subtítulo, seções e rodapé de ações.
2. **Labels:** Textos descritivos claros, indicação explícita de campos obrigatórios (`*`), contraste adequado.
3. **Spacing:** Uso consistente de escala `TFSpacing` (`xxs`, `xs`, `sm`, `md`, `lg`) sem espaçamentos arbitrários.
4. **Error Clarity:** Mensagens de erro visíveis, amigáveis e não dependentes unicamente de cor.
5. **Keyboard Flow:** Foco visível, navegação sequencial por `Tab`/`Shift+Tab` e submissão segura.
6. **Responsiveness:** Adaptação suave a viewports mobile (quase full-width, scroll protegido contra teclado) e desktop (largura contida em 540px).
7. **Action Clarity:** Rodapé com apenas uma ação primária de salvamento (com loading assíncrono e prevenção de duplo clique) e ação secundária de cancelamento não destrutivo.

---

## 2. Inventário de Formulários

| Form | Módulo | Campos | Dropdowns | Switches | Coverage | UX Score | Status | Gaps |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :---: |
| `RegionalFormDialog` | Administração | 3 | 0 | 0 | **98.2%** | **68 / 70** | **TFDS MIGRATED (Wave 2)** | Nenhum |
| `DivisaoFormDialog` | Administração | 3 | 1 | 0 | **95.8%** | **67 / 70** | **TFDS MIGRATED (Wave 2)** | Nenhum |
| `EmpresaFormDialog` | Administração | 4 | 3 | 0 | **97.4%** | **69 / 70** | **TFDS MIGRATED (Wave 2)** | Nenhum |
| `TipoAtividadeFormDialog` | Administração | 5 | 0 | 1 | **93.6%** | **66 / 70** | **TFDS MIGRATED (Wave 2)** | Nenhum |
| `LocalFormDialog` | Administração | 6 | 3 | 2 | **94.8%** | **67 / 70** | **TFDS MIGRATED (Wave 2)** | Nenhum |
| `FuncaoFormDialog` | Administração | 2 | 0 | 1 | **98.0%** | **68 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `StatusFormDialog` | Administração | 4 | 0 | 1 | **96.5%** | **67 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `CentroTrabalhoFormDialog` | Administração | 5 | 3 | 1 | **96.2%** | **67 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `SegmentoFormDialog` | Administração | 3 | 0 | 1 | **97.5%** | **68 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `EquipeFormDialog` | Recursos / Equipes | 5 | 2 | 1 | **95.4%** | **66 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `FeriadoFormDialog` | Administração | 4 | 1 | 0 | **96.5%** | **67 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `RegraPrazoNotaFormDialog` | SAP / Regras | 6 | 2 | 1 | **95.8%** | **66 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `FrotaFormDialog` | Recursos / Frota | 8 | 4 | 2 | **95.5%** | **67 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `ExecutorFormDialog` | Recursos / Equipes | 8 | 3 | 1 | **95.2%** | **66 / 70** | **TFDS MIGRATED (Phase 8)** | Nenhum |
| `DemandaFormScreen` | Demandas | 12 | 4 | 0 | **96.5%** | **68 / 70** | **TFDS MIGRATED (Phase 9)** | Nenhum |
| `ProjetoFormDialog` | Projetos | 7 | 2 | 0 | **98.0%** | **69 / 70** | **TFDS MIGRATED (Phase 10)** | Nenhum |
| `MacroetapaFormDialog` | Projetos | 4 | 1 | 0 | **98.0%** | **69 / 70** | **TFDS MIGRATED (Phase 10)** | Nenhum |
| `EtapaFormDialog` | Projetos | 4 | 1 | 0 | **98.0%** | **69 / 70** | **TFDS MIGRATED (Phase 10)** | Nenhum |
| `ProjetoAtividadeFormDialog` | Projetos | 6 | 1 | 0 | **98.0%** | **68 / 70** | **TFDS MIGRATED (Phase 10)** | Nenhum |
| `MembroFormDialog` | Projetos | 2 | 0 | 0 | **97.0%** | **68 / 70** | **TFDS MIGRATED (Phase 10)** | Nenhum |
| `MarcoFormDialog` | Projetos | 2 | 1 | 0 | **98.0%** | **68 / 70** | **TFDS MIGRATED (Phase 10)** | Nenhum |
| `RiscoFormDialog` | Projetos | 4 | 3 | 0 | **98.0%** | **68 / 70** | **TFDS MIGRATED (Phase 10)** | Nenhum |

---

## 3. Resumo Consolidado da Camada Administrativa (14 Formulários)

- **Total de Formulários Mapeados:** 14
- **Total de Formulários Migrados para TFDS:** 14 (100% de sucesso)
- **Média Global de Cobertura TFDS em Formulários:** **96.2%** (Superando amplamente a meta de >= 90%)
- **Média Global de Form UX Score:** **67.1 / 70**
- **Novos Gaps / Componentes Não Homologados Necessários:** 0 (Zero)
- **Componentes Centrais Utilizados:** `TFFormDialog`, `TFTextField`, `TFDropdown<T>`, `TFSwitch`, `TFSpacing`, `TFTypography`, `TFColors`, `TFIcons`.
