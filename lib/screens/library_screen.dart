import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:dotted_border/dotted_border.dart';
import '../theme/design_system.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/map_list_item.dart';
import '../widgets/layer_list_item.dart';
import '../widgets/map_loading_item.dart';
import '../widgets/object_list_item.dart';
import 'add_map_overlay.dart';
import '../services/map_data_service.dart';
import '../services/layer_store.dart';

class MapStore {
  static Map<String, Uint8List> bytesCache = {};
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedSegment = 0; // 0 for Mapas, 1 for Capas
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _mockMaps = [];
  final List<String> _loadingMaps = []; // Nombres de los mapas que se están procesando

  bool get isMapsTab => _selectedSegment == 0;

  List<Map<String, dynamic>> get _filteredMaps {
    if (_searchQuery.isEmpty) return _mockMaps;
    return _mockMaps.where((map) => 
      map['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  List<Map<String, dynamic>> get _filteredLayers {
    final allLayers = LayerStore.getLayers(null);
    if (_searchQuery.isEmpty) return allLayers;
    return allLayers.where((layer) => 
      layer['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentList = isMapsTab ? _filteredMaps : _filteredLayers;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            )
          : Text(
              'NAVIMAP',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      drawer: const SidebarMenu(),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignSystem.spacingMd),
              child: Container(
                padding: const EdgeInsets.all(DesignSystem.spacingXs),
                decoration: BoxDecoration(
                  color: DesignSystem.surfaceContainer,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                  border: Border.all(color: DesignSystem.outline),
                ),
                child: Row(
                  children: [
                    _buildSegment('Mapas', 0),
                    _buildSegment('Capas', 1),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spacingMd),
              child: Text(
                '${isMapsTab ? "MAPAS" : "CAPAS"} DISPONIBLES (${currentList.length + (isMapsTab ? _loadingMaps.length : 0)})',
                style: DesignSystem.labelCaps.copyWith(color: Colors.white54),
              ),
            ),
            const SizedBox(height: DesignSystem.spacingMd),
            Expanded(
              child: (currentList.isEmpty && _loadingMaps.isEmpty && !_isSearching)
                  ? _buildEmptyStatePlaceholder(isMapsTab ? 'mapas' : 'capas')
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spacingMd),
                      children: [
                        // Tarjetas de carga primero
                        if (isMapsTab) ..._loadingMaps.map((name) => MapLoadingItem(title: name)).toList(),
                        // Lista normal
                        ...currentList.map((item) {
                          final String title = item['title'];
                          if (isMapsTab) {
                            return MapListItem(
                              title: title,
                              dateAdded: item['date'],
                              status: item['status'],
                              thumbnailBytes: item['thumbnailBytes'],
                              onTap: () {
                                final bytes = MapStore.bytesCache[title];
                                if (bytes != null) {
                                  MapDataService().setCurrentMap(title, Uint8List.fromList(bytes));
                                }
                                Navigator.pushNamed(context, '/detail');
                              },
                              onDelete: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: DesignSystem.surface,
                                    title: const Text('¿Eliminar Mapa?', style: TextStyle(color: Colors.white)),
                                    content: Text('¿Deseas eliminar el mapa "${title}"? Todos los datos asociados se perderán.', style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: DesignSystem.error),
                                        onPressed: () {
                                          setState(() => _mockMaps.remove(item));
                                          Navigator.pop(context);
                                        },
                                        child: const Text('ELIMINAR'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          } else {
                            return LayerListItem(
                              title: title,
                              objectCount: item['objects'] ?? 0,
                              onTap: () {
                                Navigator.pushNamed(
                                  context, 
                                  '/layer-objects',
                                  arguments: {
                                    'layerName': title,
                                    'mapContext': null,
                                  },
                                ).then((_) => setState(() {}));
                              },
                              onDelete: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: DesignSystem.surface,
                                    title: const Text('¿Eliminar Capa?', style: TextStyle(color: Colors.white)),
                                    content: Text('¿Deseas eliminar "${title}" del respaldo global? Esta acción no se puede deshacer.', style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: DesignSystem.error),
                                        onPressed: () {
                                          setState(() {
                                            LayerStore.layers.remove(item);
                                            LayerStore.mapLayerObjects.remove(title);
                                          });
                                          Navigator.pop(context);
                                        },
                                        child: const Text('ELIMINAR'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onRename: () {},
                              onExport: () {},
                            );
                          }
                        }).toList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddPressed(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: DesignSystem.surface,
        selectedItemColor: DesignSystem.primary,
        unselectedItemColor: Colors.white24,
        selectedLabelStyle: DesignSystem.labelCaps,
        unselectedLabelStyle: DesignSystem.labelCaps,
        onTap: (index) {
          if (index == 0) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Funcionalidad de Satélite próximamente')),
          );
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Biblioteca'),
          BottomNavigationBarItem(
            icon: Icon(Icons.satellite_alt, color: Colors.white.withOpacity(0.05)),
            label: 'Satélite',
          ),
        ],
      ),
    );
  }

  void _onAddPressed() {
    if (isMapsTab) {
      AddMapOverlay.show(
        context,
        onMapProcessingStarted: (name) {
          setState(() {
            _loadingMaps.insert(0, name);
          });
        },
        onMapAdded: (name, thumbnail, fullBytes) {
          if (fullBytes != null) MapStore.bytesCache[name] = Uint8List.fromList(fullBytes);
          setState(() {
            _loadingMaps.remove(name);
            _mockMaps.insert(0, {
              'title': name,
              'date': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              'status': MapSpatialStatus.outside,
              'thumbnailBytes': thumbnail,
            });
          });
        },
      );
    } else {
      _showAddLayerDialog();
    }
  }

  void _showAddLayerDialog() {
    final controller = TextEditingController();
    String? errorText;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: DesignSystem.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignSystem.radiusLg)),
          title: const Row(
            children: [
              Icon(Icons.layers_outlined, color: DesignSystem.primary),
              SizedBox(width: 12),
              Text('Nueva Capa', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Deseas agregar una nueva capa de información?', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre de la capa',
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignSystem.radiusSm)),
                ),
                onChanged: (value) { if (errorText != null) setDialogState(() => errorText = null); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: DesignSystem.primary, foregroundColor: Colors.black),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final layers = LayerStore.getLayers(null);
                if (layers.any((l) => l['title'].toString().toLowerCase() == name.toLowerCase())) {
                  setDialogState(() => errorText = 'Ya existe esta capa');
                  return;
                }
                setState(() {
                  layers.insert(0, {'title': name, 'objects': 1});
                  LayerStore.initializeLayer(name);
                  // Añadir objeto de ejemplo inmediatamente para que el conteo sea correcto desde el exterior
                  LayerStore.addObject(name, {
                    'name': 'Punto de control 1',
                    'type': GeoObjectType.point,
                    'value': 'Lat: 4.6097, Lon: -74.0817',
                  }, mapContext: null);
                });
                Navigator.pop(context);
              },
              child: const Text('CREAR CAPA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStatePlaceholder(String type) {
    final bool isMap = type == 'mapas';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spacingMd),
      child: Column(
        children: [
          Opacity(
            opacity: 0.4,
            child: DottedBorder(
              color: Colors.white24,
              strokeWidth: 2,
              dashPattern: const [8, 4],
              borderType: BorderType.RRect,
              radius: const Radius.circular(DesignSystem.radiusDefault),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesignSystem.spacingMd),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(DesignSystem.radiusDefault)),
                child: Row(
                  children: [
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(DesignSystem.radiusSm)), child: Icon(isMap ? Icons.map_outlined : Icons.layers_outlined, color: Colors.white24)),
                    const SizedBox(width: DesignSystem.spacingMd),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 14, width: 150, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 8), Container(height: 10, width: 100, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)))]))
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignSystem.spacingLg),
          Text('No hay $type cargadas', style: const TextStyle(color: Colors.white38, fontSize: 16)),
          Text('Usa el botón + para añadir tu primera ${isMap ? "mapa" : "capa"}', style: const TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, int index) {
    bool isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DesignSystem.spacingSm),
          decoration: BoxDecoration(color: isSelected ? DesignSystem.primary : Colors.transparent, borderRadius: BorderRadius.circular(DesignSystem.radiusSm)),
          child: Text(label, textAlign: TextAlign.center, style: DesignSystem.labelCaps.copyWith(color: isSelected ? Colors.black : Colors.white54)),
        ),
      ),
    );
  }
}
