import 'package:flutter/material.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../domain/models/notificacao_interna.dart';
import '../notificacoes_controller.dart';

class NotificacoesPreferenciasDialog extends StatefulWidget {
  final NotificacoesController controller;

  const NotificacoesPreferenciasDialog({
    super.key,
    required this.controller,
  });

  @override
  State<NotificacoesPreferenciasDialog> createState() =>
      _NotificacoesPreferenciasDialogState();
}

class _NotificacoesPreferenciasDialogState
    extends State<NotificacoesPreferenciasDialog> {
  late bool _receberInterna;
  late bool _receberTelegram;
  late Set<int> _antecedencias;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.controller.preferencias;
    _receberInterna = p.receberInterna;
    _receberTelegram = p.receberTelegram;
    _antecedencias = p.antecedenciasDias.toSet();
    widget.controller.carregarPreferencias().then((_) {
      if (!mounted) return;
      final atual = widget.controller.preferencias;
      setState(() {
        _receberInterna = atual.receberInterna;
        _receberTelegram = atual.receberTelegram;
        _antecedencias = atual.antecedenciasDias.toSet();
      });
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final list = _antecedencias.toList()..sort((a, b) => b.compareTo(a));
      await widget.controller.salvarPreferencias(
        NotificacaoPreferencia(
          receberInterna: _receberInterna,
          receberTelegram: _receberTelegram,
          antecedenciasDias: list,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar preferências: $e')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    return AlertDialog(
      title: const Text('Preferências de Notificações'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notificações internas no TaskFlow'),
                subtitle: const Text(
                  'Alertas críticos de compatibilidade permanecem visíveis na Central.',
                ),
                value: _receberInterna,
                onChanged: (v) => setState(() => _receberInterna = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Receber avisos via Telegram'),
                subtitle: const Text(
                  'Respeita a habilitação configurada pela sua unidade organizacional.',
                ),
                value: _receberTelegram,
                onChanged: (v) => setState(() => _receberTelegram = v),
              ),
              const SizedBox(height: 12),
              Text(
                'Antecedência dos lembretes automáticos',
                style: typo.labelMedium.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [7, 3, 1, 0].map((dias) {
                  final sel = _antecedencias.contains(dias);
                  final label = dias == 0 ? 'No dia' : '$dias dia(s) antes';
                  return FilterChip(
                    label: Text(label),
                    selected: sel,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _antecedencias.add(dias);
                        } else {
                          _antecedencias.remove(dias);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
