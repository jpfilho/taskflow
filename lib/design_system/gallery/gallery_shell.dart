import 'package:flutter/material.dart';
import '../foundations/tf_breakpoints.dart';
import '../foundations/tf_density.dart';
import '../foundations/tf_icons.dart';
import '../foundations/tf_radius.dart';
import '../../providers/theme_provider.dart';
import '../../services/theme_service.dart';
import '../theme/taskflow_theme_extension.dart';
import 'gallery_navigation.dart';
import 'sections/buttons_section.dart';
import 'sections/cards_section.dart';
import 'sections/colors_section.dart';
import 'sections/density_validation_section.dart';
import 'sections/elevation_section.dart';
import 'sections/feedback_section.dart';
import 'sections/icon_buttons_section.dart';
import 'sections/icons_section.dart';
import 'sections/inputs_section.dart';
import 'sections/overview_section.dart';
import 'sections/page_header_section.dart';
import 'sections/radius_section.dart';
import 'sections/responsive_section.dart';
import 'sections/spacing_section.dart';
import 'sections/status_section.dart';
import 'sections/sync_section.dart';
import 'sections/typography_section.dart';
import 'sections/tables_section.dart';
import 'sections/dialogs_section.dart';
import 'sections/switches_section.dart';

/// Shell visual da Design System Gallery.
///
/// Fornece controles de alternância de Tema em tempo real (via ThemeProvider)
/// e de Densidade visual (Comfortable, Compact, Dense), além de navegação lateral responsiva.
class GalleryShell extends StatefulWidget {
  final ThemeProvider? themeProvider;

  const GalleryShell({
    super.key,
    this.themeProvider,
  });

  @override
  State<GalleryShell> createState() => _GalleryShellState();
}

class _GalleryShellState extends State<GalleryShell> {
  String _selectedSectionId = 'overview';
  TFDensityMode _activeDensityMode = TFDensityMode.compact;

  final List<GalleryNavItem> _navItems = const [
    // Overview
    GalleryNavItem(id: 'overview', title: 'Visão Geral', icon: TFIcons.ai, group: 'Geral'),

    // Foundations
    GalleryNavItem(id: 'colors', title: 'Cores & Tokens', icon: Icons.palette_outlined, group: 'Foundations'),
    GalleryNavItem(id: 'typography', title: 'Tipografia', icon: Icons.text_fields_rounded, group: 'Foundations'),
    GalleryNavItem(id: 'spacing', title: 'Espaçamentos', icon: Icons.space_bar_rounded, group: 'Foundations'),
    GalleryNavItem(id: 'radius', title: 'Raios de Curvatura', icon: Icons.rounded_corner_rounded, group: 'Foundations'),
    GalleryNavItem(id: 'elevation', title: 'Elevação & Sombras', icon: Icons.layers_outlined, group: 'Foundations'),
    GalleryNavItem(id: 'icons', title: 'Ícones Semânticos', icon: Icons.sentiment_satisfied_alt_rounded, group: 'Foundations'),

    // Components
    GalleryNavItem(id: 'buttons', title: 'Botões (TFButton)', icon: Icons.smart_button_outlined, group: 'Componentes'),
    GalleryNavItem(id: 'icon_buttons', title: 'Botões de Ícone', icon: Icons.touch_app_outlined, group: 'Componentes'),
    GalleryNavItem(id: 'inputs', title: 'Entradas de Texto', icon: Icons.edit_note_rounded, group: 'Componentes'),
    GalleryNavItem(id: 'switches', title: 'Switches & Booleanos', icon: Icons.toggle_on_outlined, group: 'Componentes'),
    GalleryNavItem(id: 'status', title: 'Status & Severidade', icon: Icons.verified_outlined, group: 'Componentes'),
    GalleryNavItem(id: 'cards', title: 'Cards & Superfícies', icon: Icons.crop_portrait_rounded, group: 'Componentes'),
    GalleryNavItem(id: 'tables', title: 'Tabelas (TFDataTable)', icon: Icons.table_chart_outlined, group: 'Componentes'),
    GalleryNavItem(id: 'dialogs', title: 'Modais (TFModalDialog)', icon: Icons.picture_in_picture_alt_rounded, group: 'Componentes'),
    GalleryNavItem(id: 'page_header', title: 'Page Header', icon: Icons.web_asset_rounded, group: 'Componentes'),
    GalleryNavItem(id: 'feedback', title: 'Empty State & Loading', icon: Icons.hourglass_empty_rounded, group: 'Componentes'),
    GalleryNavItem(id: 'sync', title: 'Indicador de Sync', icon: Icons.sync_rounded, group: 'Componentes'),

    // Validation
    GalleryNavItem(id: 'responsive', title: 'Responsividade', icon: Icons.devices_rounded, group: 'Validação'),
    GalleryNavItem(id: 'density_val', title: 'Comparativo de Densidade', icon: Icons.density_medium_rounded, group: 'Validação'),
  ];

