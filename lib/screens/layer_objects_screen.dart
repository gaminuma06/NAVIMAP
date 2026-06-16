import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import '../theme/design_system.dart';
import '../widgets/object_list_item.dart';
import '../widgets/export_layer_dialog.dart';
import '../services/layer_store.dart';
import '../services/georeference_service.dart';
import 'object_attributes_screen.dart';

class LayerObjectsScreen extends StatefulWidget {
  final String layerName;
  final String? mapContext;

  const LayerObjectsScreen({
    super.key,
    required this.layerName,
    this.mapContext,
  });

  @override
  State<LayerObjectsScreen> createState() => _LayerObjectsScreenState();
}

class _LayerObjectsScreenState extends State<LayerObjectsScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFormat = 'DD';

  bool get _isActiveLayer {
    if (widget.mapContext == null) return false;
    return LayerStore.activeMapLayer[widget.mapContext!] == widget.layerName;
  }

  String get _currentFormat {
    if (_isActiveLayer) {
      return GeoreferenceService().getCoordinateFormat(widget.mapContext!);
    }
    return _selectedFormat;
  }

  @override
  void initState() {
    super.initState();
    LayerStore.initializeLayer(widget.layerName, mapContext: widget.mapContext);
  }

  List<Map<String, dynamic>> get _allObjects {
    return LayerStore.getObjects(
      widget.layerName,
      mapContext: widget.mapContext,
    );
  }

  List<Map<String, dynamic>> get _filteredObjects {
    final all = _allObjects;
    if (_searchQuery.isEmpty) return all;
    return all
        .where(
          (obj) => obj['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  void _deleteObject(int index) {
    final objectToDelete = _filteredObjects[index];
    final realIndex = _allObjects.indexOf(objectToDelete);
    bool alsoDeleteCrossContext = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: DesignSystem.surface,
            title: const Text(
              '¿Eliminar objeto?',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Deseas eliminar "${objectToDelete['name']}"?',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: DesignSystem.spacingMd),
                Theme(
                  data: ThemeData(
                    unselectedWidgetColor: Colors.white30,
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      widget.mapContext != null
                          ? 'Eliminar también del menú de capas principal'
                          : 'Eliminar también de la capa de los mapas',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    value: alsoDeleteCrossContext,
                    activeColor: DesignSystem.primary,
                    checkColor: Colors.black,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setDialogState(() {
                        alsoDeleteCrossContext = val ?? false;
                      });
                    },
                  ),
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
                  backgroundColor: DesignSystem.error,
                ),
                onPressed: () {
                  setState(() {
                    if (alsoDeleteCrossContext) {
                      LayerStore.removeObjectCrossContext(
                        widget.layerName,
                        objectToDelete,
                        currentContext: widget.mapContext,
                      );
                    } else {
                      LayerStore.removeObject(
                        widget.layerName,
                        realIndex,
                        mapContext: widget.mapContext,
                      );
                    }
                  });
                  Navigator.pop(context);
                },
                child: const Text('ELIMINAR'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _duplicateObject(int index) {
    final objectToDuplicate = _filteredObjects[index];
    final realIndex = _allObjects.indexOf(objectToDuplicate);
    setState(
      () => LayerStore.duplicateObject(
        widget.layerName,
        realIndex,
        mapContext: widget.mapContext,
      ),
    );
  }

  void _renameObject(int index) {
    final originalObject = _filteredObjects[index];
    final controller = TextEditingController(text: originalObject['name']);
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
                'Renombrar Objeto',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el nuevo nombre para "${originalObject['name']}":',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre del objeto',
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
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
                final newName = controller.text.trim();
                if (newName.isEmpty) return;
                if (newName == originalObject['name']) {
                  Navigator.pop(context);
                  return;
                }
                
                if (_allObjects.any((obj) => obj['name'].toString().toLowerCase() == newName.toLowerCase())) {
                  setDialogState(() => errorText = 'Ya existe un objeto con este nombre');
                  return;
                }

                setState(() {
                  final updatedObject = Map<String, dynamic>.from(originalObject);
                  updatedObject['name'] = newName;
                  LayerStore.updateObject(
                    widget.layerName,
                    originalObject,
                    updatedObject,
                    mapContext: widget.mapContext,
                  );
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

  void _showMoveDialog(int index) {
    final objectToMove = _filteredObjects[index];
    final realIndex = _allObjects.indexOf(objectToMove);
    final List<Map<String, dynamic>> otherLayers = LayerStore.getLayers(
      widget.mapContext,
    ).where((l) => l['title'] != widget.layerName).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surface,
        title: const Text(
          'Mover a otra Capa',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: otherLayers.isEmpty
            ? const Text(
                'No hay otras capas disponibles.',
                style: TextStyle(color: Colors.white54),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: otherLayers.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (context, lIndex) => ListTile(
                    title: Text(
                      otherLayers[lIndex]['title'],
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () {
                      LayerStore.copyObjectToLayer(
                        widget.layerName,
                        realIndex,
                        otherLayers[lIndex]['title'],
                        mapContext: widget.mapContext,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
        ],
      ),
    );
  }

  void _exportObject(Map<String, dynamic> obj) {
    ExportLayerDialog.show(
      context,
      layerName: obj['name'],
      objects: [obj],
    );
  }

  void _showUpdateSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surface,
        title: const Text(
          'Actualizar objetos',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás seguro de que deseas actualizar los objetos en las capas? '
          'Esto sincronizará los objetos entre la capa del mapa y la capa principal global, '
          'haciendo que ambas contengan todos los objetos.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignSystem.primary,
            ),
            onPressed: () {
              setState(() {
                LayerStore.synchronizeLayers(
                  widget.layerName,
                  mapContext: widget.mapContext,
                );
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Objetos sincronizados y actualizados correctamente.'),
                  backgroundColor: DesignSystem.primary,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'ACTUALIZAR',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
                  hintText: 'Buscar objeto...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Text(
                widget.layerName.toUpperCase(),
                style: DesignSystem.labelCaps.copyWith(
                  color: DesignSystem.primary,
                ),
              ),
        actions: [
          if (!_isActiveLayer)
            IconButton(
              icon: const Icon(Icons.straighten, color: DesignSystem.primary),
              tooltip: 'Formato de Coordenadas',
              onPressed: _showFormatSelector,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: DesignSystem.spacingMd),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSystem.spacingMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OBJETOS (${_filteredObjects.length})',
                    style: DesignSystem.labelCaps.copyWith(color: Colors.white38),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignSystem.spacingSm,
                        vertical: DesignSystem.spacingXs,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _showUpdateSyncDialog,
                    icon: const Icon(
                      Icons.sync,
                      size: 14,
                      color: DesignSystem.primary,
                    ),
                    label: const Text(
                      'Actualizar objetos en las capas',
                      style: TextStyle(
                        color: DesignSystem.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignSystem.spacingMd),
            Expanded(
              child: _filteredObjects.isEmpty && !_isSearching
                  ? _buildEmptyStatePlaceholder()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignSystem.spacingMd,
                      ),
                      itemCount: _filteredObjects.length,
                      itemBuilder: (context, index) {
                        final obj = _filteredObjects[index];
                        return ObjectListItem(
                          name: obj['name'],
                          type: obj['type'],
                          value: _getObjectDisplayValue(obj),
                          color: obj['color'] != null ? Color(obj['color'] as int) : null,
                           onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ObjectAttributesScreen(
                                  layerName: widget.layerName,
                                  object: obj,
                                  mapContext: widget.mapContext,
                                ),
                              ),
                            ).then((value) {
                              if (value == true) {
                                setState(() {});
                              }
                            });
                          },
                          onDelete: () => _deleteObject(index),
                          onDuplicate: widget.mapContext != null ? () => _duplicateObject(index) : null,
                          onMoveToLayer: widget.mapContext != null ? () => _showMoveDialog(index) : null,
                          onExport: () => _exportObject(obj),
                          onRename: widget.mapContext != null ? () => _renameObject(index) : null,
                        );
                      },
                    ),
            ),
          ],
        ),
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
                  color: Colors.white.withValues(alpha: 0.05),
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
                        Icons.location_on_outlined,
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
            'Capa vacía',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
          const Text(
            'Esta capa aún no contiene objetos tácticos.',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _getObjectDisplayValue(Map<String, dynamic> obj) {
    if (obj['type'] == GeoObjectType.point &&
        obj['latitude'] != null &&
        obj['longitude'] != null) {
      final double lat = obj['latitude'] as double;
      final double lon = obj['longitude'] as double;
      final format = obj['coordinateFormat'] as String? ?? _currentFormat;
      return GeoreferenceService().formatCoordinates(
        lat,
        lon,
        format,
      );
    }
    return obj['value'] ?? '';
  }

  void _showFormatSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Formato de Coordenadas de la Capa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    _buildBottomSheetItem('DD', 'Grados Decimales (DD)', setModalState),
                    _buildBottomSheetItem('DM', 'Grados y Minutos (DM)', setModalState),
                    _buildBottomSheetItem('DMS', 'Grados, Minutos y Segundos (DMS)', setModalState),
                    _buildBottomSheetItem('UTM', 'UTM (WGS84)', setModalState),
                    _buildBottomSheetItem('ON', 'Origen Nacional (EPSG:9377)', setModalState),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheetItem(String value, String label, StateSetter setModalState) {
    final bool isSelected = _selectedFormat == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = value;
        });
        setModalState(() {});
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? DesignSystem.primary : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: DesignSystem.primary,
                size: 20,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.white24,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
