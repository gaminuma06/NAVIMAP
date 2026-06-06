import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import '../theme/design_system.dart';
import '../services/layer_store.dart';
import '../widgets/layer_list_item.dart';
import '../widgets/export_layer_dialog.dart';

class MapLayerLibraryScreen extends StatefulWidget {
  final String mapTitle;

  const MapLayerLibraryScreen({super.key, required this.mapTitle});

  @override
  State<MapLayerLibraryScreen> createState() => _MapLayerLibraryScreenState();
}

class _MapLayerLibraryScreenState extends State<MapLayerLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  List<Map<String, dynamic>> get _currentLayers {
    final list = List<Map<String, dynamic>>.from(LayerStore.getLayers(widget.mapTitle));
    final activeLayer = LayerStore.activeMapLayer[widget.mapTitle];
    if (activeLayer != null) {
      list.sort((a, b) {
        final aActive = a['title'] == activeLayer;
        final bActive = b['title'] == activeLayer;
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
        return 0;
      });
    }
    return list;
  }

  List<Map<String, dynamic>> get _filteredLayers {
    final allLayers = _currentLayers;
    if (_searchQuery.isEmpty) return allLayers;
    return allLayers
        .where(
          (l) => l['title'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  void _addLayer() {
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: DesignSystem.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          title: const Row(
            children: [
              Icon(Icons.layers_outlined, color: DesignSystem.primary),
              SizedBox(width: 12),
              Text(
                'Nueva Capa para el Mapa',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Deseas agregar una nueva capa? También se guardará en la biblioteca principal.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre de la capa',
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                  ),
                ),
                onChanged: (value) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                if (_currentLayers.any(
                  (l) => l['title'].toLowerCase() == name.toLowerCase(),
                )) {
                  setDialogState(
                    () => errorText = 'Ya existe esta capa en el mapa',
                  );
                  return;
                }
                setState(() {
                LayerStore.initializeLayer(name, mapContext: widget.mapTitle);
                final mapLayers = LayerStore.getLayers(widget.mapTitle);
                if (!mapLayers.any((l) => l['title'].toLowerCase() == name.toLowerCase())) {
                  mapLayers.add({'title': name, 'objects': 0});
                }
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

  void _showRenameLayerDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: DesignSystem.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_outlined, color: DesignSystem.primary),
              SizedBox(width: 12),
              Text(
                'Renombrar Capa',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el nuevo nombre para la capa "$oldName":',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre de la capa',
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                  ),
                ),
                onChanged: (value) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                if (name.toLowerCase() == oldName.toLowerCase()) {
                  Navigator.pop(context);
                  return;
                }
                if (_currentLayers.any(
                  (l) => l['title'].toLowerCase() == name.toLowerCase(),
                )) {
                  setDialogState(
                    () => errorText = 'Ya existe esta capa en el mapa',
                  );
                  return;
                }
                setState(() {
                  LayerStore.renameLayer(oldName, name);
                });
                Navigator.pop(context);
              },
              child: const Text('RENOMBRAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _importFromGlobal() {
    final globalLayers = LayerStore.getLayers(null);
    final availableToImport = globalLayers
        .where(
          (gl) => !_currentLayers.any(
            (cl) =>
                cl['title'].toString().toLowerCase() ==
                gl['title'].toString().toLowerCase(),
          ),
        )
        .toList();

    List<String> selectedLayerNames = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: DesignSystem.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          title: const Text(
            'Importar Capas Globales',
            style: TextStyle(color: Colors.white),
          ),
          content: availableToImport.isEmpty
              ? const Text(
                  'No hay nuevas capas en la biblioteca principal.',
                  style: TextStyle(color: Colors.white54),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableToImport.length,
                    itemBuilder: (context, index) {
                      final layer = availableToImport[index];
                      final isSelected = selectedLayerNames.contains(
                        layer['title'],
                      );
                      return CheckboxListTile(
                        activeColor: DesignSystem.primary,
                        checkColor: Colors.black,
                        title: Text(
                          layer['title'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: isSelected,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedLayerNames.add(layer['title']);
                            } else {
                              selectedLayerNames.remove(layer['title']);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            if (availableToImport.isNotEmpty)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignSystem.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: selectedLayerNames.isEmpty
                    ? null
                    : () {
                        setState(() {
                          for (var name in selectedLayerNames) {
                            LayerStore.importLayerWithObjects(
                              name,
                              widget.mapTitle,
                            );
                          }
                        });
                        Navigator.pop(context);
                      },
                child: const Text('IMPORTAR SELECCIONADAS'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar capa...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Text(
                'CAPAS: ${widget.mapTitle.toUpperCase()}',
                style: DesignSystem.labelCaps.copyWith(
                  color: DesignSystem.primary,
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: DesignSystem.primary,
            ),
            tooltip: 'Importar desde Global',
            onPressed: _importFromGlobal,
          ),
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
        ],
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Column(
          children: [
            const SizedBox(height: DesignSystem.spacingMd),
            Expanded(
              child: _filteredLayers.isEmpty && !_isSearching
                  ? _buildEmptyStatePlaceholder()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignSystem.spacingMd,
                      ),
                      itemCount: _filteredLayers.length,
                      itemBuilder: (context, index) {
                        final layer = _filteredLayers[index];
                        final activeLayer = LayerStore.activeMapLayer[widget.mapTitle];
                        final isActive = layer['title'] == activeLayer;
                        return LayerListItem(
                          title: layer['title'],
                          objectCount: layer['objects'] ?? 0,
                          isActive: isActive,
                          onToggleActive: () {
                            setState(() {
                              if (isActive) {
                                LayerStore.activeMapLayer[widget.mapTitle] = null;
                              } else {
                                LayerStore.activeMapLayer[widget.mapTitle] = layer['title'];
                              }
                            });
                          },
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/layer-objects',
                              arguments: {
                                'layerName': layer['title'],
                                'mapContext': widget.mapTitle,
                              },
                            ).then((_) => setState(() {}));
                          },
                          onDelete: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: DesignSystem.surface,
                                title: const Text(
                                  '¿Quitar Capa del Mapa?',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Text(
                                  '¿Deseas quitar "${layer['title']}" de este mapa? Seguirá disponible en la biblioteca principal.',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('CANCELAR'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: DesignSystem.error,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        final targetTitle = layer['title'];
                                        final realLayers = LayerStore.getLayers(widget.mapTitle);
                                        realLayers.removeWhere((l) => l['title'] == targetTitle);
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: const Text('QUITAR'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onRename: () => _showRenameLayerDialog(layer['title']),
                          onExport: () {
                            final objects = LayerStore.getObjects(layer['title'], mapContext: widget.mapTitle);
                            ExportLayerDialog.show(
                              context,
                              layerName: layer['title'],
                              objects: objects,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DesignSystem.primary,
        onPressed: _addLayer,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildEmptyStatePlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(DesignSystem.spacingMd),
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
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(
                    DesignSystem.radiusDefault,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(
                          DesignSystem.radiusSm,
                        ),
                      ),
                      child: const Icon(
                        Icons.layers_outlined,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: DesignSystem.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignSystem.spacingLg),
          const Text(
            'No hay capas en este mapa',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
          const Text(
            'Usa el botón + para añadir o importar capas',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
