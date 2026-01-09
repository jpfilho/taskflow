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
import '../utils/responsive.dart';
import '../providers/theme_provider.dart';
import '../services/theme_service.dart';

class ConfiguracaoView extends StatelessWidget {
  final ThemeProvider? themeProvider;
  
  const ConfiguracaoView({super.key, this.themeProvider});

  @override
  Widget build(BuildContext context) {
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
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        children: [
          // Card de seleção de tema
          if (themeProvider != null) _buildThemeSelector(context, isMobile),
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

  Widget _buildThemeSelector(BuildContext context, bool isMobile) {
    if (themeProvider == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Text(
                  'Tema do Aplicativo',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            ListenableBuilder(
              listenable: themeProvider!,
              builder: (context, child) {
                return Column(
                  children: AppTheme.values.map((theme) {
                    final isSelected = themeProvider!.currentTheme == theme;
                    final themeName = themeProvider!.getThemeName(theme);
                    
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
                          themeProvider!.setTheme(theme);
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
          ],
        ),
      ),
    );
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

