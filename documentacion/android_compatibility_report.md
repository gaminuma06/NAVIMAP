# Informe de Compatibilidad y Diagnóstico para Android - NaviMap

Este informe detalla el análisis de compatibilidad de la aplicación **NaviMap** al ser compilada y ejecutada en dispositivos móviles con el sistema operativo **Android**.

---

## 1. Tabla de Compatibilidad por Funcionalidad

| Funcionalidad | Estado de Compatibilidad | Detalle y Funcionamiento en Android |
| :--- | :--- | :--- |
| **Visualización del Mapa Satelital** | **100% Compatible** | Utiliza `flutter_map` (v7.0.2). En Android, el mapa se dibuja nativamente con Skia/Impeller, ofreciendo mayor fluidez que en la Web. Bypassa por completo cualquier problema de CORS en la descarga de mapas en línea. |
| **Mapas Offline (Descarga y Almacenamiento)** | **100% Compatible** | Utiliza `path_provider` para resolver la ruta local segura de la app. Los archivos de las teselas se descargan mediante `HttpClient` en el directorio seguro `/data/user/0/com.navimap.app/app_flutter/offline_tiles/`. |
| **Visualización y Carga de GeoPDF** | **100% Compatible** | La librería `pdfx` (v2.9.2) funciona nativamente en Android utilizando la API `PdfRenderer` interna del SDK de Android. Esto asegura una generación rápida de miniaturas de páginas PDF de forma nativa sin lags. |
| **Extracción y Calibración de Metadatos** | **100% Compatible** | El parser de coordenadas georreferenciadas es código puramente escrito en Dart (`dart:convert`, `dart:io` y `zlib`), lo que garantiza que se ejecutará exactamente igual y a máxima velocidad en cualquier CPU Android (ARM64/x86_64). |
| **Sensor de GPS Real** | **100% Compatible** | Utiliza la librería `geolocator`. En Android, se comunica nativamente con el `FusedLocationProviderClient` de los servicios de Google Play o con el proveedor de GPS del sistema de manera automática. |
| **Sensor de Brújula / Dirección** | **100% Compatible** | Utiliza `flutter_compass`. En Android, consulta directamente el sensor magnético (magnetómetro) y el acelerómetro del hardware del celular para calcular la orientación del usuario con precisión. |
| **Importación de Archivos Locales** | **100% Compatible** | Utiliza `file_picker` para buscar PDFs. En Android se integra directamente con el Explorador de Archivos Nativo de Android (Storage Access Framework) para seleccionar el archivo. |
| **Compartir Mapas** | **100% Compatible** | Utiliza `share_plus`. Invoca el "Android Share Sheet" nativo para compartir el archivo PDF con otras aplicaciones instaladas (WhatsApp, Gmail, Drive, etc.). |

---

## 2. Ajuste Obligatorio Requerido (Acción Requerida antes de compilar)

Al revisar el archivo [AndroidManifest.xml](file:///d:/proyectos_gis/NAVIMAP/android/app/src/main/AndroidManifest.xml), se identificó que **no están declarados los permisos del sistema** requeridos por las librerías nativas. 

> [!WARNING]
> Si compilas la aplicación en modo `release` sin estos permisos, el mapa no cargará en línea (por falta de permiso de Internet) y el rastreo de ubicación GPS fallará o colgará la app (por falta de permisos de localización).

### Modificación Recomendada en el Manifest
Debes abrir el archivo [AndroidManifest.xml](file:///d:/proyectos_gis/NAVIMAP/android/app/src/main/AndroidManifest.xml) y agregar las siguientes líneas justo antes de la etiqueta `<application>` (alrededor de la línea 2):

```xml
    <!-- Permiso básico para que la app se conecte a Internet y descargue mapas -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Permisos requeridos para consultar el chip GPS del dispositivo -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

---

## 3. Consideraciones Finales de Compilación
* **Compatibilidad de API de Android**: Las librerías utilizadas exigen un SDK mínimo de Android 21 (Android 5.0 Lollipop). El archivo de gradle del proyecto (`build.gradle.kts`) ya está configurado para heredar automáticamente la configuración recomendada de Flutter.
* **Manejo de Permisos en Caliente**: En el código de Dart ya implementamos una solicitud proactiva de permisos (`Geolocator.requestPermission()`). Al entrar al mapa por primera vez en Android, el sistema operativo le mostrará al usuario una ventana flotante para "Permitir que NaviMap acceda a la ubicación del dispositivo", cumpliendo al 100% con los estándares de diseño de Android.
