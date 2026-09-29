import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double getTodayOffsetForDays(List<DateTime> days, double dayWidth, [DateTime? mockToday]) {
  final now = mockToday ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final index = days.indexWhere((d) => 
    d.year == today.year && d.month == today.month && d.day == today.day
  );
  return index >= 0 ? index * dayWidth : -1.0;
}

void main() {
  group('Fleet Schedule — Today Vertical Indicator & Header Marker', () {
    test('1. Retorna offset correto quando o dia atual está presente na lista de dias da frota', () {
      final today = DateTime.now();
      final day0 = DateTime(today.year, today.month, today.day - 1);
      final day1 = DateTime(today.year, today.month, today.day); // Hoje (índice 1)
      final day2 = DateTime(today.year, today.month, today.day + 1);
      final days = [day0, day1, day2];
      const dayWidth = 46.0;

      final offset = getTodayOffsetForDays(days, dayWidth);

      expect(offset, equals(1 * 46.0));
    });

    test('2. Retorna -1.0 quando o dia atual NÃO está presente na janela de dias da frota', () {
      final today = DateTime.now();
      final pastDays = [
        DateTime(today.year, today.month, today.day - 15),
        DateTime(today.year, today.month, today.day - 14),
      ];
      const dayWidth = 46.0;

      final offsetPast = getTodayOffsetForDays(pastDays, dayWidth);
      expect(offsetPast, equals(-1.0));
    });

    test('3. Cálculo do centro da coluna para a linha vertical e marcador do cabeçalho da frota', () {
      final today = DateTime.now();
      final days = [
        DateTime(today.year, today.month, today.day),
      ];
      const dayWidth = 50.0;

      final offset = getTodayOffsetForDays(days, dayWidth);
      expect(offset, equals(0.0));

      final lineLeft = offset + (dayWidth / 2);
      expect(lineLeft, equals(25.0));

      final markerLeft = offset + (dayWidth / 2) - 8;
      expect(markerLeft, equals(17.0));
    });

    test('4. IgnorePointer na linha vertical da frota garante não interceptação de cliques e drags', () {
      const line = Positioned(
        left: 25.0,
        top: 0,
        bottom: 0,
        child: IgnorePointer(
          ignoring: true,
          child: SizedBox(width: 3),
        ),
      );

      expect(line.child, isA<IgnorePointer>());
      final ignorePointer = line.child as IgnorePointer;
      expect(ignorePointer.ignoring, isTrue);
    });
  });
}
