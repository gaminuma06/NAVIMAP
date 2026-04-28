import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class SidebarMenu extends StatelessWidget {
  const SidebarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DesignSystem.outline)),
            ),
            child: Center(
              child: Text(
                'NAVIMAP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: DesignSystem.primary,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.folder_special,
            label: 'BIBLIOTECA',
            onTap: () => Navigator.pushReplacementNamed(context, '/'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.satellite_alt,
            label: 'VISTA SATÉLITE',
            onTap: () => Navigator.pushReplacementNamed(context, '/satellite'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.settings,
            label: 'AJUSTES',
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(DesignSystem.spacingLg),
            child: Text(
              'v1.0.0 PRO',
              style: DesignSystem.labelCaps.copyWith(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(
        label,
        style: DesignSystem.labelCaps.copyWith(color: Colors.white),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
      ),
    );
  }
}
