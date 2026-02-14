import 'package:flutter/material.dart';
import '../../data/models/task_warning.dart';
import 'warning_severity_theme.dart';

/// Badge que agrega quantidade de alertas; cor pela maior severidade; clique abre painel.
/// Tooltip omitido na tabela para evitar assertion no MouseTracker (muitos tooltips em lista).
class WarningsBadge extends StatelessWidget {
  final List<TaskWarning> warnings;
  final VoidCallback onTap;
  final bool isMobile;
  final Color? rowBackgroundColor;
  final bool enableTooltip;

  const WarningsBadge({
    super.key,
    required this.warnings,
    required this.onTap,
    this.isMobile = false,
    this.rowBackgroundColor,
    this.enableTooltip = false,
  });

  @override
  Widget build(BuildContext context) {
    final cellWidth = isMobile ? 45.0 : 50.0;
    if (warnings.isEmpty) {
      return SizedBox(
        width: cellWidth,
        child: Center(
          child: Icon(Icons.check_circle_outline, size: isMobile ? 12 : 14, color: Colors.grey.shade400),
        ),
      );
    }

    final count = warnings.length;
    final maxSev = WarningSeverityTheme.maxSeverity(warnings);
    final color = WarningSeverityTheme.colorForSeverity(maxSev);

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: cellWidth,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.shade300, width: 0.5),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: isMobile ? 14 : 16, color: color),
              SizedBox(width: isMobile ? 2 : 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: rowBackgroundColor != null && rowBackgroundColor != Colors.white
                      ? Colors.grey.shade800
                      : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (enableTooltip) {
      final tooltipMessage = warnings.map((w) => '${w.warningCode}: ${w.message}').join('\n');
      return Tooltip(
        message: tooltipMessage,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 500),
        child: SizedBox(width: cellWidth, height: double.infinity, child: content),
      );
    }
    return SizedBox(width: cellWidth, height: double.infinity, child: content);
  }
}
