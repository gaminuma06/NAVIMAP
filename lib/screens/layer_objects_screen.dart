import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import '../widgets/object_list_item.dart';
import '../services/layer_store.dart';

class LayerObjectsScreen extends StatefulWidget {
  final String layerName;

  const LayerObjectsScreen({
    super.key,
    required this.layerName,
  });

  @override
  State<LayerObjectsScreen> createState() => _LayerObjectsScreenState();
}

class _LayerObjectsScreenState extends State<LayerObjectsScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    LayerStore.initializeLayer(widget.layerName);
    
    // Inicialización de datos de ejemplo si la capa está vacía
    if (LayerStore.layerObjects[widget.layerName]!.isEmpty) {
      LayerStore.addObject(widget.layerName, {
        'name': 'Punto de control 1',
        'type': GeoObjectType.point,
        'value': 'Lat: 4.6097, Lon: -74.0817',
      });
      LayerStore.addObject(widget.layerName, {
        'name': 'Línea de frontera Norte',
        'type': GeoObjectType.line,
        'value': '1.450 metros',
      });
      LayerStore.addObject(widget.layerName, {
        'name': 'Área de entrenamiento B',
        'type': GeoObjectType.polygon,
        'value': '12.500 m²',
      });
    }
  }

  List<Map<String, dynamic>> get _allObjects => LayerStore.layerObjects[widget.layerName] ?? [];

  List<Map<String, dynamic>> get _filteredObjects {
    if (_searchQuery.isEmpty) return _allObjects;
    return _allObjects.where((obj) => 
      obj['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void _deleteObject(int index) {
    // Buscamos el objeto real en la lista completa para borrar el correcto
    final objectToDelete = _filteredObjects[index];
    final realIndex = _allObjects.indexOf(objectToDelete);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surface,
        title: const Text('¿Eliminar objeto?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Esta acción no se puede deshacer. ¿Deseas eliminar "${objectToDelete['name']}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DesignSystem.error),
            onPressed: () {
              setState(() => LayerStore.removeObject(widget.layerName, realIndex));
              Navigator.pop(context);
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  void _duplicateObject(int index) {
    final objectToDuplicate = _filteredObjects[index];
    final realIndex = _allObjects.indexOf(objectToDuplicate);
    setState(() => LayerStore.duplicateObject(widget.layerName, realIndex));
  }

  void _showMoveDialog(int index) {
    final objectToMove = _filteredObjects[index];
    final realIndex = _allObjects.indexOf(objectToMove);

    final List<Map<String, dynamic>> otherLayers = LayerStore.layers
        .where((l) => l['title'] != widget.layerName)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surface,
        title: const Text('Seleccionar Capa Destino', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: otherLayers.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No hay otras capas a las que mover el objeto.', style: TextStyle(color: Colors.white54)),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: otherLayers.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.1)),
                  itemBuilder: (context, lIndex) => ListTile(
                    title: Text(otherLayers[lIndex]['title'], style: const TextStyle(color: Colors.white70)),
                    onTap: () {
                      LayerStore.copyObjectToLayer(widget.layerName, realIndex, otherLayers[lIndex]['title']);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar objeto...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            )
          : Text(
              widget.layerName.toUpperCase(),
              style: DesignSystem.labelCaps.copyWith(color: DesignSystem.primary),
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
        ],
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: DesignSystem.spacingMd),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spacingMd),
              child: Text(
                'OBJETOS DISPONIBLES (${_filteredObjects.length})',
                style: DesignSystem.labelCaps.copyWith(color: Colors.white38),
              ),
            ),
            const SizedBox(height: DesignSystem.spacingMd),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spacingMd),
                itemCount: _filteredObjects.length,
                itemBuilder: (context, index) {
                  final obj = _filteredObjects[index];
                  return ObjectListItem(
                    name: obj['name'],
                    type: obj['type'],
                    value: obj['value'],
                    onTap: () {},
                    onDelete: () => _deleteObject(index),
                    onDuplicate: () => _duplicateObject(index),
                    onMoveToLayer: () => _showMoveDialog(index),
                    onExport: () {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
