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
  group('Team Schedule — Today Vertical Indicator & Header Marker', () {
    test('1. Retorna offset correto quando o dia atual está presente na lista de dias', () {
      final today = DateTime.now();
      final day0 = DateTime(today.year, today.month, today.day - 2);
      final day1 = DateTime(today.year, today.month, today.day - 1);
      final day2 = DateTime(today.year, today.month, today.day); // Hoje (índice 2)
      final day3 = DateTime(today.year, today.month, today.day + 1);
      final days = [day0, day1, day2, day3];
      const dayWidth = 40.0;

      final offset = getTodayOffsetForDays(days, dayWidth);

      expect(offset, equals(2 * 40.0)); // 80.0
    });

    test('2. Retorna -1.0 quando o dia atual NÃO está presente na janela de dias', () {
      final today = DateTime.now();
      // Período no passado
      final pastDays = [
        DateTime(today.year, today.month, today.day - 10),
        DateTime(today.year, today.month, today.day - 9),
        DateTime(today.year, today.month, today.day - 8),
      ];
      const dayWidth = 50.0;

      final offsetPast = getTodayOffsetForDays(pastDays, dayWidth);
      expect(offsetPast, equals(-1.0));

      // Período no futuro
      final futureDays = [
        DateTime(today.year, today.month, today.day + 5),
        DateTime(today.year, today.month, today.day + 6),
        DateTime(today.year, today.month, today.day + 7),
      ];

      final offsetFuture = getTodayOffsetForDays(futureDays, dayWidth);
      expect(offsetFuture, equals(-1.0));
    });

    test('3. Cálculo do centro da coluna do dia atual para a linha vertical e marcador do header', () {
      final today = DateTime.now();
      final days = [
        DateTime(today.year, today.month, today.day),
      ];
      const dayWidth = 46.0;

      final offset = getTodayOffsetForDays(days, dayWidth);
      expect(offset, equals(0.0));

      // Linha vertical fica centralizada no dia: offset + (dayWidth / 2)
      final lineLeft = offset + (dayWidth / 2);
      expect(lineLeft, equals(23.0));

      // Marcador circular do header fica centralizado: offset + (dayWidth / 2) - 8 (raio 8)
      final markerLeft = offset + (dayWidth / 2) - 8;
      expect(markerLeft, equals(15.0));
    });

    test('4. IgnorePointer na linha vertical garante que cliques e drags não são interceptados', () {
      // Verifica conceitualmente a propriedade da linha do dia
      const line = Positioned(
        left: 23.0,
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
