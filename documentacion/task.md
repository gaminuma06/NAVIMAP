# Tareas: Limitaciones del Plan Free, Tarjeta de Bienvenida y Robustez en GeoPDF

- [x] **Fase 1: Robustez en la Importación de GeoPDFs**
  - [x] Envolver lectura de archivos y renderizado en `add_map_overlay.dart` en `try-catch` y mostrar feedback visual en caso de error.
  - [x] Modificar `georeference_service.dart` para usar `latin1.decode` en la decodificación de texto y envolver `_extractCalibrationFromPdf` en un bloque `try-catch` completo.
  - [x] Asegurar la limpieza y remoción del estado `_loadingMaps` en `library_screen.dart` usando un bloque `finally` para evitar la carga infinita en la UI en caso de error.

- [x] **Fase 2: Lógica y Visualización de Límite de Mapas (Plan Gratuito)**
  - [x] Registrar la propiedad cronológica `addedAt` (timestamp) al insertar nuevos mapas en `library_screen.dart`.
  - [x] Implementar el helper `_isMapEnabled(map, isPro)` y adaptar `_filteredMaps` para reordenar y colocar los 3 mapas habilitados al principio en modo Free.
  - [x] Modificar `map_detail_screen.dart` para deshabilitar botones de GPS, marcador, medición y capas en mapas bloqueados, además de ocultar la ubicación del usuario y mostrar `"COORDENADAS BLOQUEADAS (PRO)"` en la mira e inferior.

- [x] **Fase 3: Límite de Objetos en la Vista Satelital**
  - [x] Implementar la función de conteo de objetos para el contexto `'satellite'` en `satellite_view_screen.dart`.
  - [x] Restringir la adición de nuevos pines, líneas y polígonos si el usuario es Free y ya tiene 3 o más objetos creados en satélite.

- [x] **Fase 4: Tarjeta de Celebración de Suscripción Premium**
  - [x] Modificar `subscription_service.dart` para interceptar la transición de Free a Pro/HLG y establecer la bandera de celebración pendiente.
  - [x] Crear el diálogo premium flotante en `library_screen.dart` con el diseño verde esmeralda (HLG) y dorado (Pro), disparándolo exactamente una vez al detectar la transición de plan.
