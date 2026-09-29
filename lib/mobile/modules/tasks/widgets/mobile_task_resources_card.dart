import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../models/mobile_task_detail_view_model.dart';

/// Seção compacta de Equipe e Recursos da Atividade.
/// Exibe encarregado, equipe, executores e frota factual, com expansão sob demanda.
class MobileTaskResourcesCard extends StatefulWidget {
  final MobileTaskDetailViewModel task;

  const MobileTaskResourcesCard({
    super.key,
    required this.task,
  });

  @override
  State<MobileTaskResourcesCard> createState() => _MobileTaskResourcesCardState();
}

class _MobileTaskResourcesCardState extends State<MobileTaskResourcesCard> {
  bool _expandedExecutors = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final hasTeam = t.teamName != null && t.teamName!.isNotEmpty;
    final hasExecutors = t.executorsList.isNotEmpty;
    final hasVehicle = t.vehiclePlate != null && t.vehiclePlate!.isNotEmpty;
    final hasCoord = t.coordenador != null && t.coordenador!.isNotEmpty;

    if (!hasTeam && !hasExecutors && !hasVehicle && !hasCoord) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.lg, vertical: TFMobileSpacing.xs),
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, size: 20.0, color: Color(0xFF3B82F6)),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: Text(
                  'Equipe & Recursos',
                  style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFMobileSpacing.md),

          // Equipe
          if (hasTeam)
            _buildInfoRow(
              icon: Icons.groups_outlined,
              label: 'Equipe',
              value: t.teamName!,
              isDark: isDark,
            ),

          // Coordenador / Encarregado
          if (hasCoord)
            _buildInfoRow(
              icon: Icons.badge_outlined,
              label: 'Coordenador',
              value: t.coordenador!,
              isDark: isDark,
            ),

          // Veículo / Frota
          if (hasVehicle)
            _buildInfoRow(
              icon: Icons.directions_car_filled_outlined,
              label: 'Veículo',
              value: t.vehiclePlate!,
              isDark: isDark,
            ),

          // Lista de Executores (Expansível se > 2)
          if (hasExecutors) ...[
            Padding(
              padding: const EdgeInsets.only(top: TFMobileSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Executores (${t.executorsList.length})',
                          style: TFMobileTypography.caption.copyWith(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (t.executorsList.length > 2)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _expandedExecutors = !_expandedExecutors;
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(_expandedExecutors ? 'Menos' : 'Ver todos'),
                        ),
                    ],
                  ),
                  const SizedBox(height: TFMobileSpacing.xs),
                  Wrap(
                    spacing: TFMobileSpacing.xs,
                    runSpacing: TFMobileSpacing.xs,
                    children: (_expandedExecutors
                            ? t.executorsList
                            : t.executorsList.take(2).toList())
                        .map((exec) {
                      return Chip(
                        label: Text(exec, style: TFMobileTypography.caption),
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(4.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: BorderSide(color: borderColor),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.0,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: TFMobileSpacing.xs),
          Text(
            '$label: ',
            style: TFMobileTypography.caption.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TFMobileTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
