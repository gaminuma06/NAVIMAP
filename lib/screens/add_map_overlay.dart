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
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf'],
                withData: true,
              );

              if (result != null) {
                Uint8List? rawBytes;
                if (kIsWeb) {
                  rawBytes = result.files.single.bytes;
                } else {
                  final path = result.files.single.path;
                  if (path != null) {
                    rawBytes = await io.File(path).readAsBytes();
                  }
                }

                if (rawBytes == null || rawBytes.isEmpty) return;

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
