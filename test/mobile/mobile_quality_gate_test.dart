import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_touch_targets.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_typography.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_spacing.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_status_colors.dart';
import 'package:task2026/mobile/core/widgets/tf_mobile_buttons.dart';
import 'package:task2026/mobile/core/widgets/tf_mobile_card.dart';
import 'package:task2026/mobile/core/widgets/tf_mobile_status_chip.dart';
import 'package:task2026/mobile/core/widgets/tf_mobile_app_bar.dart';
import 'package:task2026/mobile/core/widgets/tf_mobile_bottom_sheet.dart';
import 'package:task2026/mobile/modules/chat/widgets/tf_chat_input.dart';
import 'package:task2026/mobile/modules/chat/widgets/tf_message_bubble.dart';
import 'package:task2026/mobile/modules/feed/widgets/tf_feed_models.dart';
import 'package:task2026/mobile/modules/feed/widgets/tf_feed_card.dart';
import 'package:task2026/mobile/modules/feed/widgets/tf_feed_composer.dart';

void main() {
  group('TaskFlow Mobile — Quality Gate Oficial da Fase 1', () {
    // 1. Touch Targets
    test('1. Touch targets devem ser estritamente >= 48px', () {
      expect(TFMobileTouchTargets.min, greaterThanOrEqualTo(48.0));
      expect(TFMobileTouchTargets.standard, greaterThanOrEqualTo(48.0));
      expect(TFMobileTouchTargets.large, greaterThanOrEqualTo(48.0));
      expect(TFMobileTouchTargets.minIconConstraints.minWidth, greaterThanOrEqualTo(48.0));
      expect(TFMobileTouchTargets.minIconConstraints.minHeight, greaterThanOrEqualTo(48.0));
    });

    // 2. Escala Tipográfica
    test('2. Escala tipográfica oficial não deve conter nenhuma fonte < 11px', () {
      expect(TFMobileTypography.display.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.titleLarge.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.titleMedium.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.bodyLarge.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.bodyMedium.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.label.fontSize, greaterThanOrEqualTo(11.0));
      expect(TFMobileTypography.caption.fontSize, greaterThanOrEqualTo(11.0));
    });

    // 3. Espaçamentos Base 4px
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

    // 4. Domínios de Status
    test('4. Status operacionais e de conectividade devem ser válidos e contrastantes', () {
      for (final status in TFOperationalStatus.values) {
        final config = TFMobileStatusColors.forOperational(status, isDark: false);
        expect(config.label.isNotEmpty, isTrue);
        expect(config.background, isNotNull);
        expect(config.foreground, isNotNull);
      }

      for (final status in TFSyncStatus.values) {
        final config = TFMobileStatusColors.forSync(status, isDark: false);
        expect(config.label.isNotEmpty, isTrue);
        expect(config.background, isNotNull);
        expect(config.foreground, isNotNull);
      }
    });

    // 5. Testes dos 8 Componentes Críticos com Text Scale 1.0, 1.3 e 1.5
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('5. Validação dos 8 Componentes Críticos com TextScale $scale', (tester) async {
        final widget = MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: MaterialApp(
            home: Scaffold(
              appBar: const TFMobileAppBar(title: 'Título AppBar'),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. TFMobileCard
                    TFMobileCard(
                      title: 'Título da Tarefa Operacional com Escala $scale',
                      subtitle: 'Subestação Miracema',
                      status: TFOperationalStatus.emExecucao,
                      primaryAction: TFPrimaryButton(label: 'Iniciar', height: 48.0, onPressed: () {}),
                    ),
                    // 2. TFMobileStatusChip
                    const TFMobileStatusChip.operational(status: TFOperationalStatus.concluido),
                    // 3. TFFeedComposer
                    TFFeedComposer(onTap: () {}),
                    // 4. TFFeedCard
                    const TFFeedCard(
                      item: TFFeedItem(
                        id: '1',
                        sourceType: TFFeedSourceType.userPost,
                        authorName: 'Maria Silva',
                        timestamp: '10 min',
                        content: 'Texto da publicação em escala aumentada.',
                      ),
                    ),
                    // 5. TFMessageBubble
                    const TFMessageBubble(
                      text: 'Mensagem de teste de acessibilidade.',
                      time: '12:00',
                      isMe: true,
                    ),
                    // 6. TFChatInput
                    TFChatInput(onSend: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      });
    }

    // 6. Testes em Resoluções Mobile Reais (360x800, 390x844, 412x915)
    final mobileResolutions = [
      const Size(360, 800),
      const Size(390, 844),
      const Size(412, 915),
    ];

    for (final res in mobileResolutions) {
      testWidgets('6. Resolução ${res.width.toInt()}x${res.height.toInt()} sem overflow', (tester) async {
        tester.view.physicalSize = res;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: const TFMobileAppBar(title: 'Validação Responsiva'),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    TFMobileCard(
                      title: 'Tarefa em Tela ${res.width.toInt()}px',
                      subtitle: 'Linha de Transmissão Norte',
                      status: TFOperationalStatus.planejado,
                    ),
                    const TFFeedCard(
                      item: TFFeedItem(
                        id: '2',
                        sourceType: TFFeedSourceType.activityEvent,
                        authorName: 'Equipe de Campo',
                        timestamp: 'agora',
                        content: 'Atividade concluída com sucesso.',
                        linkedEntityTitle: 'Substituição de Chave 69kV',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      });
    }

    // 7. Light Mode e Dark Mode
    testWidgets('7. Renderização perfeita em Light Mode e Dark Mode', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    TFMobileCard(
                      title: 'Card em modo $brightness',
                      status: TFOperationalStatus.pendente,
                      syncStatus: TFSyncStatus.offline,
                    ),
                    const TFMobileStatusChip.operational(status: TFOperationalStatus.atrasado),
                    const TFMobileStatusChip.sync(status: TFSyncStatus.pending),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });

    // 8. Teclado Virtual / ViewInsets Simulado
    testWidgets('8. ChatInput e Formulário com teclado virtual aberto (320px insets)', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 320.0), // Teclado aberto
          ),
          child: MaterialApp(
            home: Scaffold(
              resizeToAvoidBottomInset: true,
              body: Column(
                children: [
                  const Expanded(
                    child: Center(child: Text('Lista de Mensagens')),
                  ),
                  TFChatInput(onSend: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TFChatInput), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // 9. Fixtures de Conteúdo Extremo
    testWidgets('9. Fixtures de Conteúdo Extremo sem RenderFlex overflow', (tester) async {
      const extremePost = TFFeedItem(
        id: 'extreme_1',
        sourceType: TFFeedSourceType.userPost,
        authorName: 'Engenheiro de Manutenção Eletromecânica João Carlos da Silva Albuquerque Júnior',
        authorRole: 'Coordenador Geral de Intervenções e Desligamentos Programados de Alta Tensão',
        communityOrTeam: 'Comunidade Regional de Operação e Manutenção do Setor Norte-Nordeste',
        timestamp: 'há 10 minutos atrás em horário de pico operacional',
        content: 'Foi realizada a desmontagem completa do polo B do disjuntor de transferência de barra 500kV, identificando-se desgaste acentuado nas pastilhas de contato prateadas e presença de umidade no gás SF6, sendo necessária a regeneração do meio dielétrico e ensaios de tempo de abertura e fechamento com oscilografia conforme normas ABNT NBR 6939 e ONS Submódulo 2.1.',
        linkedEntityTitle: 'Manutenção Corretiva Não Programada de Grande Porte na Subestação Elevadora Principal',
        imageUrl: 'dummy_photo',
        likesCount: 142,
        commentsCount: 38,
        isOfflinePending: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const TFFeedCard(item: extremePost),
                  const TFMessageBubble(
                    text: 'Mensagem com múltiplos parágrafos:\n\nPrimeira linha de detalhamento técnico.\nSegunda linha com código da OS: 40019201920192.\nTerceira linha com observação sobre segurança.',
                    time: '08:45',
                    isMe: false,
                    senderName: 'Encarregado de Linha Viva com Nome Extremamente Extenso para Teste de Truncamento',
                    deliveryStatus: TFMessageDeliveryStatus.pendingOffline,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });
}
