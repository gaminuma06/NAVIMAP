
class LayerStore {
  // --- BIBLIOTECA GENERAL (RESPALDO MAESTRO) ---
  static List<Map<String, dynamic>> layers = [];

  // --- BIBLIOTECAS POR MAPA ---
  static Map<String, List<Map<String, dynamic>>> mapLayers = {};

  // ALMACENAMIENTO UNIFICADO DE OBJETOS
  static Map<String, List<Map<String, dynamic>>> mapLayerObjects = {};

  // CAPA ACTIVA POR MAPA
  static Map<String, String?> activeMapLayer = {};

  // Obtiene las capas según el contexto (Global o Mapa)
  static List<Map<String, dynamic>> getLayers(String? mapContext) {
    if (mapContext == null) return layers;
    if (!mapLayers.containsKey(mapContext)) {
      mapLayers[mapContext] = [];
    }
    return mapLayers[mapContext]!;
  }

  static String _getCanonicalLayerName(String name) {
    for (var l in layers) {
      if (l['title'].toString().toLowerCase() == name.toLowerCase()) {
        return l['title'].toString();
      }
    }
    return name;
  }

  // Obtiene los objetos de forma SEGURA
  static List<Map<String, dynamic>> getObjects(
    String layerName, {
    String? mapContext,
  }) {
    final canonicalName = _getCanonicalLayerName(layerName);
    final key = mapContext == null ? canonicalName : '${mapContext}_$canonicalName';
    if (!mapLayerObjects.containsKey(key)) {
      mapLayerObjects[key] = [];
    }
    return mapLayerObjects[key]!;
  }

  static void initializeLayer(String layerName, {String? mapContext}) {
    final canonicalName = _getCanonicalLayerName(layerName);
    final key = mapContext != null ? '${mapContext}_$canonicalName' : canonicalName;
    if (!mapLayerObjects.containsKey(key)) {
      mapLayerObjects[key] = [];
    }

    // Asegurar que exista en el RESPALDO GLOBAL
    if (!layers.any(
      (l) => l['title'].toString().toLowerCase() == canonicalName.toLowerCase(),
    )) {
      layers.insert(0, {'title': canonicalName, 'objects': 0});
      if (!mapLayerObjects.containsKey(canonicalName)) {
        mapLayerObjects[canonicalName] = [];
      }
    }
  }

  static void addObject(
    String layerName,
    Map<String, dynamic> object, {
    String? mapContext,
    bool isSyncCall = false,
  }) {
    final canonicalName = _getCanonicalLayerName(layerName);
    initializeLayer(canonicalName, mapContext: mapContext);
    final objects = getObjects(canonicalName, mapContext: mapContext);

    // Inicializar atributos por defecto
    if (!object.containsKey('color')) {
      object['color'] = 0xFFFF1744; // Rojo por defecto
    }
    if (!object.containsKey('createdAt')) {
      object['createdAt'] = DateTime.now().toIso8601String();
    }

    // Evitar duplicados exactos
    if (!_containsObject(objects, object)) {
      objects.insert(0, object);
      _updateLayerCount(canonicalName, mapContext);
    }

    // BREAK: Si es una llamada de sincronización, no propagar más para evitar bucles
    if (isSyncCall) return;

    if (mapContext != null) {
      // Sincronización HACIA ARRIBA (Mapa -> Global) con bandera de seguridad
      addObject(canonicalName, object, mapContext: null, isSyncCall: true);
    } else {
      // Sincronización HACIA ABAJO (Global -> Todos los mapas) con bandera de seguridad
      for (var contextKey in mapLayers.keys) {
        final currentMapLayers = mapLayers[contextKey]!;
        if (currentMapLayers.any((l) => l['title'].toString().toLowerCase() == canonicalName.toLowerCase())) {
          addObject(
            canonicalName,
            Map<String, dynamic>.from(object),
            mapContext: contextKey,
            isSyncCall: true,
          );
        }
      }
    }
  }

