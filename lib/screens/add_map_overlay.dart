import 'package:flutter/material.dart';
import '../theme/design_system.dart';

import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';

class AddMapOverlay extends StatelessWidget {
  final Function(String name, Uint8List? thumbnail, Uint8List? fullBytes) onMapAdded;

  const AddMapOverlay({super.key, required this.onMapAdded});

  static void show(BuildContext context, {required Function(String name, Uint8List? thumbnail, Uint8List? fullBytes) onMapAdded}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignSystem.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignSystem.radiusLg)),
      ),
      builder: (context) => AddMapOverlay(onMapAdded: onMapAdded),
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
          _buildOption(context, Icons.picture_as_pdf, 'IMPORTAR GEOPDF', () async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf'],
              withData: true,
            );

              if (result != null && result.files.single.bytes != null) {
                final rawBytes = result.files.single.bytes!;
                if (rawBytes.isEmpty) return;

                // CLONACIÓN PROACTIVA: Creamos copias ANTES de procesar nada
                final Uint8List bytesForThumbnail = Uint8List.fromList(rawBytes);
                final Uint8List bytesForLibrary = Uint8List.fromList(rawBytes);
                
                debugPrint('Iniciando procesamiento con ${bytesForLibrary.length} bytes');
                
                String fileName = result.files.single.name;
                Uint8List? thumbnail;

                try {
                  // La librería consumirá 'bytesForThumbnail', pero 'bytesForLibrary' quedará intacto
                  final document = await PdfDocument.openData(bytesForThumbnail);
                  final page = await document.getPage(1);
                  final pageImage = await page.render(
                    width: 200,
                    height: 200,
                    format: PdfPageImageFormat.png,
                  );
                  thumbnail = pageImage?.bytes;
                  await page.close();
                  await document.close();
                  debugPrint('Miniatura generada con éxito');
                } catch (e) {
                  debugPrint('Error generando miniatura: $e');
                }

                // Enviamos la copia que NO ha sido tocada por la librería de PDF
                onMapAdded(fileName, thumbnail, bytesForLibrary);
                debugPrint('Mapa enviado a la biblioteca de forma segura');
              }
          }),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, IconData icon, String label, VoidCallback onTap) {
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
