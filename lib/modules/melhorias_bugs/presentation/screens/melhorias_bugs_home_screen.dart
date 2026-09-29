import 'package:flutter/material.dart';
import '../../../../design_system/taskflow_design_system.dart';
import 'roadmap_board_screen.dart';
import 'melhorias_bugs_list_screen.dart';

/// Tela principal do módulo Melhorias e Bugs: abas Lista e Roadmap.
class MelhoriasBugsHomeScreen extends StatefulWidget {
  const MelhoriasBugsHomeScreen({super.key});

  @override
  State<MelhoriasBugsHomeScreen> createState() => _MelhoriasBugsHomeScreenState();
}

class _MelhoriasBugsHomeScreenState extends State<MelhoriasBugsHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Melhorias e Bugs',
          style: typography.pageTitle.copyWith(color: colors.textPrimary),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.primary,
          indicatorWeight: 3,
          labelStyle: typography.labelMedium.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: typography.labelMedium,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Lista'),
            Tab(icon: Icon(Icons.map_rounded), text: 'Roadmap'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MelhoriasBugsListScreen(),
          RoadmapBoardScreen(),
        ],
      ),
    );
  }
}
