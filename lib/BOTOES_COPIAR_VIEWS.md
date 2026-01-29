# Botões "Copiar" nas views – configuração

## Critério de “configurado corretamente”

O botão copiar está correto quando:

- Chama `await Clipboard.setData(ClipboardData(text: ...))` (operação assíncrona).
- Usa `try/catch` e trata erro (ex.: SnackBar de “Não foi possível copiar”).
- Dá feedback de sucesso (ex.: SnackBar “X copiado!”).
- Em widgets com estado, verifica `mounted` (ou `context.mounted`) antes de mostrar SnackBar após um `await`.

Sem `await`, a cópia pode falhar (principalmente na web) e o usuário ainda vê “copiado”; sem `try/catch`, falhas ficam silenciosas.

---

## Views com botão “Copiar” (para área de transferência)

### Configurados corretamente (async + await + try/catch + feedback)

| Arquivo | O que copia | Método / Observação |
|--------|-------------|----------------------|
| `ordem_view.dart` | Número da ordem | `_copiarOrdem()` – async, await, try/catch, SnackBar |
| `notas_sap_view.dart` | Número da nota | `_copiarNota()` – async, await, try/catch, SnackBar |
| `task_form_dialog.dart` | Ordem (no seletor de ordens) | `onPressed` async com await, try/catch, SnackBar |
| `ordem_calendar_view.dart` | Texto da ordem | `_copiar()` – async, await, try/catch (catch vazio; poderia mostrar erro) |

---

### Não configurados corretamente (sem await e/ou sem try/catch)

| Arquivo | O que copia | Problema |
|--------|-------------|----------|
| `fleet_schedule_view.dart` | Placa, Marca (dados da frota) | `_copyToClipboard()` é `void`, chama `Clipboard.setData` sem `await` e sem try/catch |
| `team_schedule_view.dart` | Nome, Função etc. (dados do executor) | Mesmo que acima |
| `maintenance_calendar_view.dart` | Nota, Ordem, AT, SI (4 botões) | `onPressed` síncrono, `Clipboard.setData` sem await e sem try/catch |
| `task_cards_view.dart` | “Copiar Link”, Nota, Ordem, AT, SI (5 usos) | Mesmo padrão |
| `task_table.dart` | Nota (2x), Ordem, AT, SI (5 botões) | Mesmo padrão |
| `task_view_dialog.dart` | Nota, Ordem, AT, SI (4 botões) | Mesmo padrão |
| `telegram_config_dialog.dart` | Link (Copiar Link) | `Clipboard.setData` sem await e sem try/catch |
| `ordem_selection_dialog.dart` | Ordem (2 botões) | Mesmo padrão |
| `si_view.dart` | SI (3 botões) | Mesmo padrão |
| `si_selection_dialog.dart` | SI (2 botões) | Mesmo padrão |
| `at_view.dart` | AT (3 botões) | Mesmo padrão |
| `at_selection_dialog.dart` | AT (2 botões) | Mesmo padrão |
| `nota_sap_selection_dialog.dart` | Nota (2 botões) | Mesmo padrão |

---

## Observação: ícone “copy” usado para “Duplicar”

Estas views usam o ícone de copiar (Icons.copy) para **duplicar** registro (não para copiar texto para a área de transferência). Não entram na lista de “copiar para área de transferência”:

- `status_album_list_view.dart` – Duplicar status de álbum  
- `regional_list_view.dart` – Duplicar regional  
- `divisao_list_view.dart` – Duplicar divisão  
- `segmento_list_view.dart` – Duplicar segmento  
- `gantt_chart.dart` – Duplicar período  
- `fleet_schedule_view.dart` – item de menu “Duplicar” (tarefa)  
- `team_schedule_view.dart` – item de menu “Duplicar” (tarefa)  
- `maintenance_calendar_view.dart` – item “Duplicar”  
- `task_cards_view.dart` – item “Duplicar”  
- `task_table.dart` – item “Duplicar”  

Esses estão coerentes com a ação “duplicar”; apenas os botões que copiam **texto para a área de transferência** foram checados acima.
