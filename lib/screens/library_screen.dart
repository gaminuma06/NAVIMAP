import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:js' as js; // Importación necesaria para la descarga en Web
import '../theme/design_system.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/map_list_item.dart';
import 'add_map_overlay.dart';
import '../services/map_data_service.dart';

// Almacén estático para asegurar que los bytes persistan en la sesión Web
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

  final List<Map<String, dynamic>> _mockMaps = [
    {
      'title': 'Hacienda La Gloria',
      'date': '24/04/2026',
      'status': MapSpatialStatus.within,
    },
    {
      'title': 'Rio Verde Basin',
      'date': '22/04/2026',
      'status': MapSpatialStatus.outside,
    },
    {
      'title': 'Sector Norte - Sin Ref',
      'date': '20/04/2026',
      'status': MapSpatialStatus.notReferenced,
    },
  ];

  List<Map<String, dynamic>> get _filteredMaps {
    if (_searchQuery.isEmpty) return _mockMaps;
    return _mockMaps.where((map) => 
      map['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar mapa...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
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
      body: Column(
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
              'MAPAS DISPONIBLES (${_filteredMaps.length})',
              style: DesignSystem.labelCaps.copyWith(color: Colors.white54),
            ),
          ),
          const SizedBox(height: DesignSystem.spacingMd),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spacingMd),
              itemCount: _filteredMaps.length,
              itemBuilder: (context, index) {
                final map = _filteredMaps[index];
                final String title = map['title'];
                
                return MapListItem(
                  title: title,
                  dateAdded: map['date'],
                  status: map['status'],
                  thumbnailBytes: map['thumbnailBytes'],
                  onTap: () {
                    final bytes = MapStore.bytesCache[title];
                    if (bytes != null) {
                      // Pasamos una COPIA al servicio para que el visor no destruya el original en el caché
                      MapDataService().setCurrentMap(title, Uint8List.fromList(bytes));
                    }
                    Navigator.pushNamed(context, '/detail');
                  },
                  onDownload: () {
                    final bytes = MapStore.bytesCache[title];
                    if (bytes != null) {
                      // Pasamos una COPIA a la descarga
                      _downloadMap(title, Uint8List.fromList(bytes));
                    } else {
                      _downloadMap(title, null);
                    }
                  },
                  onDelete: () => _confirmDelete(index),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddMapOverlay.show(
          context,
          onMapAdded: (name, thumbnail, fullBytes) {
            if (fullBytes != null) {
              // Guardamos la copia original "sagrada" en el caché
              MapStore.bytesCache[name] = Uint8List.fromList(fullBytes);
              debugPrint('MapStore: Guardados ${fullBytes.length} bytes SAGRADOS para $name');
            }
            setState(() {
              _mockMaps.insert(0, {
                'title': name,
                'date': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                'status': MapSpatialStatus.outside,
                'thumbnailBytes': thumbnail,
              });
            });
          },
        ),
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
          if (index == 1) Navigator.pushReplacementNamed(context, '/satellite');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Biblioteca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.satellite_alt),
            label: 'Satélite',
          ),
        ],
      ),
    );
  }

  void _downloadMap(String title, Uint8List? bytes) {
    debugPrint('Intentando descargar: $title');
    debugPrint('Bytes disponibles: ${bytes != null ? bytes.length : 'null'}');

    if (bytes == null || bytes.isEmpty) {
      String reason = (bytes == null) ? 'Datos nulos' : 'Archivo vacío';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede descargar ($reason). Los mapas de ejemplo no tienen archivo físico.')),
      );
      return;
    }

    try {
      // PROCESO DE DESCARGA REAL PARA WEB
      final String fileName = title.toLowerCase().endsWith('.pdf') ? title : '$title.pdf';
      final bytesList = bytes.toList();
      
      js.context.callMethod('eval', [
        """
        console.log('Iniciando descarga desde JS...');
        var blob = new Blob([new Uint8Array($bytesList)], {type: 'application/pdf'});
        var link = document.createElement('a');
        link.href = window.URL.createObjectURL(blob);
        link.download = '$fileName';
        link.click();
        window.URL.revokeObjectURL(link.href);
        console.log('Descarga completada');
        """
      ]);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Descargando $fileName...'),
          backgroundColor: DesignSystem.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Fallback si el JS falla (algunos navegadores)
      debugPrint('Error en descarga: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar descarga: $e')),
      );
    }
  }

  void _confirmDelete(int index) {
    final mapToDelete = _filteredMaps[index];
    final originalIndex = _mockMaps.indexOf(mapToDelete);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignSystem.radiusLg)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: DesignSystem.error),
            SizedBox(width: 12),
            Text('¿Eliminar mapa?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${mapToDelete['title']}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignSystem.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignSystem.radiusSm)),
            ),
            onPressed: () {
              setState(() {
                _mockMaps.removeAt(originalIndex);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mapa eliminado')),
              );
            },
            child: const Text('ELIMINAR'),
          ),
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
          decoration: BoxDecoration(
            color: isSelected ? DesignSystem.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: DesignSystem.labelCaps.copyWith(
              color: isSelected ? Colors.black : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
