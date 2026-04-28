---
name: Technical Mapping System
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#bacbb9'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#859585'
  outline-variant: '#3b4a3d'
  surface-tint: '#00e475'
  primary: '#75ff9e'
  on-primary: '#003918'
  primary-container: '#00e676'
  on-primary-container: '#00612e'
  inverse-primary: '#006d35'
  secondary: '#b0c6ff'
  on-secondary: '#002d6e'
  secondary-container: '#0068ed'
  on-secondary-container: '#f2f3ff'
  tertiary: '#ffddd5'
  on-tertiary: '#621100'
  tertiary-container: '#ffb7a5'
  on-tertiary-container: '#a12300'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#62ff96'
  primary-fixed-dim: '#00e475'
  on-primary-fixed: '#00210b'
  on-primary-fixed-variant: '#005226'
  secondary-fixed: '#d9e2ff'
  secondary-fixed-dim: '#b0c6ff'
  on-secondary-fixed: '#001945'
  on-secondary-fixed-variant: '#00429b'
  tertiary-fixed: '#ffdad2'
  tertiary-fixed-dim: '#ffb4a2'
  on-tertiary-fixed: '#3c0700'
  on-tertiary-fixed-variant: '#8a1d00'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.2'
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.5'
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: '1'
    letterSpacing: 0.05em
  mono-data:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1'
    letterSpacing: -0.02em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 12px
  safe-area: 20px
---

## Brand & Style

The design system is engineered for high-stakes outdoor environments where legibility and precision are paramount. The brand personality is utilitarian, professional, and mission-critical, aimed at field researchers, surveyors, and tactical navigators. 

The aesthetic follows a **Technical Minimalism** style. It prioritizes function over form, utilizing sharp edges, clear hierarchies, and high-contrast accents to ensure the interface remains usable under direct sunlight or in low-light field conditions. The UI evokes the feeling of a precision instrument—reliable, accurate, and unobtrusive—allowing the georeferenced data to remain the focal point of the experience.

## Colors

The color palette is optimized for a dark-mode-first environment to preserve night vision and maximize battery life on mobile devices. 

- **Tactical Green (#00E676):** Used exclusively for primary actions, success states, and active GPS tracking. This high-frequency green ensures immediate recognition against dark map tiles.
- **Navigation Blue (#2979FF):** Reserved for spatial information, including current location markers, breadcrumb trails, and water-related geodata.
- **Alert Orange (#FF3D00):** A tertiary color used sparingly for warnings, out-of-bounds indicators, or critical system errors.
- **Monochrome Base:** The background utilizes a deep "Rich Black" (#0A0A0A) for the base canvas, with "Charcoal" (#1A1A1A) surfaces used to define UI overlays and panels.

## Typography

This design system utilizes a dual-font strategy to balance technical character with extreme readability.

- **Space Grotesk** is used for headlines and telemetry data. Its geometric, technical quirks reinforce the scientific nature of the application while maintaining high visibility.
- **Inter** is used for all functional UI elements, body text, and map labels. Its neutral, systematic design ensures that long strings of coordinate data or layer names remain legible at small sizes.

For coordinate readouts (Lat/Long, UTM), always use the **mono-data** style to prevent character jumping during real-time movement.

## Layout & Spacing

The layout is built on a **4px baseline grid** to ensure precision in small-screen mobile environments. 

- **Map-Centric Fluidity:** The primary canvas is fluid, extending to all edges of the viewport. UI elements exist as floating "modules" or "drawers" rather than fixed structural blocks.
- **Touch Targets:** Despite the technical look, all interactive elements must maintain a minimum 44x44px hit area to account for use with gloves or in motion.
- **Modular Panels:** Sidebars and bottom sheets use a standard 320px or 400px fixed width on larger screens, collapsing into full-width sheets on mobile devices.

## Elevation & Depth

To maintain clarity over complex, high-detail map textures (satellite imagery or topographic lines), this design system uses **Tonal Layering** and **Low-Contrast Outlines** instead of heavy drop shadows.

- **Surface 0 (Base):** The map canvas itself.
- **Surface 1 (Floating Panels):** #1A1A1A with a 1px solid border (#333333). This creates a "cut-out" effect that separates UI from the map background.
- **Overlays:** For critical modals, a 40% black backdrop blur is used to dim the map, focusing the user's attention on the task at hand without losing spatial context.
- **Active State:** Elements being dragged or interacted with receive a subtle glow effect using the Tactical Green or Navigation Blue, rather than a shadow.

## Shapes

The shape language is strictly **Soft (1)**. UI elements use a 4px (0.25rem) corner radius. This choice strikes a balance between the aggressive "sharp" look of traditional military software and the approachability of modern SaaS. 

- **Buttons & Inputs:** 4px radius.
- **Large Cards/Drawers:** 8px (0.5rem) radius for the top corners of bottom sheets.
- **Icon Enclosures:** Small circular or square backgrounds for map tools use the same 4px radius to maintain a cohesive, "blocked" appearance.

## Components

### Buttons & Controls
- **Primary Action:** Solid Tactical Green (#00E676) with black text. High-contrast and impossible to miss.
- **Secondary/Tool:** Charcoal background with a 1px border. Icons are white or Tactical Green when active.
- **Toggle/Switch:** Uses the Navigation Blue for the "on" state to differentiate system settings from map actions.

### Measurement Tools
- **Ruler/Path:** A 2px dashed line in Navigation Blue with white halos for visibility against all terrains.
- **Polygon/Area:** A 10% opacity fill of Navigation Blue with a solid 2px stroke. Vertices are represented by 8px white squares with 1px blue borders.

### Lists & Layer Management
- **Layer Items:** Feature a "visibility" toggle (eye icon) and a "lock" icon. Active layers are indicated by a 4px vertical bar of Tactical Green on the left edge of the list item.
- **Draggable Handles:** Use a 6-dot matrix icon to indicate reordering capabilities for map stacking.

### Icons
- **GPS/Location:** A "crosshair" style icon for precision.
- **Icons:** All icons must use a 2px stroke weight. Avoid filled icons unless indicating an "active" or "selected" state. This maintains the "technical drawing" aesthetic of the design system.