  static void updateObject(
    String layerName,
    Map<String, dynamic> originalObject,
    Map<String, dynamic> updatedObject, {
    String? mapContext,
  }) {
    final canonicalName = _getCanonicalLayerName(layerName);

    // 1. Actualizar en el contexto actual
    final currentObjects = getObjects(canonicalName, mapContext: mapContext);
    final index = currentObjects.indexWhere(
      (item) => item['name'] == originalObject['name'] && item['value'] == originalObject['value'],
    );
    if (index != -1) {
      currentObjects[index] = updatedObject;
      _updateLayerCount(canonicalName, mapContext);
    }

    // 2. Sincronización cruzada
    if (mapContext != null) {
      // Mapa -> Global
      final globalObjects = getObjects(canonicalName, mapContext: null);
      final globalIndex = globalObjects.indexWhere(
        (item) => item['name'] == originalObject['name'] && item['value'] == originalObject['value'],
      );
      if (globalIndex != -1) {
        globalObjects[globalIndex] = Map<String, dynamic>.from(updatedObject);
        _updateLayerCount(canonicalName, null);
      }
    } else {
      // Global -> Todos los mapas
      for (var contextKey in mapLayers.keys) {
        final mapObjects = getObjects(canonicalName, mapContext: contextKey);
        final mapIndex = mapObjects.indexWhere(
          (item) => item['name'] == originalObject['name'] && item['value'] == originalObject['value'],
        );
        if (mapIndex != -1) {
          mapObjects[mapIndex] = Map<String, dynamic>.from(updatedObject);
          _updateLayerCount(canonicalName, contextKey);
        }
      }
    }
  }

  static void removeObject(
    String layerName,
    int index, {
    String? mapContext,
    bool isSyncCall = false,
  }) {
    final canonicalName = _getCanonicalLayerName(layerName);
    final objects = getObjects(canonicalName, mapContext: mapContext);
    if (index < objects.length) {
      objects.removeAt(index);
      _updateLayerCount(canonicalName, mapContext);
    }
  }

  static void duplicateObject(
    String layerName,
    int index, {
    String? mapContext,
  }) {
    final canonicalName = _getCanonicalLayerName(layerName);
    final objects = getObjects(canonicalName, mapContext: mapContext);
    if (objects.length > index) {
      final original = objects[index];
      final copy = Map<String, dynamic>.from(original);

      String baseName = original['name'];
      final copyPattern = RegExp(r' \(copia( \d+)?\)$');
      baseName = baseName.replaceFirst(copyPattern, '');

      int nextNum = 1;
      for (var obj in objects) {
        String name = obj['name'];
        if (name.startsWith(baseName)) {
          final match = copyPattern.firstMatch(name);
          if (match != null) {
            String? numStr = match.group(1)?.trim();
            int num = numStr == null ? 1 : int.parse(numStr);
            if (num >= nextNum) nextNum = num + 1;
          }
        }
      }
      copy['name'] = '$baseName (copia${nextNum == 1 ? "" : " $nextNum"})';

      // Añadir el duplicado (addObject manejará la sincronización sin bucles)
      addObject(canonicalName, copy, mapContext: mapContext);
    }
  }

  static void copyObjectToLayer(
    String fromLayer,
    int index,
    String toLayer, {
    String? mapContext,
  }) {
    final canonicalFrom = _getCanonicalLayerName(fromLayer);
    final canonicalTo = _getCanonicalLayerName(toLayer);
    final objects = getObjects(canonicalFrom, mapContext: mapContext);
    if (objects.length > index) {
      final objectToCopy = Map<String, dynamic>.from(objects[index]);
      addObject(canonicalTo, objectToCopy, mapContext: mapContext);
    }
  }

  static void importLayerWithObjects(String layerName, String mapContext) {
    final canonicalName = _getCanonicalLayerName(layerName);
    initializeLayer(canonicalName, mapContext: mapContext);

    final currentMapLayers = getLayers(mapContext);
    if (!currentMapLayers.any((l) => l['title'].toString().toLowerCase() == canonicalName.toLowerCase())) {
      final globalLayer = layers.firstWhere((l) => l['title'].toString().toLowerCase() == canonicalName.toLowerCase());
      currentMapLayers.add({
        'title': canonicalName,
        'objects': globalLayer['objects'],
      });
    }

    final globalObjects = getObjects(canonicalName, mapContext: null);
    final mapObjects = getObjects(canonicalName, mapContext: mapContext);

    for (var obj in globalObjects) {
      if (!_containsObject(mapObjects, obj)) {
        mapObjects.add(Map<String, dynamic>.from(obj));
      }
    }
    _updateLayerCount(canonicalName, mapContext);
  }

