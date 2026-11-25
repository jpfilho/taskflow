import 'package:flutter/material.dart';
import '../../../../design_system/taskflow_design_system.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';

/// Banner explícito de estado para Apoios Operacionais (Demonstração,
/// Autenticação Pendente, Backend Indisponível ou Erro de Consulta).
class TaskApoioBannerEstado extends StatelessWidget {
  final TaskApoioDisponibilidadeEstado estado;
  final String? mensagemErro;
  final VoidCallback? onAtivarDemo;
  final VoidCallback? onTentarNovamente;

  const TaskApoioBannerEstado({
    super.key,
    required this.estado,
    this.mensagemErro,
    this.onAtivarDemo,
    this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;

    if (estado == TaskApoioDisponibilidadeEstado.disponivel &&
        mensagemErro == null) {
      return const SizedBox.shrink();
    }

    final (IconData icon, Color bg, Color fg, String titulo, String subtitulo) =
        switch (estado) {
      TaskApoioDisponibilidadeEstado.modoDemonstracao => (
          Icons.science_outlined,
          colors.infoBackground,
          colors.info,
          'MODO DEMONSTRAÇÃO (DEV)',
          'Dados simulados para homologação visual. Nenhuma solicitação representa compromisso real entre unidades.',
        ),
      TaskApoioDisponibilidadeEstado.autenticacaoPendente => (
          Icons.lock_outline_rounded,
          colors.warningBackground,
          colors.warning,
          'Apoios Operacionais protegidos',
          'Acesso real ao backend aguarda autenticação verificável. O funcionamento normal das atividades permanece inalterado.',
        ),
      TaskApoioDisponibilidadeEstado.backendIndisponivel => (
          Icons.cloud_off_rounded,
          colors.dangerBackground,
          colors.danger,
          'Serviço de Apoios indisponível',
          mensagemErro ??
              'Não foi possível consultar os apoios operacionais neste momento.',
        ),
      TaskApoioDisponibilidadeEstado.disponivel => (
          Icons.error_outline_rounded,
          colors.dangerBackground,
          colors.danger,
          'Erro ao consultar apoios',
          mensagemErro ?? 'Falha de comunicação ao consultar apoios.',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: TFRadius.borderRadiusMd,
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: typo.labelMedium.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (onAtivarDemo != null &&
                  estado != TaskApoioDisponibilidadeEstado.modoDemonstracao)
                TFButton(
                  label: 'Simular cenários (DEV)',
                  variant: TFButtonVariant.secondary,
                  size: TFButtonSize.small,
                  leadingIcon: Icons.science_outlined,
                  onPressed: onAtivarDemo,
                ),
              if (onTentarNovamente != null &&
                  estado == TaskApoioDisponibilidadeEstado.backendIndisponivel)
                TFButton(
                  label: 'Tentar novamente',
                  variant: TFButtonVariant.tertiary,
                  size: TFButtonSize.small,
                  onPressed: onTentarNovamente,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
