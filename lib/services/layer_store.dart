import 'package:flutter/material.dart';

class LayerStore {
  // Lista global de capas
  static List<Map<String, dynamic>> layers = [];
  
  // Mapa global de objetos por capa: { 'NombreCapa': [lista de objetos] }
  static Map<String, List<Map<String, dynamic>>> layerObjects = {};

  // Inicializa una capa en el almacén de objetos si no existe
  static void initializeLayer(String layerName) {
    if (!layerObjects.containsKey(layerName)) {
      layerObjects[layerName] = [];
    }
  }

  // Añade un objeto a una capa específica
  static void addObject(String layerName, Map<String, dynamic> object) {
    initializeLayer(layerName);
    layerObjects[layerName]!.insert(0, object);
    _updateLayerCount(layerName);
  }

  // Elimina un objeto de una capa
  static void removeObject(String layerName, int index) {
    if (layerObjects.containsKey(layerName)) {
      layerObjects[layerName]!.removeAt(index);
      _updateLayerCount(layerName);
    }
  }

  // Duplica un objeto con numeración inteligente
  static void duplicateObject(String layerName, int index) {
    if (layerObjects.containsKey(layerName)) {
      final original = layerObjects[layerName]![index];
      final copy = Map<String, dynamic>.from(original);
      String baseName = original['name'];
      
      // Regex para buscar si ya termina en (copia) o (copia N)
      final regex = RegExp(r' \(copia( (\d+))?\)$');
      final match = regex.firstMatch(baseName);

      if (match != null) {
        // Si ya es una copia, extraemos el nombre base
        baseName = baseName.substring(0, match.start);
        
        // Buscamos cuántas copias existen ya de ese baseName para poner el siguiente número
        int nextNum = 1;
        for (var obj in layerObjects[layerName]!) {
          final m = regex.firstMatch(obj['name']);
          if (m != null && obj['name'].startsWith(baseName)) {
            final numStr = m.group(2);
            int currentNum = numStr != null ? int.parse(numStr) : 1;
            if (currentNum >= nextNum) nextNum = currentNum + 1;
          }
        }
        copy['name'] = '$baseName (copia $nextNum)';
      } else {
        copy['name'] = '$baseName (copia)';
      }

      layerObjects[layerName]!.insert(index + 1, copy);
      _updateLayerCount(layerName);
    }
  }

  // Mueve (copia) un objeto a otra capa
  static void copyObjectToLayer(String layerName, int index, String targetLayer) {
    if (layerObjects.containsKey(layerName)) {
      final object = layerObjects[layerName]![index];
      addObject(targetLayer, Map<String, dynamic>.from(object));
    }
  }

  // Actualiza el contador de objetos en la lista de capas principal
  static void _updateLayerCount(String layerName) {
    final layerIndex = layers.indexWhere((l) => l['title'] == layerName);
    if (layerIndex != -1) {
      layers[layerIndex]['objects'] = layerObjects[layerName]?.length ?? 0;
    }
  }
}
