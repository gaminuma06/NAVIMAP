import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class LayerManagerScreen extends StatelessWidget {
  const LayerManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTOR DE CAPAS', style: DesignSystem.labelCaps),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignSystem.spacingMd),
        children: [
          _buildLayerItem('Curvas de Nivel', true),
          _buildLayerItem('Drenajes Sencillos', true),
          _buildLayerItem('Vías Principales', false),
          _buildLayerItem('Linderos Propiedad', true),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // This is a bit ambiguous in the spec, but we'll use 0 for layers
        backgroundColor: DesignSystem.surface,
        selectedItemColor: DesignSystem.primary,
        unselectedItemColor: Colors.white24,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'MAPAS'),
          BottomNavigationBarItem(icon: Icon(Icons.satellite_alt), label: 'SATÉLITE'),
        ],
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/');
          if (index == 1) Navigator.pushReplacementNamed(context, '/satellite');
        },
      ),
    );
  }

  Widget _buildLayerItem(String name, bool isVisible) {
    return ListTile(
      leading: Icon(
        isVisible ? Icons.visibility : Icons.visibility_off,
        color: isVisible ? DesignSystem.primary : Colors.white24,
      ),
      title: Text(name, style: DesignSystem.bodyMd),
      trailing: const Icon(Icons.drag_indicator, color: Colors.white24),
    );
  }
}
