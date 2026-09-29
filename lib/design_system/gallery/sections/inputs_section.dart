import 'package:flutter/material.dart';
import '../../components/inputs/tf_dropdown.dart';
import '../../components/inputs/tf_text_field.dart';
import '../../foundations/tf_icons.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class InputsSection extends StatefulWidget {
  const InputsSection({super.key});

  @override
  State<InputsSection> createState() => _InputsSectionState();
}

class _InputsSectionState extends State<InputsSection> {
  String? _selectedRegional = 'Recife';
  String? _selectedTipo;

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'Entradas de Formulário (TFTextField & TFDropdown)',
      description: 'Campos de formulário e seleção suspensa com suporte a rótulos obrigatórios, ícones, estados de foco, loading e mensagens de erro sem quebra de layout.',
      children: [
        GalleryPreviewCard(
          title: 'TFTextField — Campos de Texto',
          description: 'Padrão, obrigatório, com erro, desabilitado e com ícones',
          child: Column(
            children: [
              const TFTextField(
                label: 'Descrição da Atividade',
                hint: 'Ex: Troca de isolador em cadeia de suspensão',
                helperText: 'Informe com clareza o escopo do serviço',
              ),
              SizedBox(height: spacing.md),
              const TFTextField(
                label: 'Número da Ordem SAP',
                hint: 'Ex: 40019284',
                required: true,
                prefixIcon: Icon(TFIcons.sap, size: 18),
              ),
              SizedBox(height: spacing.md),
              const TFTextField(
                label: 'Código do Vão / Linha',
                hint: 'Ex: LT-TER-01',
                errorText: 'Vão não localizado no inventário',
              ),
              SizedBox(height: spacing.md),
              const TFTextField(
                label: 'Identificador do Ativo (Bloqueado)',
                hint: 'ID-994820',
                enabled: false,
                prefixIcon: Icon(TFIcons.settings, size: 18),
              ),
              SizedBox(height: spacing.md),
              const TFTextField(
                label: 'Observações de Campo',
                hint: 'Detalhes adicionais coletados pela equipe...',
                maxLines: 3,
              ),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'TFDropdown — Seleção Suspensa',
          description: 'Estados: Padrão, selecionado, com erro, carregando e desabilitado',
          child: Column(
            children: [
              TFDropdown<String>(
                label: 'Regional Operacional',
                value: _selectedRegional,
                items: const ['Recife', 'Fortaleza', 'Salvador', 'Teresina'],
                displayText: (item) => item,
                isRequired: true,
                showClearButton: true,
                onChanged: (val) => setState(() => _selectedRegional = val),
              ),
              SizedBox(height: spacing.md),
              TFDropdown<String>(
                label: 'Tipo de Atividade (Com Erro)',
                value: _selectedTipo,
                items: const ['Manutenção Preventiva', 'Linha Viva', 'Inspeção'],
                displayText: (item) => item,
                errorText: 'Selecione um tipo válido para prosseguir',
                onChanged: (val) => setState(() => _selectedTipo = val),
              ),
              SizedBox(height: spacing.md),
              TFDropdown<String>(
                label: 'Divisão Vinculada (Carregando)',
                value: null,
                items: const [],
                isLoading: true,
                displayText: (item) => item,
                onChanged: (val) {},
              ),
              SizedBox(height: spacing.md),
              TFDropdown<String>(
                label: 'Empresa Contratada (Bloqueado)',
                value: 'Empresa Própria',
                items: const ['Empresa Própria', 'Terceirizada'],
                enabled: false,
                displayText: (item) => item,
                onChanged: (val) {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
