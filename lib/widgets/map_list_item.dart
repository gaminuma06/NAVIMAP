import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import 'dart:typed_data';

enum MapSpatialStatus { within, outside, notReferenced }

class MapListItem extends StatelessWidget {
  final String title;
  final String dateAdded;
  final MapSpatialStatus status;
  final String? thumbnailPath;
  final Uint8List? thumbnailBytes;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const MapListItem({
    super.key,
    required this.title,
    required this.dateAdded,
    required this.status,
    required this.onTap,
    this.onDownload,
    this.onDelete,
    this.thumbnailPath,
    this.thumbnailBytes,
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
            // Thumbnail / Icon Area
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
              ),
              child: _buildThumbnail(),
            ),
            const SizedBox(width: DesignSystem.spacingMd),
            
            // Content Area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DesignSystem.bodyLg.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Agregado el $dateAdded',
                    style: DesignSystem.bodySm.copyWith(color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusLabel(),
                ],
              ),
            ),
            
            // Options Icon with PopupMenu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: DesignSystem.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignSystem.radiusMd)),
              onSelected: (value) {
                if (value == 'download') onDownload?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined, color: DesignSystem.primary, size: 20),
                      SizedBox(width: 12),
                      Text('Descargar mapa', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: DesignSystem.error, size: 20),
                      SizedBox(width: 12),
                      Text('Eliminar mapa', style: TextStyle(color: Colors.white, fontSize: 14)),
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

  Widget _buildThumbnail() {
    if (thumbnailBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
        child: Image.memory(thumbnailBytes!, fit: BoxFit.cover),
      );
    }
    if (thumbnailPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
        child: Image.asset(thumbnailPath!, fit: BoxFit.cover),
      );
    }
    return const Icon(Icons.map, color: Colors.white24, size: 28);
  }

  Widget _buildStatusLabel() {
    IconData icon;
    String text;
    Color color;

    switch (status) {
      case MapSpatialStatus.within:
        icon = Icons.gps_fixed;
        text = 'ESTÁS EN EL MAPA';
        color = DesignSystem.primary;
        break;
      case MapSpatialStatus.outside:
        icon = Icons.gps_not_fixed;
        text = 'FUERA DEL MAPA';
        color = Colors.white24;
        break;
      case MapSpatialStatus.notReferenced:
        icon = Icons.location_off;
        text = 'MAPA NO REFERENCIADO';
        color = DesignSystem.error;
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: DesignSystem.labelCaps.copyWith(
            color: color,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
