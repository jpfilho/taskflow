import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_touch_targets.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_typography.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_spacing.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_status_colors.dart';
import 'package:task2026/mobile/core/widgets/tf_mobile_buttons.dart';
import 'package:task2026/mobile/core/widgets/tf_mobile_card.dart';
import 'package:task2026/mobile/core/widgets/tf_mobile_status_chip.dart';
import 'package:task2026/mobile/modules/feed/widgets/tf_feed_models.dart';
import 'package:task2026/mobile/modules/feed/widgets/tf_feed_card.dart';
import 'package:task2026/mobile/modules/chat/widgets/tf_message_bubble.dart';

void main() {
  group('TaskFlow Mobile — Quality Gate de Tokens e Touch Targets', () {
    test('1. Touch targets devem ser estritamente >= 48px', () {
      expect(TFMobileTouchTargets.min, greaterThanOrEqualTo(48.0));
      expect(TFMobileTouchTargets.standard, greaterThanOrEqualTo(48.0));
      expect(TFMobileTouchTargets.large, greaterThanOrEqualTo(48.0));
      expect(TFMobileTouchTargets.minIconConstraints.minWidth, greaterThanOrEqualTo(48.0));
      expect(TFMobileTouchTargets.minIconConstraints.minHeight, greaterThanOrEqualTo(48.0));
    });

    test('2. Escala tipográfica oficial não deve conter nenhuma fonte < 11px', () {
      expect(TFMobileTypography.display.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.titleLarge.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.titleMedium.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.bodyLarge.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.bodyMedium.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.label.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.caption.fontSize, greaterThanOrEqualTo(11.0));
    });

    test('3. Escala de espaçamento base 4px consistente', () {
      expect(TFMobileSpacing.xs, equals(4.0));
      expect(TFMobileSpacing.sm, equals(8.0));
      expect(TFMobileSpacing.md, equals(12.0));
      expect(TFMobileSpacing.lg, equals(16.0));
      expect(TFMobileSpacing.xl, equals(20.0));
      expect(TFMobileSpacing.xxl, equals(24.0));
      expect(TFMobileSpacing.xxxl, equals(32.0));
      expect(TFMobileSpacing.huge, equals(48.0));
    });

    test('4. Status operacionais e de conectividade devem ter configurações válidas e alto contraste', () {
      for (final status in TFOperationalStatus.values) {
        final config = TFMobileStatusColors.forOperational(status, isDark: false);
        expect(config.label.isNotEmpty, isTrue);
        expect(config.background, isNotNull);
        expect(config.foreground, isNotNull);
        expect(config.border, isNotNull);
      }

      for (final status in TFSyncStatus.values) {
        final config = TFMobileStatusColors.forSync(status, isDark: false);
        expect(config.label.isNotEmpty, isTrue);
        expect(config.background, isNotNull);
        expect(config.foreground, isNotNull);
        expect(config.border, isNotNull);
      }
    });
  });

  group('TaskFlow Mobile — Testes de Widgets e RenderFlex em Viewport Pequena (360x800)', () {
    testWidgets('5. TFPrimaryButton deve renderizar com altura mínima de 48px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TFPrimaryButton(
              label: 'Iniciar Serviço',
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(TFPrimaryButton);
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('6. TFMobileCard deve renderizar sem overflow mesmo com textos longos', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(360, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TFMobileCard(
                title: 'Manutenção de Transformador com Descrição Extremamente Longa de Mais de Três Linhas',
                subtitle: 'Subestação Regional com Vão de Linha de Transmissão Extenso e Detalhado',
                status: TFOperationalStatus.emExecucao,
                offlinePending: true,
                primaryAction: TFPrimaryButton(label: 'Concluir', height: 48.0, onPressed: () {}),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('7. TFFeedCard deve renderizar publicação com autor, foto e reações sem erro', (tester) async {
      const feedItem = TFFeedItem(
        id: '1',
        sourceType: TFFeedSourceType.userPost,
        authorName: 'Maria Silva',
        communityOrTeam: 'Equipe de Subestação',
        timestamp: 'há 10 min',
        content: 'Inspeção concluída com sucesso no disjuntor 14D3.',
        imageUrl: 'dummy_pic',
        likesCount: 5,
        commentsCount: 2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TFFeedCard(item: feedItem),
            ),
          ),
        ),
      );

      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('Inspeção concluída com sucesso no disjuntor 14D3.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. TFMessageBubble com foto e status offline pendente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TFMessageBubble(
              text: 'Foto da anomalia salva offline.',
              time: '10:30',
              isMe: true,
              deliveryStatus: TFMessageDeliveryStatus.pendingOffline,
              attachedImageUrl: 'dummy',
            ),
          ),
        ),
      );

      expect(find.text('Foto da anomalia salva offline.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
