import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;

class AddMapOverlay extends StatelessWidget {
  final Function(String name) onMapProcessingStarted;
  final Function(String name, Uint8List? thumbnail, Uint8List? fullBytes)
  onMapAdded;

  const AddMapOverlay({
    super.key,
    required this.onMapProcessingStarted,
    required this.onMapAdded,
  });

  static void show(
    BuildContext context, {
    required Function(String name) onMapProcessingStarted,
    required Function(String name, Uint8List? thumbnail, Uint8List? fullBytes)
    onMapAdded,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignSystem.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignSystem.radiusLg),
        ),
      ),
      builder: (context) => AddMapOverlay(
        onMapProcessingStarted: onMapProcessingStarted,
        onMapAdded: onMapAdded,
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          side: const BorderSide(color: DesignSystem.outline, width: 0.5),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ACEPTAR', style: TextStyle(color: DesignSystem.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignSystem.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOption(
            context,
            Icons.picture_as_pdf,
            'IMPORTAR GEOPDF',
            () async {
              try {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                  withData: true,
                );

                if (result != null) {
                  Uint8List? rawBytes;
                  try {
                    if (kIsWeb) {
                      rawBytes = result.files.single.bytes;
                    } else {
                      final path = result.files.single.path;
                      if (path != null) {
                        rawBytes = await io.File(path).readAsBytes();
                      }
                    }
                  } catch (e) {
                    debugPrint('Error al leer bytes del PDF: $e');
                    if (context.mounted) {
                      _showErrorDialog(
                        context,
                        'Error de Lectura',
                        'No se pudo leer el archivo. Si el archivo está en Google Drive, OneDrive u otra nube, descárguelo a su dispositivo primero.\n\nDetalle: $e',
                      );
                    }
                    return;
                  }

                  if (rawBytes == null || rawBytes.isEmpty) {
                    if (context.mounted) {
                      _showErrorDialog(
                        context,
                        'Archivo Vacío',
                        'El archivo seleccionado no contiene datos válidos.',
                      );
                    }
                    return;
                  }

                  String fileName = result.files.single.name;

                  // Notificar que empezamos el procesamiento pesado
                  onMapProcessingStarted(fileName);

                  final Uint8List bytesForThumbnail = Uint8List.fromList(
                    rawBytes,
                  );
                  final Uint8List bytesForLibrary = Uint8List.fromList(rawBytes);

                  Uint8List? thumbnail;

                  try {
                    // Simular un pequeño retardo si el archivo es muy ligero para que se vea la barra
                    await Future.delayed(const Duration(milliseconds: 800));

                    final document = await PdfDocument.openData(
                      bytesForThumbnail,
                    );
                    final page = await document.getPage(1);
                    final pageImage = await page.render(
                      width: 200,
                      height: 200,
                      format: PdfPageImageFormat.png,
                    );
                    thumbnail = pageImage?.bytes;
                    await page.close();
                    await document.close();
                  } catch (e) {
                    debugPrint('Error generando miniatura: $e');
                  }

                  onMapAdded(fileName, thumbnail, bytesForLibrary);
                }
              } catch (e) {
                debugPrint('Error general al importar PDF: $e');
                if (context.mounted) {
                  _showErrorDialog(
                    context,
                    'Error al Importar',
                    'Ocurrió un error inesperado al procesar el archivo.\n\nDetalle: $e',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: DesignSystem.bodyMd),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
