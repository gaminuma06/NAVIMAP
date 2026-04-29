import 'package:flutter/material.dart';

class LayerStore {
  // --- BIBLIOTECA GENERAL (RESPALDO MAESTRO) ---
  static List<Map<String, dynamic>> layers = [];

  // --- BIBLIOTECAS POR MAPA ---
  static Map<String, List<Map<String, dynamic>>> mapLayers = {};
  
  // ALMACENAMIENTO UNIFICADO DE OBJETOS
  static Map<String, List<Map<String, dynamic>>> mapLayerObjects = {};

  // Obtiene las capas según el contexto (Global o Mapa)
  static List<Map<String, dynamic>> getLayers(String? mapContext) {
    if (mapContext == null) return layers;
    if (!mapLayers.containsKey(mapContext)) {
      mapLayers[mapContext] = [];
    }
    return mapLayers[mapContext]!;
  }

  // Obtiene los objetos de forma SEGURA
  static List<Map<String, dynamic>> getObjects(String layerName, {String? mapContext}) {
    final key = mapContext == null ? layerName : '${mapContext}_$layerName';
    if (!mapLayerObjects.containsKey(key)) {
      mapLayerObjects[key] = [];
    }
    return mapLayerObjects[key]!;
  }

  static void initializeLayer(String layerName, {String? mapContext}) {
    final key = mapContext != null ? '${mapContext}_$layerName' : layerName;
    if (!mapLayerObjects.containsKey(key)) {
      mapLayerObjects[key] = [];
    }

    // Asegurar que exista en el RESPALDO GLOBAL
    if (!layers.any((l) => l['title'].toString().toLowerCase() == layerName.toLowerCase())) {
      layers.insert(0, {'title': layerName, 'objects': 0});
      if (!mapLayerObjects.containsKey(layerName)) {
        mapLayerObjects[layerName] = [];
      }
    }
  }

  static void addObject(String layerName, Map<String, dynamic> object, {String? mapContext, bool isSyncCall = false}) {
    initializeLayer(layerName, mapContext: mapContext);
    final objects = getObjects(layerName, mapContext: mapContext);
    
    // Evitar duplicados exactos
    if (!_containsObject(objects, object)) {
      objects.insert(0, object);
      _updateLayerCount(layerName, mapContext);
    }

    // BREAK: Si es una llamada de sincronización, no propagar más para evitar bucles
    if (isSyncCall) return;

    if (mapContext != null) {
      // Sincronización HACIA ARRIBA (Mapa -> Global) con bandera de seguridad
      addObject(layerName, object, mapContext: null, isSyncCall: true);
    } else {
      // Sincronización HACIA ABAJO (Global -> Todos los mapas) con bandera de seguridad
      for (var contextKey in mapLayers.keys) {
        final currentMapLayers = mapLayers[contextKey]!;
        if (currentMapLayers.any((l) => l['title'] == layerName)) {
          addObject(layerName, Map<String, dynamic>.from(object), mapContext: contextKey, isSyncCall: true);
        }
      }
    }
  }

  static void removeObject(String layerName, int index, {String? mapContext, bool isSyncCall = false}) {
    final objects = getObjects(layerName, mapContext: mapContext);
    if (index < objects.length) {
      final objectToRemove = objects[index];
      objects.removeAt(index);
      _updateLayerCount(layerName, mapContext);

      // BREAK: Evitar bucle infinito
      if (isSyncCall) return;

      if (mapContext != null) {
        // Sincronización HACIA ARRIBA
        final globalObjects = getObjects(layerName, mapContext: null);
        _removeObjectFromList(globalObjects, objectToRemove);
        _updateLayerCount(layerName, null);
      } else {
        // Sincronización HACIA ABAJO
        for (var contextKey in mapLayers.keys) {
          final mapObjects = getObjects(layerName, mapContext: contextKey);
          _removeObjectFromList(mapObjects, objectToRemove);
          _updateLayerCount(layerName, contextKey);
        }
      }
    }
  }

  static void duplicateObject(String layerName, int index, {String? mapContext}) {
    final objects = getObjects(layerName, mapContext: mapContext);
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
      addObject(layerName, copy, mapContext: mapContext);
    }
  }

  static void copyObjectToLayer(String fromLayer, int index, String toLayer, {String? mapContext}) {
    final objects = getObjects(fromLayer, mapContext: mapContext);
    if (objects.length > index) {
      final objectToCopy = Map<String, dynamic>.from(objects[index]);
      addObject(toLayer, objectToCopy, mapContext: mapContext);
    }
  }

  static void importLayerWithObjects(String layerName, String mapContext) {
    initializeLayer(layerName, mapContext: mapContext);
    
    final currentMapLayers = getLayers(mapContext);
    if (!currentMapLayers.any((l) => l['title'] == layerName)) {
      final globalLayer = layers.firstWhere((l) => l['title'] == layerName);
      currentMapLayers.add({'title': layerName, 'objects': globalLayer['objects']});
    }

    final globalObjects = getObjects(layerName, mapContext: null);
    final mapObjects = getObjects(layerName, mapContext: mapContext);
    
    for (var obj in globalObjects) {
      if (!_containsObject(mapObjects, obj)) {
        mapObjects.add(Map<String, dynamic>.from(obj));
      }
    }
    _updateLayerCount(layerName, mapContext);
  }

  // --- MÉTODOS DE APOYO PARA SINCRONIZACIÓN ---

  static bool _containsObject(List<Map<String, dynamic>> list, Map<String, dynamic> obj) {
    return list.any((item) => 
      item['name'] == obj['name'] && item['value'] == obj['value']
    );
  }

  static void _removeObjectFromList(List<Map<String, dynamic>> list, Map<String, dynamic> obj) {
    list.removeWhere((item) => 
      item['name'] == obj['name'] && item['value'] == obj['value']
    );
  }

  static void _updateLayerCount(String layerName, String? mapContext) {
    final layersList = getLayers(mapContext);
    final layerIndex = layersList.indexWhere((l) => l['title'] == layerName);
    if (layerIndex != -1) {
      final objects = getObjects(layerName, mapContext: mapContext);
      layersList[layerIndex]['objects'] = objects.length;
    }
  }
}
