import 'package:flutter/material.dart';
import 'regional_list_view.dart';
import 'status_list_view.dart';
import 'divisao_list_view.dart';
import 'segmento_list_view.dart';
import 'local_list_view.dart';
import 'executor_list_view.dart';
import 'empresa_list_view.dart';
import 'funcao_list_view.dart';
import 'tipo_atividade_list_view.dart';
import 'equipe_list_view.dart';
import 'feriado_list_view.dart';
import 'frota_list_view.dart';
import 'centro_trabalho_list_view.dart';
import 'regra_prazo_nota_list_view.dart';
import 'estruturas_view.dart';
import 'kmz_view.dart';
import '../utils/responsive.dart';
import '../providers/theme_provider.dart';
import '../services/theme_service.dart';
import 'color_picker_dialog.dart';

class ConfiguracaoView extends StatefulWidget {
  final ThemeProvider? themeProvider;
  
  const ConfiguracaoView({super.key, this.themeProvider});

  @override
  State<ConfiguracaoView> createState() => _ConfiguracaoViewState();
}

class _ConfiguracaoViewState extends State<ConfiguracaoView> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = widget.themeProvider;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isDesktop = Responsive.isDesktop(context);
    
    // Calcular quantas colunas baseado no tamanho da tela
    int crossAxisCount = 1;
    if (isDesktop) {
      crossAxisCount = 4; // 4 colunas no desktop
    } else if (isTablet) {
      crossAxisCount = 3; // 3 colunas no tablet
    } else {
      crossAxisCount = 2; // 2 colunas no mobile
    }

    // Lista de todos os cadastros
    final cadastros = [
      {
        'icon': Icons.location_city,
        'title': 'Regionais',
        'subtitle': 'Cadastro de regionais, divisões e empresas',
        'color': Colors.blue,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RegionalListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.label,
        'title': 'Status',
        'subtitle': 'Cadastro de status com código e cor',
        'color': Colors.green,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StatusListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.business,
        'title': 'Divisões',
        'subtitle': 'Cadastro de divisões com regional e segmento',
        'color': Colors.orange,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DivisaoListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.category,
        'title': 'Segmentos',
        'subtitle': 'Cadastro de segmentos',
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SegmentoListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.place,
        'title': 'Locais',
        'subtitle': 'Cadastro de locais com associações flexíveis',
        'color': Colors.teal,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LocalListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.people,
        'title': 'Executores',
        'subtitle': 'Cadastro de executores por divisão/segmento',
        'color': Colors.indigo,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ExecutorListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.business_center,
        'title': 'Empresas',
        'subtitle': 'Cadastro de empresas vinculadas a regional e divisão',
        'color': Colors.brown,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmpresaListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.work,
        'title': 'Funções',
        'subtitle': 'Cadastro de funções/cargos',
        'color': Colors.deepPurple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FuncaoListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.category,
        'title': 'Tipos de Atividade',
        'subtitle': 'Cadastro de tipos de atividade por segmentos',
        'color': Colors.teal,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TipoAtividadeListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.groups,
        'title': 'Equipes',
        'subtitle': 'Cadastro de equipes fixas ou flexíveis com executores',
        'color': Colors.cyan,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EquipeListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.event,
        'title': 'Feriados',
        'subtitle': 'Cadastro de feriados nacionais, estaduais e municipais',
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FeriadoListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.directions_car,
        'title': 'Frota',
        'subtitle': 'Cadastro de veículos: carros, muncks, tratores, etc.',
        'color': Colors.blueGrey,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FrotaListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.work,
        'title': 'Centros de Trabalho',
        'subtitle': 'Cadastro de centros de trabalho vinculados a regional, divisão e segmento',
        'color': Colors.amber,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CentroTrabalhoListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.schedule,
        'title': 'Regras de Prazo',
        'subtitle': 'Cadastro de regras de prazo para notas SAP por prioridade e segmento',
        'color': Colors.deepOrange,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RegraPrazoNotaListView(),
            ),
          );
        },
      },
      {
        'icon': Icons.account_tree,
        'title': 'Estruturas',
        'subtitle': 'Cadastro e importação de estruturas (XLSX)',
        'color': Colors.blueGrey,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EstruturasView(),
            ),
          );
        },
      },
      {
        'icon': Icons.map,
        'title': 'KMZ / KML',
        'subtitle': 'Importe o arquivo e visualize o mapa moderno',
        'color': Colors.lightBlue,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KmzView(),
            ),
          );
        },
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        children: [
          // Card de seleção de tema
          if (themeProvider != null) _buildThemeSelector(context, isMobile, themeProvider),
          SizedBox(height: isMobile ? 16 : 20),
          // Card de cores personalizadas
          if (themeProvider != null) _buildCustomColorsSelector(context, isMobile, themeProvider),
          SizedBox(height: isMobile ? 16 : 20),
          // Título da seção de cadastros
          Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
            child: Text(
              'Cadastros',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          // Grid de cadastros (responsivo)
          LayoutBuilder(
            builder: (context, constraints) {
              // Calcular aspect ratio dinâmico baseado na largura disponível
              double aspectRatio;
              if (isMobile) {
                aspectRatio = 2.8; // Cards mais compactos no mobile
              } else if (isTablet) {
                aspectRatio = 2.0; // Cards médios no tablet
              } else {
                aspectRatio = 1.8; // Cards mais compactos no desktop
              }
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                crossAxisSpacing: isMobile ? 8 : 12,
                mainAxisSpacing: isMobile ? 8 : 12,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: cadastros.length,
                itemBuilder: (context, index) {
                  final cadastro = cadastros[index];
                  return _buildCadastroCard(
                    context,
                    icon: cadastro['icon'] as IconData,
                    title: cadastro['title'] as String,
                    subtitle: cadastro['subtitle'] as String,
                    color: cadastro['color'] as Color,
                    onTap: cadastro['onTap'] as VoidCallback,
                    isMobile: isMobile,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, bool isMobile, ThemeProvider themeProvider) {

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(
          Icons.palette,
          color: Theme.of(context).colorScheme.primary,
          size: isMobile ? 20 : 24,
        ),
        title: Text(
          'Tema do Aplicativo',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: ListenableBuilder(
              listenable: themeProvider,
              builder: (context, child) {
                return Column(
                  children: AppTheme.values.map((theme) {
                    final isSelected = themeProvider.currentTheme == theme;
                    final themeName = themeProvider.getThemeName(theme);
                    
                    // Obter cor de destaque para cada tema
                    Color themeColor;
                    IconData themeIcon;
                    switch (theme) {
                      case AppTheme.light:
                        themeColor = Colors.blue;
                        themeIcon = Icons.light_mode;
                        break;
                      case AppTheme.dark:
                        themeColor = Colors.grey[800]!;
                        themeIcon = Icons.dark_mode;
                        break;
                      case AppTheme.axia:
                        themeColor = ThemeService.axiaBlue;
                        themeIcon = Icons.color_lens;
                        break;
                    }
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected 
                              ? themeColor 
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected 
                            ? themeColor.withOpacity(0.1) 
                            : Colors.transparent,
                      ),
                      child: ListTile(
                        leading: Icon(
                          themeIcon,
                          color: isSelected ? themeColor : Colors.grey[600],
                        ),
                        title: Text(
                          themeName,
                          style: TextStyle(
                            fontWeight: isSelected 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: isSelected 
                                ? themeColor 
                                : Colors.grey[800],
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: themeColor,
                              )
                            : const Icon(
                                Icons.radio_button_unchecked,
                                color: Colors.grey,
                              ),
                        onTap: () {
                          themeProvider.setTheme(theme);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomColorsSelector(BuildContext context, bool isMobile, ThemeProvider themeProvider) {

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(
          Icons.color_lens,
          color: Theme.of(context).colorScheme.primary,
          size: isMobile ? 20 : 24,
        ),
        title: Text(
          'Cores Personalizadas',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AppBar/HeaderBar
                _buildColorSelector(
                  context,
                  'AppBar / HeaderBar',
                  'appbar',
                  isMobile,
                ),
                SizedBox(height: isMobile ? 12 : 16),
                // Sidebar
                _buildColorSelector(
                  context,
                  'Sidebar',
                  'sidebar',
                  isMobile,
                ),
                SizedBox(height: isMobile ? 12 : 16),
                // Footbar
                _buildColorSelector(
                  context,
                  'Footbar',
                  'footbar',
                  isMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(
    BuildContext context,
    String title,
    String barType,
    bool isMobile,
  ) {
    return FutureBuilder<Map<String, Color?>>(
      future: Future.wait([
        ThemeService.loadCustomColor('${barType}_background_color'),
        ThemeService.loadCustomColor('${barType}_text_color'),
        ThemeService.loadCustomColor('${barType}_icon_color'),
      ]).then((colors) => {
        'background': colors[0],
        'text': colors[1],
        'icon': colors[2],
      }),
      builder: (context, snapshot) {
        final currentTheme = widget.themeProvider?.currentTheme ?? AppTheme.light;
        final defaultBackground = ThemeService.getBarBackgroundColorSync(currentTheme);
        final defaultText = ThemeService.getBarTextColorSync(currentTheme);
        final defaultIcon = ThemeService.getBarIconColorSync(currentTheme);

        final backgroundColor = snapshot.data?['background'] ?? defaultBackground;
        final textColor = snapshot.data?['text'] ?? defaultText;
        final iconColor = snapshot.data?['icon'] ?? defaultIcon;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            Row(
              children: [
                Expanded(
                  child: _buildColorButton(
                    context,
                    'Fundo',
                    backgroundColor,
                    () async {
                      final color = await showDialog<Color>(
                        context: context,
                        builder: (context) => ColorPickerDialog(
                          initialColor: backgroundColor,
                          title: 'Cor de Fundo - $title',
                        ),
                      );
                      if (color != null) {
                        await ThemeService.saveCustomColor(
                          '${barType}_background_color',
                          color,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cor de fundo salva!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          setState(() {});
                        }
                      }
                    },
                    isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: _buildColorButton(
                    context,
                    'Texto',
                    textColor,
                    () async {
                      final color = await showDialog<Color>(
                        context: context,
                        builder: (context) => ColorPickerDialog(
                          initialColor: textColor,
                          title: 'Cor de Texto - $title',
                        ),
                      );
                      if (color != null) {
                        await ThemeService.saveCustomColor(
                          '${barType}_text_color',
                          color,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cor de texto salva!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          setState(() {});
                        }
                      }
                    },
                    isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: _buildColorButton(
                    context,
                    'Ícone',
                    iconColor,
                    () async {
                      final color = await showDialog<Color>(
                        context: context,
                        builder: (context) => ColorPickerDialog(
                          initialColor: iconColor,
                          title: 'Cor de Ícone - $title',
                        ),
                      );
                      if (color != null) {
                        await ThemeService.saveCustomColor(
                          '${barType}_icon_color',
                          color,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cor de ícone salva!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          setState(() {});
                        }
                      }
                    },
                    isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                IconButton(
                  icon: const Icon(Icons.restore, size: 18),
                  tooltip: 'Restaurar padrão',
                  onPressed: () async {
                    await ThemeService.removeCustomColor('${barType}_background_color');
                    await ThemeService.removeCustomColor('${barType}_text_color');
                    await ThemeService.removeCustomColor('${barType}_icon_color');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cores restauradas para o padrão!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      // Forçar rebuild
                      (context as Element).markNeedsBuild();
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorButton(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap,
    bool isMobile,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _getContrastColor(color),
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isMobile ? 4 : 6),
            Text(
              '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(
                color: _getContrastColor(color),
                fontSize: isMobile ? 9 : 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildCadastroCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
          child: Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          child: Row(
            children: [
              Container(
                width: isMobile ? 40 : 44,
                height: isMobile ? 40 : 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isMobile ? 20 : 22,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isMobile ? 2 : 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: isMobile ? 4 : 6),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: isMobile ? 18 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

