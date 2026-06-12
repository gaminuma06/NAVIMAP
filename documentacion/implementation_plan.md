# Plan de Implementación: Reestructuración de Limitaciones, Tarjeta de Bienvenida y Robustez en GeoPDF

Este plan detalla los cambios para rediseñar las restricciones del plan gratuito (Free), añadir limitaciones de dibujo en la vista Satelital, mostrar una tarjeta flotante de bienvenida premium y resolver los fallos intermitentes al adjuntar archivos GeoPDF.

---

## User Review Required

> [!IMPORTANT]
> - **Cambio de Regla en Mapas Gratuitos:** En lugar de bloquear la importación después de 3 mapas, el usuario podrá agregar mapas ilimitados. Sin embargo, el GPS, las coordenadas de la mira y la creación de capas/objetos solo estarán activos en los **primeros 3 mapas agregados cronológicamente** (antiguos primero). Los mapas 4 en adelante tendrán las herramientas bloqueadas y mostrarán una advertencia para pasarse a Pro/HLG.
> - **Sincronización al Eliminar:** Si el usuario tiene 4 mapas y elimina uno de los 3 primeros habilitados, el 4º mapa pasará a estar activo de manera automática e inmediata (promoción por orden cronológico).
> - **Límite en Vista Satelital:** En modo gratuito, el usuario solo podrá guardar hasta **3 objetos** en total (puntos, líneas o polígonos). Al intentar agregar un cuarto objeto, se bloqueará y se le invitará a actualizarse a Pro/HLG.
> - **Tarjeta de Celebración y Bienvenida Única:** Se presentará una tarjeta flotante premium con un look festivo al cambiar del plan gratuito a Pro (dorado lujoso) o HLG (verde esmeralda brillante). Esta tarjeta se mostrará **una sola vez por activación** y se podrá cerrar mediante un botón.

---

## Proposed Changes

### 1. Robustez en la Selección e Importación de GeoPDFs (Solución a Fallos Intermitentes)
#### [MODIFY] [add_map_overlay.dart](file:///d:/proyectos_gis/NAVIMAP/lib/screens/add_map_overlay.dart)
- Envolver todo el proceso de lectura de archivos (`readAsBytes()`) y renderizado de la primera página en un bloque `try-catch` robusto.
- Si la lectura de bytes falla (como ocurre en Android con rutas virtuales de Google Drive o OneDrive) o si el PDF está protegido o corrupto, capturar el error y mostrar un aviso visual (`SnackBar` o diálogo de error) en lugar de fallar silenciosamente.

#### [MODIFY] [georeference_service.dart](file:///d:/proyectos_gis/NAVIMAP/lib/services/georeference_service.dart)
- Modificar el escaneo de metadatos reemplazando la decodificación pesada `String.fromCharCodes(bytes)` por `latin1.decode(bytes, allowInvalid: true)`. Esto evita desbordamientos de memoria en navegadores web y dispositivos móviles para PDFs de gran tamaño.
- Envolver toda la función `_extractCalibrationFromPdf` en un bloque `try-catch` global para asegurar que no se produzcan excepciones no controladas.

#### [MODIFY] [library_screen.dart](file:///d:/proyectos_gis/NAVIMAP/lib/screens/library_screen.dart) (Sección Importación)
- Envolver la carga de metadatos dentro de `onMapAdded` en un `try-catch`.
- Garantizar que la remoción de la lista de carga `_loadingMaps.remove(name)` se ejecute siempre (utilizando un bloque `finally`), evitando que la tarjeta quede en bucle de carga si ocurre un error.

---

### 2. Lógica y Visualización del Límite de Mapas (Plan Gratuito)
#### [MODIFY] [library_screen.dart](file:///d:/proyectos_gis/NAVIMAP/lib/screens/library_screen.dart) (Sección Límite & Listado)
- **Eliminar el bloqueo de importación:** Quitar la comprobación que impide añadir más de 3 mapas.
- **Timestamp de Adición:** Registrar `'addedAt': DateTime.now().millisecondsSinceEpoch` en cada mapa insertado para rastrear el orden cronológico original.
- **Helper de Habilitación:** Crear el método `_isMapEnabled(map, isPro)` que determine si un mapa pertenece a los primeros 3 basándose en `addedAt` ascendente.
- **Reordenamiento de Lista:** En el getter `_filteredMaps`, si el usuario está en plan gratuito, ordenar la lista para colocar los 3 mapas habilitados al principio, seguidos de los mapas bloqueados (con un indicador visual como un candado o un texto descriptivo de "Requiere Pro").

