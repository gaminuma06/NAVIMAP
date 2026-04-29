import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import '../services/map_data_service.dart';
import '../services/user_location_service.dart';
import '../services/georeference_service.dart';
import '../widgets/user_location_marker.dart';

class MapDetailScreen extends StatefulWidget {
  const MapDetailScreen({super.key});

  @override
  State<MapDetailScreen> createState() => _MapDetailScreenState();
}

class _MapDetailScreenState extends State<MapDetailScreen> {
  PdfController? _pdfController;
  String _mapTitle = '';
  String? _errorMessage;
  
  UserLocationData? _currentUserLocation;
  Offset? _markerPosition;
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  double _pdfPageWidth = 1000; 
  double _pdfPageHeight = 1000;

  @override
  void initState() {
    super.initState();
    _loadMap();
    _initLocationTracking();
    _transformationController.addListener(() {
      setState(() {
        _currentScale = _transformationController.value.getMaxScaleOnAxis();
      });
    });
  }

  void _initLocationTracking() {
    UserLocationService().startTracking();
    UserLocationService().locationStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentUserLocation = data;
          _updateMarkerPosition();
        });
      }
    });
  }

  void _updateMarkerPosition() {
    if (_currentUserLocation == null) return;
    
    final position = GeoreferenceService().getPixelOffset(
      mapTitle: _mapTitle,
      lat: _currentUserLocation!.latitude,
      lon: _currentUserLocation!.longitude,
      mapWidth: _pdfPageWidth,
      mapHeight: _pdfPageHeight,
    );

    if (position != null && !position.dx.isNaN && !position.dy.isNaN) {
      _markerPosition = position;
    } else {
      _markerPosition = null;
    }
  }

  Uint8List? _mapImageBytes;

  Future<void> _loadMap() async {
    final service = MapDataService();
    _mapTitle = service.currentMapTitle ?? 'Mapa';
    final bytes = service.currentMapBytes;

    if (bytes != null && bytes.isNotEmpty) {
      try {
        await GeoreferenceService().scanGeoPdfMetadata(_mapTitle, bytes);

        final document = await PdfDocument.openData(bytes);
        final page = await document.getPage(1);
        
        // Renderizar la página como imagen para control total de píxeles
        final image = await page.render(
          width: page.width * 2, 
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );

        setState(() {
          // Usamos las dimensiones reales del renderizado para evitar distorsiones ("apachurado")
          _pdfPageWidth = (image!.width ?? (page.width * 2)) / 2;
          _pdfPageHeight = (image.height ?? (page.height * 2)) / 2;
          _mapImageBytes = image.bytes;
          _pdfController = PdfController(document: Future.value(document));
        });
      } catch (e) {
        setState(() => _errorMessage = 'Error al abrir el PDF: $e');
      }
    } else {
      setState(() => _errorMessage = 'El archivo no contiene datos válidos.');
    }
  }

  void _openMapLayers() {
    Navigator.pushNamed(
      context, 
      '/map-layers',
      arguments: _mapTitle,
    ).then((_) => setState(() {}));
  }

  @override
  void dispose() {
    UserLocationService().stopTracking();
    _pdfController?.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calcular dinámicamente la coordenada a la que apunta la mira central
    Map<String, double>? centerLatLon;
    if (_pdfPageWidth > 0 && _pdfPageHeight > 0) {
      final screenSize = MediaQuery.of(context).size;
      final viewportCenter = Offset(screenSize.width / 2, screenSize.height / 2);
      final sceneCenter = _transformationController.toScene(viewportCenter);
      
      centerLatLon = GeoreferenceService().getLatLonFromPixel(
        px: sceneCenter.dx,
        py: sceneCenter.dy,
        mapWidth: _pdfPageWidth,
        mapHeight: _pdfPageHeight,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        centerTitle: true,
        title: Text(_mapTitle, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: DesignSystem.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: DesignSystem.primary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.info_outline, color: DesignSystem.primary), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          Container(color: Colors.grey[600]),
          _pdfController == null
              ? const Center(child: CircularProgressIndicator(color: DesignSystem.primary))
              : Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return InteractiveViewer(
                        transformationController: _transformationController,
                        maxScale: 40.0,
                        minScale: 0.1,
                        boundaryMargin: const EdgeInsets.all(1000),
                        child: _mapImageBytes == null 
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              width: _pdfPageWidth,
                              height: _pdfPageHeight,
                              child: LayoutBuilder(
                                builder: (context, stackConstraints) {
                                  // Recalcular la posición usando el tamaño REAL del Stack en pantalla
                                  Offset? dynamicPosition;
                                  if (_currentUserLocation != null) {
                                    dynamicPosition = GeoreferenceService().getPixelOffset(
                                      mapTitle: _mapTitle,
                                      lat: _currentUserLocation!.latitude,
                                      lon: _currentUserLocation!.longitude,
                                      mapWidth: stackConstraints.maxWidth,
                                      mapHeight: stackConstraints.maxHeight,
                                    );
                                  }

                                  return Stack(
                                    alignment: Alignment.topLeft,
                                    children: [
                                      Image.memory(
                                        _mapImageBytes!,
                                        width: stackConstraints.maxWidth,
                                        height: stackConstraints.maxHeight,
                                        fit: BoxFit.contain, // Mantiene la relación de aspecto sin apachurrar
                                      ),
                                      if (dynamicPosition != null)
                                        Positioned(
                                          left: dynamicPosition.dx - 30,
                                          top: dynamicPosition.dy - 30,
                                          child: Transform.scale(
                                            scale: _currentScale > 0 ? (1.0 / _currentScale) : 1.0, 
                                            child: UserLocationMarker(
                                              heading: _currentUserLocation?.heading ?? 0,
                                            ),
                                          ),
                                        ),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
          
          // Crosshair en el centro de la pantalla (Mira estática combinada)
          Center(
            child: SizedBox(
              width: 40, height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.circle_outlined, color: DesignSystem.primary.withOpacity(0.8), size: 28),
                  Icon(Icons.add, color: DesignSystem.primary.withOpacity(0.8), size: 38),
                ],
              ),
            ),
          ),
          
          Positioned(top: 20, right: 20, child: _buildCircularButton(Icons.navigation_outlined)),
          Positioned(
            bottom: 100, 
            right: 20, 
            child: GestureDetector(
              onTap: () {
                // Usamos el GPS real, ya no sobreescribimos con coordenadas simuladas.
              },
              child: _buildCircularButton(Icons.location_on),
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
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
                        decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          centerLatLon != null 
                            ? '${centerLatLon['lat']!.toStringAsFixed(6)}, ${centerLatLon['lon']!.toStringAsFixed(6)}'
                            : 'Calculando coordenadas...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(onTap: _openMapLayers, child: const Icon(Icons.layers_outlined, color: DesignSystem.primary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: DesignSystem.primary, borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCircularButton(IconData icon) {
    return Container(
      width: 50, height: 50,
      decoration: const BoxDecoration(color: Color(0xFF0D0D0D), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))]),
      child: Icon(icon, color: DesignSystem.primary, size: 26),
    );
  }
}
