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
import '../features/media_albums/presentation/pages/status_album_list_view.dart';
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
      crossAxisCount = 4; // 4 colunas no desktop (xl)
    } else if (isTablet) {
      crossAxisCount = 2; // 2 colunas no tablet (md)
    } else {
      crossAxisCount = 1; // 1 coluna no mobile
    }

    // Lista de cadastros agrupados por tópicos
    final topicos = [
      {
        'nome': 'Básicos',
        'icon': Icons.apps,
        'color': Colors.blue,
        'cadastros': [
          {
            'icon': Icons.corporate_fare,
            'title': 'Regionais',
            'subtitle': 'Cadastro de regionais, divisões e empresas do grupo.',
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
            'icon': Icons.domain,
            'title': 'Divisões',
            'subtitle': 'Gerenciamento de unidades de negócio e segmentos.',
            'color': Colors.amber[700]!,
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
            'icon': Icons.place,
            'title': 'Locais',
            'subtitle': 'Cadastro de pontos físicos com associações flexíveis.',
            'color': Colors.green[600]!,
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
            'icon': Icons.engineering,
            'title': 'Executores',
            'subtitle': 'Gerencie as equipes executoras por região e função.',
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
            'subtitle': 'Entidades jurídicas vinculadas a regionais.',
            'color': Colors.pink[600]!,
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
            'icon': Icons.groups,
            'title': 'Equipes',
            'subtitle': 'Organização de times fixos e dinâmicos para atividades.',
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
            'icon': Icons.event_busy,
            'title': 'Feriados',
            'subtitle': 'Calendário nacional, estadual e municipal.',
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
        ],
      },
      {
        'nome': 'Sistema',
        'icon': Icons.settings,
        'color': Colors.grey,
        'cadastros': [
          {
            'icon': Icons.pending_actions,
            'title': 'Status',
            'subtitle': 'Configuração de fluxos e cores de status.',
            'color': Colors.grey[600]!,
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
            'icon': Icons.category,
            'title': 'Segmentos',
            'subtitle': 'Definição de categorias de serviços e atuação.',
            'color': Colors.pink[600]!,
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
            'icon': Icons.badge,
            'title': 'Funções',
            'subtitle': 'Gestão de cargos, permissões e especialidades.',
            'color': Colors.orange[600]!,
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
            'icon': Icons.format_list_bulleted,
            'title': 'Tipos de Atividade',
            'subtitle': 'Padronização de tarefas e checklists por segmento.',
            'color': Colors.lightBlue[600]!,
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
            'icon': Icons.collections_bookmark,
            'title': 'Status de Álbuns',
            'subtitle': 'Cadastro de status para álbuns de imagens com cores customizadas.',
            'color': Colors.purple[600]!,
            'onTap': () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StatusAlbumListView(),
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
        ],
      },
      {
        'nome': 'Linhas de Transmissão',
        'icon': Icons.power,
        'color': Colors.orange,
        'cadastros': [
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
        ],
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: EdgeInsets.all(isMobile ? 24 : 40),
        children: [
          // Cabeçalho
          Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 24 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurações',
                  style: TextStyle(
                    fontSize: isMobile ? 28 : 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Gerencie os parâmetros e regras do sistema para sua organização.',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Card de seleção de tema
          if (themeProvider != null) _buildThemeCard(context, isMobile, themeProvider),
          SizedBox(height: isMobile ? 24 : 32),
          // Card de cores personalizadas (não expansível, estilo simples)
          if (themeProvider != null) _buildCustomColorsCard(context, isMobile, themeProvider),
          SizedBox(height: isMobile ? 32 : 40),
          // Lista de cadastros agrupados por tópicos
          ...topicos.map((topico) {
            final cadastros = topico['cadastros'] as List<Map<String, dynamic>>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título do tópico em maiúsculas
                Padding(
                  padding: EdgeInsets.only(bottom: isMobile ? 20 : 24),
                  child: Row(
                    children: [
                      Icon(
                        (topico['icon'] as IconData) == Icons.apps ? Icons.grid_view : 
                        (topico['icon'] as IconData) == Icons.settings ? Icons.settings_applications : 
                        (topico['icon'] as IconData),
                        color: Theme.of(context).colorScheme.primary,
                        size: isMobile ? 20 : 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        (topico['nome'] as String).toUpperCase(),
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                // Grid de cadastros do tópico (responsivo)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: isMobile ? 16 : 24,
                    mainAxisSpacing: isMobile ? 16 : 24,
                    childAspectRatio: 1.6, // Cards mais baixos e compactos
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
                ),
                SizedBox(height: isMobile ? 32 : 48),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, bool isMobile, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Abrir o dialog de seleção de tema
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tema do Aplicativo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 24),
                      ListenableBuilder(
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
                                margin: EdgeInsets.only(bottom: 12),
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
                                    Navigator.pop(context);
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
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fechar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 48 : 56,
                  height: isMobile ? 48 : 56,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.palette,
                    color: Colors.blue[600],
                    size: isMobile ? 24 : 28,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tema do Aplicativo',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      SizedBox(height: 4),
                      ListenableBuilder(
                        listenable: themeProvider,
                        builder: (context, child) {
                          final themeName = themeProvider.getThemeName(themeProvider.currentTheme);
                          return Text(
                            'Tema atual: $themeName',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomColorsCard(BuildContext context, bool isMobile, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Abrir o dialog de cores personalizadas
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cores Personalizadas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildColorSelector(
                        context,
                        'AppBar / HeaderBar',
                        'appbar',
                        isMobile,
                      ),
                      SizedBox(height: 16),
                      _buildColorSelector(
                        context,
                        'Sidebar',
                        'sidebar',
                        isMobile,
                      ),
                      SizedBox(height: 16),
                      _buildColorSelector(
                        context,
                        'Footbar',
                        'footbar',
                        isMobile,
                      ),
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fechar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 48 : 56,
                  height: isMobile ? 48 : 56,
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.palette,
                    color: Colors.orange[600],
                    size: isMobile ? 24 : 28,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cores Personalizadas',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Personalize a identidade visual do seu painel administrativo',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
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
    return _HoverCard(
      onTap: onTap,
      isMobile: isMobile,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Topo com ícone e seta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isMobile ? 40 : 44,
                  height: isMobile ? 40 : 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isMobile ? 20 : 22,
                  ),
                ),
                _HoverIcon(
                  icon: Icons.arrow_forward,
                  color: Colors.grey[300]!,
                  hoverColor: Theme.of(context).colorScheme.primary,
                  size: isMobile ? 16 : 18,
                ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : 10),
            // Título
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            SizedBox(height: isMobile ? 3 : 4),
            // Descrição
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para card com efeito hover
class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isMobile;

  const _HoverCard({
    required this.child,
    required this.onTap,
    required this.isMobile,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// Widget para ícone com mudança de cor no hover
class _HoverIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final double size;

  const _HoverIcon({
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.size,
  });

  @override
  State<_HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<_HoverIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          widget.icon,
          color: _isHovered ? widget.hoverColor : widget.color,
          size: widget.size,
        ),
      ),
    );
  }
}