#### [MODIFY] [map_detail_screen.dart](file:///d:/proyectos_gis/NAVIMAP/lib/screens/map_detail_screen.dart) (Herramientas Bloqueadas)
- Implementar la lógica para comprobar si el mapa actual está habilitado usando el mismo criterio cronológico.
- Si el mapa actual está **bloqueado**:
  - Desactivar los botones de **GPS/Centrado**, **Añadir Marcador**, **Modo Medición (Regla)** y **Gestor de Capas**. Al hacer clic en ellos, mostrar el diálogo de invitación a NAVIMAP Pro.
  - En la barra de coordenadas inferior, en lugar de mostrar las coordenadas reales de la mira, mostrar el texto `"COORDENADAS BLOQUEADAS (PRO)"` en rojo. Bloquear también la copia de coordenadas al portapapeles y el selector de formatos, redirigiendo al diálogo Pro.
  - Ocultar el marcador de ubicación del usuario (GPS) sobre el mapa.

---

### 3. Límite de Objetos en la Vista Satelital
#### [MODIFY] [satellite_view_screen.dart](file:///d:/proyectos_gis/NAVIMAP/lib/screens/satellite_view_screen.dart)
- Crear una función para contar todos los objetos agregados en el contexto de la vista satelital (sumando la cantidad de elementos en todas las capas asociadas a `'satellite'`).
- En las acciones `_handlePlacePin`, `_saveMeasuringLine` y `_saveMeasuringPolygon`, si el usuario es gratuito y el conteo de objetos es `>= 3`, abortar el flujo antes de abrir el diálogo de nombres y presentar la invitación a NAVIMAP Pro.

---

### 4. Tarjeta Flotante de Bienvenida / Celebración Premium
#### [MODIFY] [subscription_service.dart](file:///d:/proyectos_gis/NAVIMAP/lib/services/subscription_service.dart)
- Añadir campos para detectar la transición del plan de `'free'` a `'pro'` o `'hlg'`.
- Establecer una bandera `_celebrationPending = true` únicamente al detectar este cambio, de modo que si el usuario ya inicia sesión con el plan Pro/HLG cargado no se le muestre repetidamente, sino únicamente al pasar de Free a Pro/HLG.

#### [MODIFY] [library_screen.dart](file:///d:/proyectos_gis/NAVIMAP/lib/screens/library_screen.dart) (Diálogo de Bienvenida)
- Añadir un listener al inicializar que observe `SubscriptionService().planNotifier`.
- Al detectar la bandera de celebración pendiente, limpiar el estado e invocar una tarjeta flotante (`showDialog` personalizado de alta estética):
  - **HLG (Corporate):** Diseño premium color **verde esmeralda brillante** (`Color(0xFF00E676)`) con detalles de lujo, icono de bienvenida y mensaje corporativo festivo.
  - **PRO:** Diseño premium color **dorado brillante tipo oro** (`Color(0xFFFFD700)`) con micro-animaciones, sombras y mensaje de felicitación exclusivo.
  - Ambas tarjetas contarán con un botón de cierre ("Comenzar" o icono de cruz) de alta fidelidad.

---

## Verification Plan

### Manual Verification
1. **Verificación de Carga GeoPDF:** Subir un PDF normal, un GeoPDF y verificar que el decodificador `latin1` procese los archivos grandes sin problemas de rendimiento.
2. **Prueba de Límite y Reordenamiento:** Subir 5 GeoPDFs en el plan gratuito. Verificar que:
   - Los primeros 3 subidos aparezcan arriba con el GPS y las herramientas activas.
   - Los mapas 4 y 5 aparezcan abajo marcados con un candado y sus herramientas no respondan (lanzando el popup Pro).
   - Al eliminar el mapa 2, el mapa 4 suba de posición y se active de inmediato.
3. **Prueba de Límite Satelital:** Dibujar 3 marcadores en la vista satelital (plan gratuito) y comprobar que el 4º se bloquee.
4. **Prueba de Celebración:** Cambiar el plan en Firestore de `'free'` a `'pro'` y luego a `'hlg'`. Verificar que la tarjeta flotante aparezca con el color correspondiente (dorado para Pro, verde esmeralda para HLG) y se cierre correctamente.
