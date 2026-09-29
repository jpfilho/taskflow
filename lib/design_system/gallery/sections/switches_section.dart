import 'package:flutter/material.dart';
import '../../components/inputs/tf_switch.dart';
import '../../foundations/tf_density.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class SwitchesSection extends StatefulWidget {
  const SwitchesSection({super.key});

  @override
  State<SwitchesSection> createState() => _SwitchesSectionState();
}

class _SwitchesSectionState extends State<SwitchesSection> {
  bool _switch1 = true;
  bool _switch2 = false;
  bool _switchLabel1 = true;
  bool _switchLabel2 = false;
  bool _switchDense = true;
  bool _switchComfortable = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'TFSwitch — Controles Booleanos',
      description: 'Controle booleano padronizado com suporte a acessibilidade, leitor de telas, densidades e estados.',
      children: [
        GalleryPreviewCard(
          title: 'Estados Básicos',
          description: 'ON, OFF e Desabilitado (com área de toque mínima acessível)',
          child: Wrap(
            spacing: spacing.lg,
            runSpacing: spacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TFSwitch(
                value: _switch1,
                onChanged: (val) => setState(() => _switch1 = val),
                label: 'Ativo (ON)',
              ),
              TFSwitch(
                value: _switch2,
                onChanged: (val) => setState(() => _switch2 = val),
                label: 'Inativo (OFF)',
              ),
              const TFSwitch(
                value: true,
                enabled: false,
                onChanged: null,
                label: 'Desabilitado (ON)',
              ),
              const TFSwitch(
                value: false,
                enabled: false,
                onChanged: null,
                label: 'Desabilitado (OFF)',
              ),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Com Título e Descrição',
          description: 'Para formulários e configurações com texto auxiliar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TFSwitch(
                value: _switchLabel1,
                onChanged: (val) => setState(() => _switchLabel1 = val),
                label: 'Notificações de Manutenção SAP',
                description: 'Receber alertas em tempo real quando ordens forem despachadas para sua regional.',
              ),
              SizedBox(height: spacing.md),
              TFSwitch(
                value: _switchLabel2,
                onChanged: (val) => setState(() => _switchLabel2 = val),
                label: 'Modo Offline Forçado',
                description: 'Desabilita requisições ativas ao Supabase e enfileira transações no SQLite local.',
              ),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Variações de Densidade',
          description: 'Comfortable (44px/24px), Compact (38px/20px), Dense (32px/16px)',
          child: Wrap(
            spacing: spacing.lg,
            runSpacing: spacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TFSwitch(
                value: _switchComfortable,
                densityMode: TFDensityMode.comfortable,
                onChanged: (val) => setState(() => _switchComfortable = val),
                label: 'Comfortable',
              ),
              TFSwitch(
                value: _switch1,
                densityMode: TFDensityMode.compact,
                onChanged: (val) => setState(() => _switch1 = val),
                label: 'Compact (Padrão)',
              ),
              TFSwitch(
                value: _switchDense,
                densityMode: TFDensityMode.dense,
                onChanged: (val) => setState(() => _switchDense = val),
                label: 'Dense',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
