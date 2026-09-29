import 'package:flutter/material.dart';
import '../../components/buttons/tf_icon_button.dart';
import '../../components/status/tf_status_badge.dart';
import '../../components/tables/tf_data_table.dart';
import '../../foundations/tf_density.dart';
import '../../foundations/tf_icons.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class _CargoMock {
  final String id;
  final String cargo;
  final String area;
  final bool ativo;

  const _CargoMock(this.id, this.cargo, this.area, this.ativo);
}

class TablesSection extends StatelessWidget {
  const TablesSection({super.key});

  static const List<_CargoMock> _sampleThreeItems = [
    _CargoMock('1', 'Eletricista de Linha Viva', 'Manutenção AT', true),
    _CargoMock('2', 'Engenheiro de Proteção', 'Subestações', true),
    _CargoMock('3', 'Técnico de Medição', 'Inspeção BT', false),
  ];

  static const List<_CargoMock> _sampleTenItems = [
    _CargoMock('1', 'Eletricista de Rede', 'Distribuição', true),
    _CargoMock('2', 'Engenheiro Civil', 'Obras Civis', true),
    _CargoMock('3', 'Técnico em Telecomunicações', 'Redes & SCADA', true),
    _CargoMock('4', 'Mecânico de Guindauto', 'Frota Pesada', false),
    _CargoMock('5', 'Operador de Subestação', 'Operação Centro', true),
    _CargoMock('6', 'Inspetor Termográfico', 'Predial & Termovisão', true),
    _CargoMock('7', 'Eletricista de Emergência', 'Plantão 24h', true),
    _CargoMock('8', 'Coordenador de Pátio', 'Logística & Postes', true),
    _CargoMock('9', 'Auxiliar de Eletricista', 'Apoio Operacional', false),
    _CargoMock('10', 'Engenheiro de Segurança', 'SESMT', true),
  ];

  List<TFDataColumn<_CargoMock>> _buildColumns(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return [
      TFDataColumn<_CargoMock>.text(
        id: 'cargo',
        title: 'Função / Cargo',
        cellBuilder: (ctx, item) => Text(
          item.cargo,
          style: typography.bodyMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      TFDataColumn<_CargoMock>.text(
        id: 'area',
        title: 'Segmento Operacional',
        cellBuilder: (ctx, item) => Text(
          item.area,
          style: typography.bodySmall.copyWith(color: colors.textSecondary),
        ),
      ),
      TFDataColumn<_CargoMock>(
        id: 'status',
        label: const Text('Status'),
        width: 130,
        cellBuilder: (ctx, item) => Align(
          alignment: Alignment.centerLeft,
          child: TFStatusBadge(
            label: item.ativo ? 'Ativo' : 'Inativo',
            severity: item.ativo ? TFStatusSeverity.success : TFStatusSeverity.neutral,
            icon: item.ativo ? TFIcons.success : TFIcons.warning,
            compact: true,
          ),
        ),
      ),
      TFDataColumn<_CargoMock>(
        id: 'acoes',
        label: const Text('Ações'),
        width: 160,
        alignment: Alignment.centerRight,
        cellBuilder: (ctx, item) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TFIconButton(
              icon: TFIcons.edit,
              tooltip: 'Editar',
              variant: TFIconButtonVariant.standard,
              iconSize: 18,
              onPressed: () {},
            ),
            TFIconButton(
              icon: Icons.copy_rounded,
              tooltip: 'Duplicar',
              variant: TFIconButtonVariant.subtle,
              iconSize: 18,
              onPressed: () {},
            ),
            TFIconButton(
              icon: TFIcons.delete,
              tooltip: 'Excluir',
              variant: TFIconButtonVariant.danger,
              iconSize: 18,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'TFDataTable — Tabelas de Dados',
      description: 'Componente de tabela corporativa com cabeçalhos semânticos, densidade configurável e ações de linha integradas.',
      children: [
        GalleryPreviewCard(
          title: 'Tabela Padrão (3 Registros com Ações)',
          description: 'Densidade Compact (padrão) com ações de linha padronizadas',
          child: TFDataTable<_CargoMock>(
            columns: _buildColumns(context),
            items: _sampleThreeItems,
            zebra: true,
          ),
        ),
        GalleryPreviewCard(
          title: 'Tabela Densa (10 Registros)',
          description: 'Densidade Dense para alto volume de dados em telas operacionais',
          child: TFDataTable<_CargoMock>(
            columns: _buildColumns(context),
            items: _sampleTenItems,
            densityMode: TFDensityMode.dense,
            zebra: true,
          ),
        ),
        GalleryPreviewCard(
          title: 'Estado de Carregamento (Loading)',
          description: 'Feedback visual integrado com TFLoading e mensagem descritiva',
          child: TFDataTable<_CargoMock>(
            columns: _buildColumns(context),
            items: const [],
            isLoading: true,
            loadingMessage: 'Sincronizando tabela com banco central...',
          ),
        ),
        GalleryPreviewCard(
          title: 'Estado Vazio (Empty State)',
          description: 'Apresentação padronizada quando a busca ou filtro não retornam registros',
          child: TFDataTable<_CargoMock>(
            columns: _buildColumns(context),
            items: const [],
          ),
        ),
      ],
    );
  }
}
