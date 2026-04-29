# NAVIMAP 🛰️📐

**NAVIMAP** es una aplicación GIS (Sistema de Información Geográfica) de alto rendimiento desarrollada en Flutter, diseñada para la gestión táctica de mapas y capas geográficas en entornos de precisión.

## 🚀 Características Principales

### 🗺️ Gestión de Mapas
* **Carga Dinámica**: Soporte para importación de mapas en formato PDF.
* **Miniaturas en Tiempo Real**: Generación automática de vistas previas de los mapas cargados.
* **Estado Espacial**: Indicadores visuales sobre si el usuario se encuentra dentro o fuera del área del mapa.

### 📚 Biblioteca de Capas
* **Organización Estructural**: Sistema de capas independientes con conteo automático de objetos.
* **Operaciones Avanzadas**: Creación, renombrado, eliminación y exportación de capas.
* **Seguridad de Datos**: Validación de nombres únicos para evitar conflictos de información.

### 📐 Gestión de Objetos Geográficos
* **Tipos de Entidades**:
    * **Puntos**: Visualización de coordenadas exactas (Lat/Lon).
    * **Líneas**: Medición automática de longitud en metros.
    * **Polígonos**: Cálculo de área en metros cuadrados (m²).
* **Acciones Inteligentes**:
    * **Búsqueda**: Filtrado en tiempo real de objetos dentro de una capa.
    * **Duplicación**: Sistema de copia con numeración inteligente (ej. "Objeto (copia 2)").
    * **Movilidad**: Capacidad de copiar objetos entre diferentes capas del sistema.

## 🎨 Diseño y UX
* **Estética Táctica**: Interfaz en modo oscuro (Dark Mode) diseñada para reducir la fatiga visual en campo.
* **Minimalismo Funcional**: Eliminación de barras de scroll intrusivas y efectos de tinte para una visualización limpia.
* **Navegación Fluida**: Transiciones optimizadas entre la biblioteca de mapas y el detalle de objetos.

## 🛠️ Tecnologías Utilizadas
* **Lenguaje**: Dart
* **Framework**: Flutter (Web/Mobile)
* **Persistencia**: `LayerStore` - Sistema centralizado para gestión de estado de sesión.
* **Iconografía**: Google Fonts & Material Design Icons.

## ⚙️ Instalación y Ejecución

1. **Prerrequisitos**:
   * Flutter SDK instalado.
   * Navegador Chrome (para versión web).

2. **Ejecución**:
   ```powershell
   # Clonar el repositorio
   git clone https://github.com/gaminuma06/NAVIMAP.git
   
   # Obtener dependencias
   flutter pub get
   
   # Ejecutar en Chrome
   flutter run -d chrome
   ```

## 🏗️ Estructura del Proyecto
* `lib/screens/`: Pantallas principales (Biblioteca, Objetos, Ajustes).
* `lib/services/`: Lógica de persistencia y manejo de datos geográficos.
* `lib/widgets/`: Componentes reutilizables de UI (Tarjetas de mapas, capas y objetos).
* `lib/theme/`: Definición del sistema de diseño (Colores, tipografías, radios).

---
Desarrollado con precisión para profesionales del área geográfica. 🌎🛰️
