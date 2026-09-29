import 'package:flutter/material.dart';
import '../../components/buttons/tf_button.dart';
import '../../components/buttons/tf_icon_button.dart';
import '../../components/layout/tf_page_header.dart';
import '../../foundations/tf_icons.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class PageHeaderSection extends StatelessWidget {
  const PageHeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'TFPageHeader — Cabeçalhos de Página',
      description: 'Padronização do topo de visões com suporte a título, subtítulo operacional, breadcrumbs e ações primárias/secundárias.',
      children: [
        GalleryPreviewCard(
          title: 'Cabeçalho Completo com Ações',
          description: 'Layout automático em linha (Desktop/Tablet) e empilhado (Mobile)',
          child: TFPageHeader(
            title: 'Ordens de Manutenção SAP',
            subtitle: 'Visão consolidada da regional Piauí / Maranhão',
            breadcrumb: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Início', style: TextStyle(fontSize: 11)),
                Text(' / ', style: TextStyle(fontSize: 11)),
                Text('SAP PM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            primaryAction: TFButton(
              label: 'Nova Ordem',
              leadingIcon: TFIcons.add,
              onPressed: () {},
            ),
            secondaryActions: [
              TFIconButton(
                icon: TFIcons.filter,
                tooltip: 'Filtrar',
                onPressed: () {},
              ),
              TFIconButton(
                icon: TFIcons.refresh,
                tooltip: 'Atualizar',
                onPressed: () {},
              ),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Cabeçalho Simples (Apenas Título e Subtítulo)',
          description: 'Ideal para painéis secundários e detalhes de registro',
          child: Column(
            children: [
              const TFPageHeader(
                title: 'Histórico de Atividades da Equipe',
                subtitle: 'Registros dos últimos 30 dias sincronizados',
              ),
              SizedBox(height: spacing.sm),
            ],
          ),
        ),
      ],
    );
  }
}
