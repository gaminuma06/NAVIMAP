import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import '../services/map_data_service.dart';

class MapDetailScreen extends StatefulWidget {
  const MapDetailScreen({super.key});

  @override
  State<MapDetailScreen> createState() => _MapDetailScreenState();
}

class _MapDetailScreenState extends State<MapDetailScreen> {
  PdfController? _pdfController;
  String _mapTitle = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  void _loadMap() {
    final service = MapDataService();
    _mapTitle = service.currentMapTitle ?? 'Mapa';
    final bytes = service.currentMapBytes;

    if (bytes != null && bytes.isNotEmpty) {
      try {
        _pdfController = PdfController(
          document: PdfDocument.openData(bytes),
        );
      } catch (e) {
        _errorMessage = 'Error al abrir el PDF: $e';
      }
    } else {
      _errorMessage = 'El archivo no contiene datos válidos o es un mapa de ejemplo.';
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        centerTitle: true,
        title: Text(_mapTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: DesignSystem.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: DesignSystem.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: DesignSystem.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fondo Gris del Mapa
          Container(color: Colors.grey[600]),

          _pdfController == null
              ? const Center(child: CircularProgressIndicator(color: DesignSystem.primary))
              : Positioned.fill(
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 1.0, // El mapa siempre ocupará al menos la pantalla
                    maxScale: 50.0,
                    boundaryMargin: const EdgeInsets.all(50), // Margen pequeño para que se sienta el tope
                    constrained: true,
                    child: IgnorePointer(
                      child: PdfView(
                        controller: _pdfController!,
                        physics: const NeverScrollableScrollPhysics(),
                        builders: PdfViewBuilders<DefaultBuilderOptions>(
                          options: const DefaultBuilderOptions(),
                          documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: DesignSystem.primary)),
                          pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: DesignSystem.primary)),
                          errorBuilder: (_, error) => Center(child: Text(error.toString(), style: const TextStyle(color: Colors.white))),
                        ),
                      ),
                    ),
                  ),
                ),

          // Mira (Crosshair) Central - Se mantiene fija sobre el visor
          IgnorePointer(
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withOpacity(0.3), width: 1),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(width: 20, height: 1, color: Colors.black.withOpacity(0.3)),
                    Container(width: 1, height: 20, color: Colors.black.withOpacity(0.3)),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Botón Compás (Arriba Derecha)
          Positioned(
            top: 20,
            right: 20,
            child: _buildCircularButton(Icons.navigation_outlined),
          ),

          // Escala (Abajo Izquierda)
          Positioned(
            bottom: 100,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('500 m', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: 60,
                  height: 8,
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.white, width: 2),
                      bottom: BorderSide(color: Colors.white, width: 2),
                      right: BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botón Ubicación (Abajo Derecha)
          Positioned(
            bottom: 100,
            right: 20,
            child: _buildCircularButton(Icons.location_on),
          ),

          // Barra Inferior de Herramientas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0D0D0D),
              child: SafeArea(
                child: Row(
                  children: [
                    const Icon(Icons.straighten, color: DesignSystem.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '8°39\'18.5", -73°50\'14.9"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.layers_outlined, color: DesignSystem.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton(IconData icon) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Icon(
        icon,
        color: DesignSystem.primary,
        size: 26,
      ),
    );
  }
}
