# NAVIMAP 🛰️📐

**NAVIMAP** es una solución GIS (Sistema de Información Geográfica) de vanguardia desarrollada en Flutter, diseñada específicamente para profesionales que requieren una gestión táctica, precisa y redundante de datos geográficos en tiempo real.

## 🚀 Innovaciones y Capacidades Tácticas

### 🔄 Motor de Sincronización Bi-direccional y Borrado Cruzado
NAVIMAP integra una arquitectura de datos "Shadow Sync" que garantiza la integridad total de la información:
* **Respaldo Maestro Inteligente**: El Menú Capa Principal actúa como una caja fuerte global. Cualquier objeto creado o modificado en un mapa se replica instantáneamente en el respaldo global.
* **Borrado Cruzado Opcional**: Al eliminar un objeto, el sistema ofrece una casilla de confirmación interactiva para decidir si la eliminación debe ser local o propagarse de forma cruzada (eliminando del menú global o de todos los mapas vinculados).
* **Sincronización Proactiva (Botón de Actualización)**: Opción rápida para calcular la unión de objetos sin duplicados entre el mapa y la biblioteca global, alineando ambas listas de forma inmediata.
* **Consistencia Case-Insensitive**: Resolución automática mediante nombres canónicos para evitar discrepancias en la sincronización causadas por diferencias de mayúsculas/minúsculas.

### 🎨 Edición de Atributos y Colores Dinámicos
* **Ventana de Atributos Detallados**: Acceso directo al tocar cualquier objeto para modificar su nombre y coordenadas (mediante campos individuales de latitud y longitud).
* **Colores Tácticos del Pin**: Selector rápido de 6 colores (Rojo, Azul, Verde, Amarillo, Naranja, Morado) que actualiza dinámicamente tanto el marcador en el mapa como el icono representativo en la tarjeta del listado.
* **Fechas de Creación e Historial de Edición**: Fecha automática e inmutable que se actualiza únicamente si el usuario realiza modificaciones a las coordenadas del objeto.

### 📚 Gestión Avanzada de Bibliotecas y Capa Activa
* **Destacado de Capa Activa**: La capa actualmente activa en el mapa se resalta visualmente con un contorno verde y el texto de estado "Capa activa", mientras que las inactivas ocultan sus subtítulos para una interfaz más despejada.
* **Reordenamiento Dinámico**: La capa seleccionada como activa se sitúa automáticamente al principio de la lista de capas para agilizar el acceso operativo.
* **Activación desde Menú de Opciones**: Acceso directo para activar capas directamente desde su menú contextual de tres puntos, evitando pasos adicionales.


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
