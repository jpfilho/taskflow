import 'package:flutter/material.dart';
import '../features/demandas/presentation/screens/demandas_screen.dart';

class DemandasView extends StatefulWidget {
  const DemandasView({super.key});

  @override
  State<DemandasView> createState() => _DemandasViewState();
}

class _DemandasViewState extends State<DemandasView> {
  @override
  Widget build(BuildContext context) {
    return const DemandasScreen();
  }
}
