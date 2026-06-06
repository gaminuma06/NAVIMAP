import 'package:flutter/material.dart';
import '../theme/design_system.dart';

enum GeoObjectType { point, line, polygon }

class ObjectListItem extends StatelessWidget {
  final String name;
  final GeoObjectType type;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onExport;
  final VoidCallback? onMoveToLayer;
  final Color? color;
  final VoidCallback? onRename;

  const ObjectListItem({
    super.key,
    required this.name,
    required this.type,
    required this.value,
    required this.onTap,
    this.onDelete,
    this.onDuplicate,
    this.onExport,
    this.onMoveToLayer,
    this.color,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignSystem.spacingSm),
        padding: const EdgeInsets.all(DesignSystem.spacingMd),
        decoration: BoxDecoration(
          color: DesignSystem.surfaceContainer,
          borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
          border: Border.all(color: DesignSystem.outline.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Object Icon Area
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
              ),
              child: _buildIcon(),
            ),
            const SizedBox(width: DesignSystem.spacingMd),

            // Content Area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: DesignSystem.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: DesignSystem.bodySm.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),

            // Options Icon with PopupMenu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Colors.white38),
              color: DesignSystem.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    onExport?.call();
                    break;
                  case 'duplicate':
                    onDuplicate?.call();
                    break;
                  case 'rename':
                    onRename?.call();
                    break;
                  case 'move':
                    onMoveToLayer?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(
                        Icons.ios_share,
                        size: 18,
                        color: DesignSystem.primary,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Exportar',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (onDuplicate != null)
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 18, color: Colors.white70),
                        SizedBox(width: 12),
                        Text(
                          'Duplicar',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                if (onRename != null)
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Renombrar',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                if (onMoveToLayer != null)
                  const PopupMenuItem(
                    value: 'move',
                    child: Row(
                      children: [
                        Icon(
                          Icons.drive_file_move_outlined,
                          size: 18,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Mover a otra capa',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                if (onDelete != null) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: DesignSystem.error,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Eliminar',
                          style: TextStyle(
                            color: DesignSystem.error,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color iconColor;

    switch (type) {
      case GeoObjectType.point:
        icon = Icons.location_on;
        iconColor = color ?? Colors.redAccent;
        break;
      case GeoObjectType.line:
        icon = Icons.horizontal_rule;
        iconColor = color ?? Colors.orangeAccent;
        break;
      case GeoObjectType.polygon:
        icon = Icons.pentagon;
        iconColor = color ?? Colors.blueAccent;
        break;
    }

    return Icon(icon, color: iconColor, size: 24);
  }
}
