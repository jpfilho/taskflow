import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/rules/task_apoio_state_machine.dart';
import '../task_apoio_ui_controller.dart';

/// Helper compartilhado para execução de ações da máquina de estados
/// (justificativas, contrapropostas, proteção contra clique duplo e tratamento de erros).
class TaskApoioNegociacaoHelper {
  static final _fmt = DateFormat('dd/MM HH:mm');

  static Future<bool> executarAcao({
    required BuildContext context,
    required TaskApoioUiController controller,
    required TaskApoioSolicitacao solicitacao,
    required TaskApoioAcao acao,
    required String usuarioAtualId,
    String? usuarioAtualNome,
  }) async {
    String? justificativa;
    DateTime? contraIni;
    DateTime? contraFim;

    if (acao == TaskApoioAcao.enviarContraproposta) {
      final res = await _pedirContraproposta(context, solicitacao);
      if (res == null) return false;
      contraIni = res.$1;
      contraFim = res.$2;
      justificativa = res.$3;
    } else if (acao.exigeJustificativa) {
      justificativa = await _pedirJustificativa(context, acao.label);
      if (justificativa == null || justificativa.trim().isEmpty) return false;
    }

    try {
      await controller.executarAcaoProtegida(() async {
        final svc = controller.service;
        switch (acao) {
          case TaskApoioAcao.encaminharAnalise:
            await svc.encaminharParaAnalise(
              solicitacaoId: solicitacao.id,
              versaoEsperada: solicitacao.versao,
              responsavelId: usuarioAtualId,
              responsavelNome: usuarioAtualNome,
            );
          case TaskApoioAcao.aceitar:
            await svc.aceitar(
              solicitacaoId: solicitacao.id,
              versaoEsperada: solicitacao.versao,
              atorUsuarioId: usuarioAtualId,
              atorNome: usuarioAtualNome,
            );
          case TaskApoioAcao.recusar:
            await svc.recusar(
              solicitacaoId: solicitacao.id,
              versaoEsperada: solicitacao.versao,
              atorUsuarioId: usuarioAtualId,
              atorNome: usuarioAtualNome,
              justificativa: justificativa!,
            );
          case TaskApoioAcao.enviarContraproposta:
            await svc.apresentarContraproposta(
              solicitacaoId: solicitacao.id,
              versaoEsperada: solicitacao.versao,
              atorUsuarioId: usuarioAtualId,
              atorNome: usuarioAtualNome,
              inicioProposto: contraIni!,
              fimProposto: contraFim!,
              justificativa: justificativa!,
            );
          case TaskApoioAcao.aceitarContraproposta:
            await svc.aceitarContraproposta(
              solicitacaoId: solicitacao.id,
              versaoEsperada: solicitacao.versao,
              atorUsuarioId: usuarioAtualId,
              atorNome: usuarioAtualNome,
            );
          case TaskApoioAcao.recusarContraproposta:
            await svc.recusarContraproposta(
              solicitacaoId: solicitacao.id,
              versaoEsperada: solicitacao.versao,
              atorUsuarioId: usuarioAtualId,
              atorNome: usuarioAtualNome,
              justificativa: justificativa!,
            );
          case TaskApoioAcao.cancelar:
            await svc.cancelar(
              solicitacaoId: solicitacao.id,
              versaoEsperada: solicitacao.versao,
              atorUsuarioId: usuarioAtualId,
              atorNome: usuarioAtualNome,
              motivo: justificativa!,
            );
          case TaskApoioAcao.solicitarReconfirmacao:
            await svc.solicitarReconfirmacao(
              solicitacaoId: solicitacao.id,
              versaoEsperada: solicitacao.versao,
              atorUsuarioId: usuarioAtualId,
              atorNome: usuarioAtualNome,
              motivo: justificativa!,
            );
        }
      });

      if (solicitacao.taskSolicitanteId != null) {
        controller.invalidarCacheTask(solicitacao.taskSolicitanteId!);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir a ação: $e')),
        );
      }
      return false;
    }
  }

  static Future<String?> _pedirJustificativa(
    BuildContext context,
    String tituloAcao,
  ) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tituloAcao),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Justificativa obrigatória *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TFButton(
            label: 'Voltar',
            variant: TFButtonVariant.tertiary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TFButton(
            label: 'Confirmar',
            variant: TFButtonVariant.primary,
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(ctrl.text.trim());
            },
          ),
        ],
      ),
    );
  }

  static Future<(DateTime, DateTime, String)?> _pedirContraproposta(
    BuildContext context,
    TaskApoioSolicitacao sol,
  ) async {
    final ctrl = TextEditingController();
    var ini = sol.dataInicioSolicitada;
    var fim = sol.dataFimSolicitada;
    return showDialog<(DateTime, DateTime, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Apresentar Contraproposta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Período proposto: ${_fmt.format(ini.toLocal())} a ${_fmt.format(fim.toLocal())}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: ini,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2032),
                      );
                      if (d != null) {
                        setDlg(
                          () => ini = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            ini.hour,
                            ini.minute,
                          ),
                        );
                      }
                    },
                    child: const Text('Alterar início'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: fim,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2032),
                      );
                      if (d != null) {
                        setDlg(
                          () => fim = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            fim.hour,
                            fim.minute,
                          ),
                        );
                      }
                    },
                    child: const Text('Alterar fim'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Justificativa da contraproposta *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TFButton(
              label: 'Cancelar',
              variant: TFButtonVariant.tertiary,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TFButton(
              label: 'Enviar contraproposta',
              variant: TFButtonVariant.primary,
              onPressed: () {
                if (ctrl.text.trim().isEmpty || fim.isBefore(ini)) return;
                Navigator.of(ctx).pop((ini, fim, ctrl.text.trim()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

