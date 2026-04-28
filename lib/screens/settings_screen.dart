import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AJUSTES DEL SISTEMA', style: DesignSystem.labelCaps),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSettingsHeader('PREFERENCIAS DE MAPA'),
          ListTile(
            title: const Text('Unidades de Medida'),
            subtitle: const Text('Métrico (m, km)'),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Formato de Coordenadas'),
            subtitle: const Text('Decimal (DD.DDDDDD)'),
            onTap: () {},
          ),
          const Divider(color: DesignSystem.outline),
          _buildSettingsHeader('SISTEMA'),
          ListTile(
            title: const Text('Modo de Ahorro de Energía'),
            trailing: Switch(
              value: true, 
            activeTrackColor: DesignSystem.primary,
              onChanged: (v) {},
            ),
          ),
          ListTile(
            title: const Text('Descargar Mapas para Uso Offline'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: DesignSystem.labelCaps.copyWith(color: DesignSystem.primary, fontSize: 10),
      ),
    );
  }
}
