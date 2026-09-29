# TaskFlow Design System — Relatório Detalhado de Dívida Visual

> **Status:** Concluído  
> **Data:** Setembro de 2026

---

## 1. Dívida em Cores (Colors Debt)

### Evidência 1: 14 Tonalidades Utilizadas como "Azul Primário"
No código-fonte foram encontradas 14 declarações distintas para representar ações primárias e links:
1. `Color(0xFF3B82F6)` — em `features/ai_assistants/presentation/screens/ai_assistants_list_screen.dart:258`
2. `Color(0xFF2563EB)` — em `features/media_albums/presentation/pages/upload_page.dart:530`
3. `Color(0xFF1E40AF)` — em `features/media_albums/presentation/pages/gallery_page.dart:197`
4. `Color(0xFF1E3A5F)` — em `services/theme_service.dart:272`
5. `Color(0xFF0000FF)` — em `services/theme_service.dart:31` (`axiaBlue`)
6. `Color(0xFF2196F3)` — em `models/status.dart:17`
7. `Colors.blue` — em `widgets/main.dart:247`
8. `Colors.blue[700]` — em `widgets/si_selection_dialog.dart:298`
9. `Colors.blue[800]` — em `widgets/sync_status_widget.dart:219`
10. `Colors.blueAccent` — em `services/theme_service.dart:180`
11. `Colors.blue[600]` — em `widgets/task_table.dart:2104`
12. `Colors.blue[200]` — em `widgets/notas_sap_view.dart:2151`
13. `Color(0xFF60A5FA)` — em `features/ai_assistants/presentation/widgets/ai_assistant_card.dart:94`
14. `Color(0xFF1D4ED8)` — em `features/documents/presentation/widgets/document_card.dart:82`

**Impacto:** O usuário percebe diferentes tons de azul dependendo da tela onde está navegando, quebrando a sensação de produto coeso.

---

## 2. Dívida em Status Operacionais (Status Badges Debt)

### Evidência 2: 7 Implementações Diferentes de Status Badge para Cancelamento/Bloqueio
1. `widgets/notas_sap_view.dart:2141` $\rightarrow$ `if (status.contains('CANC')) return Colors.black;` (Fundo preto com texto branco)
2. `widgets/ordem_view.dart:2598` $\rightarrow$ `if (status.contains('CANC')) return Colors.grey[700];` (Fundo cinza escuro)
3. `widgets/advanced_list_view.dart:318` $\rightarrow$ `default: return Colors.grey;` (Fundo cinza neutro)
4. `widgets/task_table.dart:1840` $\rightarrow$ `status.cor` (Lido diretamente do banco de dados sem contraste garantido)
5. `features/demandas/presentation/screens/demandas_screen.dart:420` $\rightarrow$ `Chip(backgroundColor: Colors.red.withOpacity(0.2))`
6. `modules/melhorias_bugs/presentation/widgets/bug_card.dart:115` $\rightarrow$ `Container(color: Colors.red[100], child: Text('Cancelado', style: TextStyle(color: Colors.red[800])))`
7. `features/media_albums/presentation/pages/status_album_list_view.dart:310` $\rightarrow$ `Badge(backgroundColor: Color(0xFFDC2626))`

**Impacto:** Um item "Cancelado" aparece preto em Notas SAP, cinza em Ordens, vermelho claro em Demandas e vermelho sólido em Álbuns.

---

## 3. Dívida em Botões (Buttons Debt)

### Evidência 3: 5 Formas Diferentes de Criar o Botão "Salvar / Confirmar"
1. `ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))` — em `widgets/form_dialog_helpers.dart:460`
2. `ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue))` — em `widgets/task_form_dialog.dart:1412`
3. `FilledButton(onPressed: ..., child: Text('Salvar'))` — em `features/ai_assistants/presentation/screens/ai_assistant_editor_screen.dart:320`
4. `InkWell(onTap: ..., child: Container(decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)), child: Text('Confirmar')))` — em `widgets/sync_status_widget.dart:233`
5. `TextButton.icon(onPressed: ..., icon: Icon(Icons.check), label: Text('Salvar'))` — em `features/documents/presentation/pages/document_upload_page.dart:210`

---

## 4. Dívida em Espaçamento e Modais (Layout Debt)

* **Largura de Modais:**
  * `ModernFormDialog` (`form_dialog_helpers.dart`): `maxWidth: 512px`
  * `TaskFormDialog`: `maxWidth: 900px`
  * `OrdemSelectionDialog`: `maxWidth: 1100px`
  * `ColorPickerDialog`: `maxWidth: 400px`
* **Margens Internas de Diálogos:** Variam entre `padding: EdgeInsets.all(16)` e `padding: EdgeInsets.all(32)` em arquivos vizinhos.
