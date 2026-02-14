import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Melhorias e Bugs'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Lista'),
            Tab(icon: Icon(Icons.map), text: 'Roadmap'),
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
