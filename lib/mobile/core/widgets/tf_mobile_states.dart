import 'package:flutter/material.dart';
import '../theme/tf_mobile_spacing.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_colors.dart';
import '../theme/tf_mobile_touch_targets.dart';
import 'tf_mobile_buttons.dart';

/// Estado de Carregamento nativo com feedback tátil e visual limpo.
class TFLoadingState extends StatelessWidget {
  final String message;

  const TFLoadingState({
    super.key,
    this.message = 'Carregando dados operacionais...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TFMobileSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                valueColor: AlwaysStoppedAnimation<Color>(TFMobileColors.primaryBlue),
              ),
            ),
            const SizedBox(height: TFMobileSpacing.lg),
            Text(
              message,
              style: TFMobileTypography.bodyMedium.copyWith(
                color: TFMobileColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado Vazio voltado para Adoção e engajamento operacional (Regra #8).
class TFEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const TFEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  /// Construtor focado na adoção do Feed / Comunidade (conforme instrução obrigatória).
  const TFEmptyState.feedCommunity({
    super.key,
    this.title = 'Ainda não há atualizações nesta comunidade',
    this.description = 'Compartilhe uma informação, foto ou boa prática com sua equipe para iniciar a conversa.',
    this.icon = Icons.forum_outlined,
    this.actionLabel = 'Compartilhar atualização',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TFMobileSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: TFMobileColors.primaryBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36.0,
                color: TFMobileColors.primaryBlue,
              ),
            ),
            const SizedBox(height: TFMobileSpacing.xl),
            Text(
              title,
              style: TFMobileTypography.titleLarge.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TFMobileSpacing.sm),
            Text(
              description,
              style: TFMobileTypography.bodyLarge.copyWith(
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: TFMobileSpacing.xxl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: TFPrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  height: TFMobileTouchTargets.standard,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de Erro Operacional.
class TFErrorState extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onRetry;

  const TFErrorState({
    super.key,
    this.title = 'Não foi possível carregar as informações',
    this.description = 'Verifique sua conexão ou tente novamente em instantes.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TFMobileSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: TFMobileColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32.0,
                color: TFMobileColors.error,
              ),
            ),
            const SizedBox(height: TFMobileSpacing.lg),
            Text(
              title,
              style: TFMobileTypography.titleLarge.copyWith(
                color: TFMobileColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TFMobileSpacing.sm),
            Text(
              description,
              style: TFMobileTypography.bodyMedium.copyWith(
                color: TFMobileColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: TFMobileSpacing.xl),
              TFSecondaryButton(
                label: 'Tentar Novamente',
                onPressed: onRetry,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de Falta de Conexão (Sem cache local).
class TFOfflineState extends StatelessWidget {
  final VoidCallback? onRetry;

  const TFOfflineState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TFMobileSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54.0, color: TFMobileColors.warning),
            const SizedBox(height: TFMobileSpacing.lg),
            Text(
              'Você está offline',
              style: TFMobileTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TFMobileSpacing.sm),
            Text(
              'Este conteúdo ainda não foi baixado para o dispositivo. Conecte-se à rede para sincronizar.',
              style: TFMobileTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: TFMobileSpacing.xl),
              TFSecondaryButton(
                label: 'Verificar Conexão',
                onPressed: onRetry,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de Busca sem Resultados.
class TFNoResultsState extends StatelessWidget {
  final String query;
  final VoidCallback? onClear;

  const TFNoResultsState({
    super.key,
    required this.query,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TFMobileSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48.0, color: Colors.grey),
            const SizedBox(height: TFMobileSpacing.md),
            Text(
              'Nenhum resultado encontrado',
              style: TFMobileTypography.titleMedium,
            ),
            const SizedBox(height: TFMobileSpacing.xs),
            Text(
              'Não encontramos itens correspondentes a "$query".',
              style: TFMobileTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onClear != null) ...[
              const SizedBox(height: TFMobileSpacing.lg),
              TFTertiaryButton(
                label: 'Limpar busca',
                onPressed: onClear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