  Widget _buildActiveSection() {
    return switch (_selectedSectionId) {
      'overview' => const OverviewSection(),
      'colors' => const ColorsSection(),
      'typography' => const TypographySection(),
      'spacing' => const SpacingSection(),
      'radius' => const RadiusSection(),
      'elevation' => const ElevationSection(),
      'icons' => const IconsSection(),
      'buttons' => const ButtonsSection(),
      'icon_buttons' => const IconButtonsSection(),
      'inputs' => const InputsSection(),
      'switches' => const SwitchesSection(),
      'status' => const StatusSection(),
      'cards' => const CardsSection(),
      'tables' => const TablesSection(),
      'dialogs' => const DialogsSection(),
      'page_header' => const PageHeaderSection(),
      'feedback' => const FeedbackSection(),
      'sync' => const SyncSection(),
      'responsive' => const ResponsiveSection(),
      'density_val' => const DensityValidationSection(),
      _ => const OverviewSection(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final isMobile = TFBreakpoints.isMobile(context);

    // Resolver tema com override de densidade selecionado na Gallery
    final currentTheme = Theme.of(context);
    final ext = currentTheme.extension<TaskFlowThemeExtension>();

    ThemeData themedContextData = currentTheme;
    if (ext != null) {
      final targetDensity = switch (_activeDensityMode) {
        TFDensityMode.comfortable => TFDensity.comfortable(),
        TFDensityMode.compact => TFDensity.compact(),
        TFDensityMode.dense => TFDensity.dense(),
      };
      themedContextData = currentTheme.copyWith(
        extensions: [ext.copyWith(density: targetDensity)],
      );
    }

    final currentAppTheme = widget.themeProvider?.currentTheme ?? AppTheme.light;

    Widget bodyContent = Theme(
      data: themedContextData,
      child: Builder(
        builder: (innerContext) {
          return Scaffold(
            backgroundColor: innerContext.tfColors.background,
            appBar: AppBar(
              backgroundColor: innerContext.tfColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: innerContext.tfColors.textPrimary),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(spacing.xs),
                    decoration: BoxDecoration(
                      color: innerContext.tfColors.primary.withValues(alpha: 0.1),
                      borderRadius: TFRadius.borderRadiusSm,
                    ),
                    child: Icon(TFIcons.ai, size: 20, color: innerContext.tfColors.primary),
                  ),
                  SizedBox(width: spacing.sm),
                  Text(
                    'TF Design System',
                    style: typography.sectionTitle.copyWith(color: innerContext.tfColors.textPrimary),
                  ),
                ],
              ),
              actions: [
                // Seletor de Tema Real do App
                if (widget.themeProvider != null) ...[
                  SegmentedButton<AppTheme>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: AppTheme.light, label: Text('Light', style: TextStyle(fontSize: 10))),
                      ButtonSegment(value: AppTheme.dark, label: Text('Dark', style: TextStyle(fontSize: 10))),
                      ButtonSegment(value: AppTheme.axia, label: Text('AXIA', style: TextStyle(fontSize: 10))),
                    ],
                    selected: {currentAppTheme},
                    onSelectionChanged: (selection) {
                      widget.themeProvider!.setTheme(selection.first);
                    },
                  ),
                  SizedBox(width: spacing.xs),
                ],
                // Seletor de Densidade
                SegmentedButton<TFDensityMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: TFDensityMode.comfortable, label: Text('Comfort', style: TextStyle(fontSize: 10))),
                    ButtonSegment(value: TFDensityMode.compact, label: Text('Compact', style: TextStyle(fontSize: 10))),
                    ButtonSegment(value: TFDensityMode.dense, label: Text('Dense', style: TextStyle(fontSize: 10))),
                  ],
                  selected: {_activeDensityMode},
                  onSelectionChanged: (selection) {
                    setState(() => _activeDensityMode = selection.first);
                  },
                ),
                SizedBox(width: spacing.sm),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(color: innerContext.tfColors.borderSubtle, height: 1.0),
              ),
            ),
            drawer: isMobile
                ? GalleryNavigation(
                    items: _navItems,
                    selectedId: _selectedSectionId,
                    onSelect: (id) => setState(() => _selectedSectionId = id),
                    isDrawer: true,
                  )
                : null,
            body: Row(
              children: [
                if (!isMobile)
                  GalleryNavigation(
                    items: _navItems,
                    selectedId: _selectedSectionId,
                    onSelect: (id) => setState(() => _selectedSectionId = id),
                  ),
                Expanded(
                  child: _buildActiveSection(),
                ),
              ],
            ),
          );
        },
      ),
    );

    return bodyContent;
  }
}
