import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../../../core/theme/tf_mobile_touch_targets.dart';
import '../models/mobile_agenda_day_summary.dart';

/// Seletor de dia em carrossel horizontal ergonômico para smartphones.
/// Apresenta o dia da semana, número do mês, indicador de 'Hoje',
/// contagem de tarefas e alerta de conflito com touch target >= 48px.
class DayCarouselSelector extends StatefulWidget {
  final List<MobileAgendaDaySummary> days;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  const DayCarouselSelector({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.onDaySelected,
  });

  @override
  State<DayCarouselSelector> createState() => _DayCarouselSelectorState();
}

class _DayCarouselSelectorState extends State<DayCarouselSelector> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(DayCarouselSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _scrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!mounted || widget.days.isEmpty || !_scrollController.hasClients) return;

    final index = widget.days.indexWhere(
        (d) => isSameDay(d.date, widget.selectedDate));
    if (index >= 0) {
      // 64px é a largura média do chip + margem
      final targetOffset = (index * 68.0) - 100.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 96.0,
      padding: const EdgeInsets.symmetric(vertical: TFMobileSpacing.xs),
      decoration: BoxDecoration(
        color: TFMobileColors.surface(context),
        border: Border(
          bottom: BorderSide(color: TFMobileColors.border(context), width: 1.0),
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md),
        itemCount: widget.days.length,
        itemBuilder: (context, index) {
          final summary = widget.days[index];
          final isSelected = isSameDay(summary.date, widget.selectedDate);

          return _buildDayItem(
            context: context,
            summary: summary,
            isSelected: isSelected,
            isDark: isDark,
          );
        },
      ),
    );
  }

  Widget _buildDayItem({
    required BuildContext context,
    required MobileAgendaDaySummary summary,
    required bool isSelected,
    required bool isDark,
  }) {
    final weekdayStr = DateFormat('EEE', 'pt_BR')
        .format(summary.date)
        .replaceAll('.', '')
        .toUpperCase();

    final dayNum = summary.date.day.toString();

    Color bgColor;
    Color textColor;
    Border border;

    if (isSelected) {
      bgColor = TFMobileColors.primaryBlue;
      textColor = Colors.white;
      border = Border.all(color: TFMobileColors.primaryBlue, width: 1.5);
    } else if (summary.isToday) {
      bgColor = isDark
          ? TFMobileColors.primaryBlue.withValues(alpha: 0.2)
          : const Color(0xFFEBF5FF);
      textColor = TFMobileColors.primaryBlue;
      border = Border.all(color: TFMobileColors.primaryBlue, width: 1.5);
    } else {
      bgColor = isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFF8FAFC);
      textColor = summary.isWeekend
          ? TFMobileColors.textSecondary(context)
          : TFMobileColors.textPrimary(context);
      border = Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        width: 1.0,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: TFMobileSpacing.xs),
      child: Semantics(
        label: 'Dia $dayNum, $weekdayStr. ${summary.totalTasks} tarefas.',
        selected: isSelected,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onDaySelected(summary.date);
            },
            borderRadius: BorderRadius.circular(12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 58.0,
                minHeight: TFMobileTouchTargets.min,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: TFMobileSpacing.xs,
                  vertical: TFMobileSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12.0),
                  border: border,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Dia da Semana (SEG, TER, ...)
                    Text(
                      weekdayStr,
                      style: TFMobileTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 10.0,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : (summary.isToday
                                ? TFMobileColors.primaryBlue
                                : TFMobileColors.textSecondary(context)),
                      ),
                    ),
                    const SizedBox(height: 2.0),

                    // Número do Dia
                    Text(
                      dayNum,
                      style: TFMobileTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4.0),

                    // Indicadores: Tarefas e Conflitos
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (summary.hasConflict)
                          Container(
                            width: 6.0,
                            height: 6.0,
                            margin: const EdgeInsets.only(right: 3.0),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444), // Vermelho de conflito
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (summary.totalTasks > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 1.0,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Text(
                              '${summary.totalTasks}',
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : TFMobileColors.textPrimary(context),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 12.0),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