  static void removeObjectCrossContext(
    String layerName,
    Map<String, dynamic> object, {
    String? currentContext,
  }) {
    final canonicalName = _getCanonicalLayerName(layerName);
    if (currentContext != null) {
      // Eliminar del mapa actual
      final mapObjects = getObjects(canonicalName, mapContext: currentContext);
      mapObjects.removeWhere(
        (item) => item['name'] == object['name'] && item['value'] == object['value'],
      );
      _updateLayerCount(canonicalName, currentContext);

      // Eliminar también del menú global
      final globalObjects = getObjects(canonicalName, mapContext: null);
      globalObjects.removeWhere(
        (item) => item['name'] == object['name'] && item['value'] == object['value'],
      );
      _updateLayerCount(canonicalName, null);
    } else {
      // Eliminar del menú global
      final globalObjects = getObjects(canonicalName, mapContext: null);
      globalObjects.removeWhere(
        (item) => item['name'] == object['name'] && item['value'] == object['value'],
      );
      _updateLayerCount(canonicalName, null);

      // Eliminar de TODOS los mapas
      for (var contextKey in mapLayers.keys) {
        final mapObjects = getObjects(canonicalName, mapContext: contextKey);
        mapObjects.removeWhere(
          (item) => item['name'] == object['name'] && item['value'] == object['value'],
        );
        _updateLayerCount(canonicalName, contextKey);
      }
    }
  }

  static void synchronizeLayers(String layerName, {String? mapContext}) {
    final canonicalName = _getCanonicalLayerName(layerName);
    final List<Map<String, dynamic>> unionObjects = [];

    void addUniqueObjects(List<Map<String, dynamic>> sourceList) {
      for (var obj in sourceList) {
        if (!unionObjects.any(
          (item) => item['name'] == obj['name'] && item['value'] == obj['value'],
        )) {
          unionObjects.add(Map<String, dynamic>.from(obj));
        }
      }
    }

    // 1. Obtener objetos de la capa global
    final globalObjects = getObjects(canonicalName, mapContext: null);
    addUniqueObjects(globalObjects);

    if (mapContext != null) {
      // 2. Si estamos en el contexto de un mapa, obtener objetos de este mapa
      final mapObjects = getObjects(canonicalName, mapContext: mapContext);
      addUniqueObjects(mapObjects);

      // 3. Escribir la unión de vuelta en ambos
      globalObjects.clear();
      globalObjects.addAll(unionObjects.map((o) => Map<String, dynamic>.from(o)));
      _updateLayerCount(canonicalName, null);

      mapObjects.clear();
      mapObjects.addAll(unionObjects.map((o) => Map<String, dynamic>.from(o)));
      _updateLayerCount(canonicalName, mapContext);
    } else {
      // 2. Si estamos en el menú global, obtener objetos de TODOS los mapas
      for (var contextKey in mapLayers.keys) {
        final mapObjects = getObjects(canonicalName, mapContext: contextKey);
        addUniqueObjects(mapObjects);
      }

      // 3. Escribir la unión de vuelta en el global
      globalObjects.clear();
      globalObjects.addAll(unionObjects.map((o) => Map<String, dynamic>.from(o)));
      _updateLayerCount(canonicalName, null);

      // 4. Escribir la unión de vuelta en todos los mapas que ya tienen esa capa
      for (var contextKey in mapLayers.keys) {
        final currentMapLayers = mapLayers[contextKey]!;
        if (currentMapLayers.any((l) => l['title'].toString().toLowerCase() == canonicalName.toLowerCase())) {
          final mapObjects = getObjects(canonicalName, mapContext: contextKey);
          mapObjects.clear();
          mapObjects.addAll(unionObjects.map((o) => Map<String, dynamic>.from(o)));
          _updateLayerCount(canonicalName, contextKey);
        }
      }
    }
  }

  // --- MÉTODOS DE APOYO PARA SINCRONIZACIÓN ---

  static bool _containsObject(
    List<Map<String, dynamic>> list,
    Map<String, dynamic> obj,
  ) {
    return list.any(
      (item) => item['name'] == obj['name'] && item['value'] == obj['value'],
    );
  }

  static void _updateLayerCount(String layerName, String? mapContext) {
    final canonicalName = _getCanonicalLayerName(layerName);
    final layersList = getLayers(mapContext);
    final layerIndex = layersList.indexWhere((l) => l['title'].toString().toLowerCase() == canonicalName.toLowerCase());
    if (layerIndex != -1) {
      final objects = getObjects(canonicalName, mapContext: mapContext);
      layersList[layerIndex]['objects'] = objects.length;
    }
  }
}
