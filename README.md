# NAVIMAP 🛰️📐

**NAVIMAP** es una solución GIS (Sistema de Información Geográfica) de vanguardia desarrollada en Flutter, diseñada específicamente para profesionales que requieren una gestión táctica, precisa y redundante de datos geográficos en tiempo real.

## 🚀 Innovaciones y Capacidades Tácticas

### 🔄 Motor de Sincronización Bi-direccional en Cascada
NAVIMAP integra una arquitectura de datos "Shadow Sync" que garantiza la integridad total de la información:
* **Respaldo Maestro Inteligente**: El Menú Capa Principal actúa como una caja fuerte global. Cualquier objeto creado o modificado en un mapa se replica instantáneamente en el respaldo global.
* **Sincronización en Cascada**: Las modificaciones en la biblioteca global se propagan automáticamente a todos los mapas que contienen esas capas, manteniendo la coherencia operativa en todo momento.
* **Independencia Estructural**: Eliminar una capa de un mapa específico no afecta al respaldo global, permitiendo una limpieza táctica de la vista de trabajo sin pérdida de datos históricos.

### 📚 Gestión Avanzada de Bibliotecas
* **Multi-Mapa Independiente**: Cada proyecto cartográfico posee su propia biblioteca de capas local.
* **Importación Inteligente**: Sistema de selección múltiple (checkbox) para traer capas y objetos desde el respaldo global hacia mapas específicos en segundos.
* **Mover es Copiar**: Filosofía de despliegue múltiple donde mover un objeto entre capas genera una replicación estratégica, permitiendo que la información coexista en diferentes contextos sin destruir el original.

### 🎯 Interfaz de Precisión Quirúrgica
* **Mira de Precisión**: Retícula central permanente para la captura exacta de coordenadas y alineación de activos sobre el terreno.
* **UI de Alto Contraste**: Tema oscuro (Dark Mode) optimizado para operaciones en campo con luz solar intensa o baja luminosidad.
* **Estados Vacíos Profesionales**: Implementación de `DottedBorder` para guiar al usuario en la carga de datos, eliminando la ambigüedad visual.

### 🛡️ Blindaje y Seguridad de Datos
* **Diálogos de Confirmación**: Sistema de verificación triple para la eliminación de capas, objetos y mapas, asegurando que ninguna acción crítica sea accidental.
* **Guardia de Duplicados**: Algoritmo inteligente que evita la repetición de objetos durante los procesos de sincronización masiva.

## 🛠️ Stack Tecnológico
* **Core**: Flutter / Dart.
* **Visualización**: `pdfx` para renderizado de mapas PDF de alta fidelidad.
* **Motor de Datos**: `LayerStore` - Motor customizado para persistencia reactiva y sincronización bi-direccional.
* **Estética**: Design System personalizado con tokens de diseño premium.

## ⚙️ Instalación y Despliegue

1. **Prerrequisitos**: Flutter SDK instalado y entorno Chrome para visualización web.
2. **Setup**:
   ```powershell
   git clone https://github.com/gaminuma06/NAVIMAP.git
   cd NAVIMAP
   flutter pub get
   flutter run -d chrome
   ```

## 🏗️ Estructura de Misión
* `lib/services/layer_store.dart`: Corazón del sistema de sincronización y respaldo.
* `lib/screens/map_detail_screen.dart`: Visor cartográfico con retícula de precisión.
* `lib/screens/map_layer_library_screen.dart`: Gestión de capas locales e importación masiva.
* `lib/theme/design_system.dart`: Definición de la identidad visual táctica.

---
**NAVIMAP** - Precisión sin límites para el análisis geográfico profesional. 🌎🛰️
