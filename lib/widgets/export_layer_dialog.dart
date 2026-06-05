import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/design_system.dart';
import '../utils/kml_exporter.dart';
import '../utils/shapefile_exporter.dart';
import '../utils/zip_writer.dart';

class ExportLayerDialog extends StatefulWidget {
  final String layerName;
  final List<Map<String, dynamic>> objects;

  const ExportLayerDialog({
    super.key,
    required this.layerName,
    required this.objects,
  });

  static void show(
    BuildContext context, {
    required String layerName,
    required List<Map<String, dynamic>> objects,
  }) {
    showDialog(
      context: context,
      builder: (context) => ExportLayerDialog(
        layerName: layerName,
        objects: objects,
      ),
    );
  }

  @override
  State<ExportLayerDialog> createState() => _ExportLayerDialogState();
}

class _ExportLayerDialogState extends State<ExportLayerDialog> {
  String _selectedFormat = 'kml'; // 'kml' or 'shp'
  String _selectedDestination = 'save'; // 'save' or 'share'
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final bool hasObjects = widget.objects.isNotEmpty;

    return AlertDialog(
      backgroundColor: DesignSystem.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        side: const BorderSide(color: Colors.white10),
      ),
      title: Row(
        children: [
          const Icon(Icons.ios_share_outlined, color: DesignSystem.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Exportar Capa',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ) ??
                  const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
      content: _isExporting
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 20),
                CircularProgressIndicator(color: DesignSystem.primary),
                SizedBox(height: 20),
                Text(
                  'Generando y preparando archivos...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 20),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capa: ${widget.layerName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contiene: ${widget.objects.length} objetos geográficos',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (!hasObjects) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DesignSystem.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                      border: Border.all(color: DesignSystem.error.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: DesignSystem.error),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Esta capa no contiene objetos para exportar. Agrega puntos, líneas o polígonos primero.',
                            style: TextStyle(color: DesignSystem.error, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const Text(
                    'FORMATO DE EXPORTACIÓN',
                    style: DesignSystem.labelCaps,
                  ),
                  const SizedBox(height: 8),
                  _buildFormatOption('kml', 'KML (.kml)', 'Ideal para Google Earth y visores rápidos.'),
                  const SizedBox(height: 8),
                  _buildFormatOption('shp', 'Shapefile (.zip)', 'Formato estándar GIS (incluye shp, shx, dbf, prj).'),
                  const SizedBox(height: 20),
                  const Text(
                    'DESTINO',
                    style: DesignSystem.labelCaps,
                  ),
                  const SizedBox(height: 8),
                  _buildDestinationOption('save', 'Guardar en dispositivo', Icons.save_alt_outlined),
                  const SizedBox(height: 8),
                  _buildDestinationOption('share', 'Compartir / Enviar', Icons.share_outlined),
                ],
              ],
            ),
      actions: _isExporting
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasObjects ? DesignSystem.primary : Colors.white10,
                  foregroundColor: hasObjects ? Colors.black : Colors.white24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: hasObjects ? _handleExport : null,
                child: const Text(
                  'EXPORTAR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
    );
  }

  Widget _buildFormatOption(String value, String title, String subtitle) {
    final bool isSelected = _selectedFormat == value;
    return InkWell(
      onTap: () => setState(() => _selectedFormat = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignSystem.primary.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
          border: Border.all(
            color: isSelected ? DesignSystem.primary : Colors.white10,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? DesignSystem.primary : Colors.white30,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? DesignSystem.primary : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationOption(String value, String title, IconData icon) {
    final bool isSelected = _selectedDestination == value;
    return InkWell(
      onTap: () => setState(() => _selectedDestination = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignSystem.primary.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
          border: Border.all(
            color: isSelected ? DesignSystem.primary : Colors.white10,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? DesignSystem.primary : Colors.white30,
              size: 20,
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              color: isSelected ? DesignSystem.primary : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? DesignSystem.primary : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final String cleanName = widget.layerName.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
      final bool isKml = _selectedFormat == 'kml';

      Uint8List fileBytes;
      String fileName;
      String mimeType;

      if (isKml) {
        final kmlContent = KmlExporter.generate(widget.layerName, widget.objects);
        fileBytes = Uint8List.fromList(utf8.encode(kmlContent));
        fileName = '$cleanName.kml';
        mimeType = 'application/vnd.google-earth.kml+xml';
      } else {
        final zipEntries = ShapefileExporter.generateShapefileFiles(
          widget.layerName,
          widget.objects,
        );
        if (zipEntries.isEmpty) {
          throw Exception('No se pudieron generar los archivos de Shapefile.');
        }
        fileBytes = ZipWriter.createZip(zipEntries);
        fileName = '${cleanName}_shapefile.zip';
        mimeType = 'application/zip';
      }

      if (_selectedDestination == 'save') {
        // Save locally using file_picker
        final String? savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar Capa',
          fileName: fileName,
          bytes: fileBytes,
        );

        if (mounted) {
          Navigator.pop(context);
          if (savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Capa guardada correctamente como $fileName'),
                backgroundColor: const Color(0xFF388E3C),
              ),
            );
          }
        }
      } else {
        // Share via share_plus
        final XFile xFile = XFile.fromData(
          fileBytes,
          name: fileName,
          mimeType: mimeType,
        );

        await Share.shareXFiles(
          [xFile],
          text: 'Capa ${widget.layerName} exportada desde NaviMap',
        );

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: DesignSystem.surface,
            title: const Text('Error de Exportación', style: TextStyle(color: DesignSystem.error)),
            content: Text(
              'Ocurrió un error al procesar el archivo:\n$e',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ENTENDIDO', style: TextStyle(color: DesignSystem.primary)),
              ),
            ],
          ),
        );
      }
    }
  }
}
