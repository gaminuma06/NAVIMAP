import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class LayerListItem extends StatelessWidget {
  final String title;
  final int objectCount;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onExport;

  const LayerListItem({
    super.key,
    required this.title,
    required this.objectCount,
    required this.onTap,
    this.onDelete,
    this.onRename,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignSystem.spacingMd),
        padding: const EdgeInsets.all(DesignSystem.spacingMd),
        decoration: BoxDecoration(
          color: DesignSystem.surfaceContainer,
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          border: Border.all(color: DesignSystem.outline.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            // Layer Icon Area
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
              ),
              child: const Icon(
                Icons.layers_outlined,
                color: DesignSystem.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: DesignSystem.spacingMd),

            // Content Area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DesignSystem.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$objectCount objetos',
                    style: DesignSystem.bodySm.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),

            // Options Icon with PopupMenu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: DesignSystem.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
              ),
              onSelected: (value) {
                if (value == 'rename') onRename?.call();
                if (value == 'export') onExport?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Renombrar capa',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(
                        Icons.ios_share_outlined,
                        color: DesignSystem.primary,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Exportar capa',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: DesignSystem.error,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Eliminar capa',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
