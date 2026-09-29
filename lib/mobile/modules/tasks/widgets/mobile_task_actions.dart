import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/widgets/tf_mobile_buttons.dart';
import '../models/mobile_task_available_actions.dart';

/// Barra de ações operacionais fixada na base do detalhe da atividade.
/// Posicionada na zona fácil do polegar, com botões de altura >= 48px,
/// proteção contra múltiplos toques e diálogo de confirmação para conclusão.
class MobileTaskActions extends StatelessWidget {
  final MobileTaskAvailableActions actions;
  final bool isProcessing;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;

  const MobileTaskActions({
    super.key,
    required this.actions,
    this.isProcessing = false,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
  });

  void _showCompleteConfirmation(BuildContext context) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Concluir Atividade?'),
          content: const Text(
            'Confirma o encerramento da execução desta atividade? '
            'Certifique-se de que as evidências necessárias foram registradas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TFMobileColors.success,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                HapticFeedback.heavyImpact();
                onComplete();
              },
              child: const Text('Confirmar Conclusão'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (actions.isReadOnly) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        TFMobileSpacing.lg,
        TFMobileSpacing.md,
        TFMobileSpacing.lg,
        TFMobileSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10.0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _buildButtons(context),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    if (isProcessing) {
      return Container(
        height: 48.0,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20.0,
              height: 20.0,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: TFMobileSpacing.md),
            Text(
              'Processando alteração...',
              style: TFMobileTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // Caso 1: Tarefa pode ser iniciada (PROG -> ANDA)
    if (actions.canStart) {
      return SizedBox(
        width: double.infinity,
        height: 48.0,
        child: TFPrimaryButton(
          label: 'Iniciar Atividade',
          icon: Icons.play_arrow_rounded,
          height: 48.0,
          onPressed: () {
            HapticFeedback.mediumImpact();
            onStart();
          },
        ),
      );
    }

    // Caso 2: Tarefa em execução (pode pausar ou concluir)
    if (actions.canPause && actions.canComplete) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48.0,
              child: TFSecondaryButton(
                label: 'Pausar',
                icon: Icons.pause_rounded,
                height: 48.0,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onPause();
                },
              ),
            ),
          ),
          const SizedBox(width: TFMobileSpacing.md),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48.0,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TFMobileColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  minimumSize: const Size.fromHeight(48.0),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20.0),
                label: Text(
                  'Concluir',
                  style: TFMobileTypography.label.copyWith(color: Colors.white),
                ),
                onPressed: () => _showCompleteConfirmation(context),
              ),
            ),
          ),
        ],
      );
    }

    // Caso 3: Tarefa pausada (pode retomar)
    if (actions.canResume) {
      return SizedBox(
        width: double.infinity,
        height: 48.0,
        child: TFPrimaryButton(
          label: 'Retomar Atividade',
          icon: Icons.play_arrow_rounded,
          height: 48.0,
          onPressed: () {
            HapticFeedback.mediumImpact();
            onResume();
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
