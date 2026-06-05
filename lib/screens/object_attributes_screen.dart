import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/design_system.dart';
import '../services/layer_store.dart';
import '../services/georeference_service.dart';
import '../widgets/object_list_item.dart';

class ObjectAttributesScreen extends StatefulWidget {
  final String layerName;
  final Map<String, dynamic> object;
  final String? mapContext;

  const ObjectAttributesScreen({
    super.key,
    required this.layerName,
    required this.object,
    this.mapContext,
  });

  @override
  State<ObjectAttributesScreen> createState() => _ObjectAttributesScreenState();
}

class _ObjectAttributesScreenState extends State<ObjectAttributesScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _latController;
  late TextEditingController _lonController;
  late int _selectedColor;
  late String _createdAt;
  late String _selectedFormat;
  late double _currentLat;
  late double _currentLon;
  late String _selectedUnit;

  final List<int> _colorOptions = [
    0xFFFF1744, // Rojo
    0xFF2979FF, // Azul
    0xFF00E676, // Verde
    0xFFFFEA00, // Amarillo
    0xFFFFA726, // Naranja Pálido (Avenza)
    0xFFD500F9, // Morado
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.object['name']);
    
    final bool isLine = widget.object['type'] == GeoObjectType.line;
    _currentLat = widget.object['latitude'] as double? ?? 0.0;
    _currentLon = widget.object['longitude'] as double? ?? 0.0;
    
    _latController = TextEditingController();
    _lonController = TextEditingController();
    
    _selectedColor = widget.object['color'] as int? ?? (isLine ? 0xFFFFA726 : 0xFFFF1744);
    _createdAt = widget.object['createdAt'] as String? ?? DateTime.now().toIso8601String();
    _selectedFormat = widget.object['coordinateFormat'] as String? ?? 'DD';
    _selectedUnit = widget.object['unit'] as String? ?? 'm';
    
    if (!isLine) {
      _updateTextFields();
      _latController.addListener(_onCoordsChanged);
      _lonController.addListener(_onCoordsChanged);
    }
  }

  @override
  void dispose() {
    if (widget.object['type'] != GeoObjectType.line) {
      _latController.removeListener(_onCoordsChanged);
      _lonController.removeListener(_onCoordsChanged);
    }
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  void _saveAttributes() {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();

    if (widget.object['type'] == GeoObjectType.line) {
      final points = widget.object['points'] as List? ?? [];
      final double totalLength = _calculateGeodesicLength(points);
      final formattedValue = _formatLengthWithUnit(totalLength, _selectedUnit);

      final updatedObject = {
        'name': newName,
        'type': widget.object['type'],
        'value': formattedValue,
        'points': widget.object['points'],
        'unit': _selectedUnit,
        'color': _selectedColor,
        'createdAt': _createdAt,
      };

      LayerStore.updateObject(
        widget.layerName,
        widget.object,
        updatedObject,
        mapContext: widget.mapContext,
      );

      Navigator.pop(context, true);
      return;
    }

    final newLat = _currentLat;
    final newLon = _currentLon;

    final double originalLat = widget.object['latitude'] as double? ?? 0.0;
    final double originalLon = widget.object['longitude'] as double? ?? 0.0;

    String finalCreatedAt = _createdAt;
    // Si hubo cambio en las coordenadas, se actualiza la fecha a la de esta modificación.
    if (newLat != originalLat || newLon != originalLon) {
      finalCreatedAt = DateTime.now().toIso8601String();
    }

    final updatedObject = {
      'name': newName,
      'type': widget.object['type'],
      'value': 'Lat: ${newLat.toStringAsFixed(6)}, Lon: ${newLon.toStringAsFixed(6)}',
      'latitude': newLat,
      'longitude': newLon,
      'color': _selectedColor,
      'createdAt': finalCreatedAt,
      'coordinateFormat': _selectedFormat,
    };

    LayerStore.updateObject(
      widget.layerName,
      widget.object,
      updatedObject,
      mapContext: widget.mapContext,
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'ATRIBUTOS DEL OBJETO',
          style: DesignSystem.labelCaps.copyWith(color: DesignSystem.primary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignSystem.spacingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INFORMACIÓN GENERAL',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignSystem.spacingMd),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: DesignSystem.primary),
                    borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: DesignSystem.spacingMd),
              if (widget.object['type'] == GeoObjectType.line) ...[
                const Text(
                  'INFORMACIÓN DE MEDIDA',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignSystem.spacingMd),
                Builder(
                  builder: (context) {
                    final points = widget.object['points'] as List? ?? [];
                    final meters = _calculateGeodesicLength(points);
                    final lengthStr = _formatLengthWithUnit(meters, _selectedUnit);
                    return TextFormField(
                      key: ValueKey(lengthStr),
                      initialValue: lengthStr,
                      style: const TextStyle(color: Colors.white70),
                      decoration: InputDecoration(
                        labelText: 'Longitud de la línea',
                        labelStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.02),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                        ),
                      ),
                      readOnly: true,
                    );
                  }
                ),
                const SizedBox(height: DesignSystem.spacingMd),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUnit,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Unidad de medida',
                    labelStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: DesignSystem.primary),
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                    ),
                  ),
                  items: _buildDropdownItems(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedUnit = val;
                      });
                    }
                  },
                ),
              ] else ...[
                const Text(
                  'COORDENADAS TÁCTICAS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignSystem.spacingMd),
                TextFormField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _latLabel,
                    labelStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: DesignSystem.primary),
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                    ),
                  ),
                  readOnly: _currentFormat != 'DD',
                  validator: (value) {
                    if (_currentFormat != 'DD') return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa la latitud';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null) {
                      return 'Ingresa un número decimal válido';
                    }
                    if (parsed < -90 || parsed > 90) {
                      return 'La latitud debe estar entre -90 y 90';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DesignSystem.spacingMd),
                TextFormField(
                  controller: _lonController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _lonLabel,
                    labelStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: DesignSystem.primary),
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                    ),
                  ),
                  readOnly: _currentFormat != 'DD',
                  validator: (value) {
                    if (_currentFormat != 'DD') return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa la longitud';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null) {
                      return 'Ingresa un número decimal válido';
                    }
                    if (parsed < -180 || parsed > 180) {
                      return 'La longitud debe estar entre -180 y 180';
                    }
                    return null;
                  },
                ),
                if (!_isActiveLayer) ...[
                  const SizedBox(height: DesignSystem.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DesignSystem.primary,
                        side: const BorderSide(color: DesignSystem.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                        ),
                      ),
                      onPressed: _showFormatSelector,
                      icon: const Icon(Icons.straighten, size: 18),
                      label: const Text(
                        'CAMBIAR SISTEMA DE COORDENADAS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: DesignSystem.spacingLg),
              const Text(
                'COLOR DEL PIN',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignSystem.spacingMd),
              _buildColorSelector(),
              const SizedBox(height: DesignSystem.spacingLg),
              _buildDateField(),
              const SizedBox(height: DesignSystem.spacingXl),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignSystem.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                    ),
                  ),
                  onPressed: _saveAttributes,
                  child: const Text(
                    'GUARDAR CAMBIOS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _colorOptions.map((colorVal) {
        final isSelected = _selectedColor == colorVal;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = colorVal;
            });
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(colorVal),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 24,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignSystem.spacingMd),
      decoration: BoxDecoration(
        color: DesignSystem.surfaceContainer,
        borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FECHA DE CREACIÓN / ÚLTIMA MODIFICACIÓN',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDateTime(_createdAt),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  bool get _isActiveLayer {
    if (widget.mapContext == null) return false;
    return LayerStore.activeMapLayer[widget.mapContext!] == widget.layerName;
  }

  void _onCoordsChanged() {
    if (_currentFormat == 'DD') {
      final lat = double.tryParse(_latController.text.trim());
      final lon = double.tryParse(_lonController.text.trim());
      if (lat != null) {
        _currentLat = lat;
      }
      if (lon != null) {
        _currentLon = lon;
      }
    }
    setState(() {});
  }

  String get _currentFormat {
    if (_isActiveLayer) {
      if (widget.mapContext != null) {
        return GeoreferenceService().getCoordinateFormat(widget.mapContext!);
      }
    }
    return _selectedFormat;
  }

  String get _latLabel {
    final format = _currentFormat;
    switch (format) {
      case 'UTM':
        return 'Easting (UTM)';
      case 'ON':
        return 'Easting (Origen Nacional)';
      case 'DM':
        return 'Latitud (DM)';
      case 'DMS':
        return 'Latitud (DMS)';
      case 'DD':
      default:
        return 'Latitud (DD)';
    }
  }

  String get _lonLabel {
    final format = _currentFormat;
    switch (format) {
      case 'UTM':
        return 'Northing (UTM)';
      case 'ON':
        return 'Northing (Origen Nacional)';
      case 'DM':
        return 'Longitud (DM)';
      case 'DMS':
        return 'Longitud (DMS)';
      case 'DD':
      default:
        return 'Longitud (DD)';
    }
  }

  Map<String, String> _getCoordinatesForFormat(double lat, double lon, String format) {
    final formatted = GeoreferenceService().formatCoordinates(lat, lon, format);
    final parts = formatted.split(', ');
    if (parts.length >= 2) {
      return {
        'lat': parts[0],
        'lon': parts[1],
      };
    }
    return {
      'lat': formatted,
      'lon': '',
    };
  }

  double _calculateGeodesicLength(List<dynamic> points) {
    double total = 0.0;
    const double r = 6371000; // Earth radius in meters
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1['latitude'] == null || p1['longitude'] == null ||
          p2['latitude'] == null || p2['longitude'] == null) continue;
      final lat1 = (p1['latitude'] as num).toDouble() * math.pi / 180;
      final lon1 = (p1['longitude'] as num).toDouble() * math.pi / 180;
      final lat2 = (p2['latitude'] as num).toDouble() * math.pi / 180;
      final lon2 = (p2['longitude'] as num).toDouble() * math.pi / 180;

      final dLat = lat2 - lat1;
      final dLon = lon2 - lon1;

      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      total += r * c;
    }
    return total;
  }

  String _formatLengthWithUnit(double meters, String unit) {
    switch (unit) {
      case 'km':
        return '${(meters / 1000.0).toStringAsFixed(3)} km';
      case 'cm':
        return '${(meters * 100.0).toStringAsFixed(1)} cm';
      case 'mm':
        return '${(meters * 1000.0).toStringAsFixed(0)} mm';
      case 'in':
        return '${(meters * 39.3701).toStringAsFixed(1)} in';
      case 'ft':
        return '${(meters * 3.28084).toStringAsFixed(2)} ft';
      case 'yd':
        return '${(meters * 1.09361).toStringAsFixed(2)} yd';
      case 'mi':
        return '${(meters * 0.000621371).toStringAsFixed(3)} mi';
      case 'NM':
        return '${(meters * 0.000539957).toStringAsFixed(3)} NM';
      case 'm':
      default:
        return '${meters.toStringAsFixed(2)} m';
    }
  }

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    final List<DropdownMenuItem<String>> items = [];
    
    // Group 1: Sistema Métrico
    items.add(const DropdownMenuItem<String>(
      value: '__metric_header__',
      enabled: false,
      child: Text(
        'SISTEMA MÉTRICO',
        style: TextStyle(
          color: DesignSystem.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    ));
    items.add(const DropdownMenuItem<String>(value: 'm', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Metros (m)'))));
    items.add(const DropdownMenuItem<String>(value: 'km', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Kilómetros (km)'))));
    items.add(const DropdownMenuItem<String>(value: 'cm', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Centímetros (cm)'))));
    items.add(const DropdownMenuItem<String>(value: 'mm', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Milímetros (mm)'))));

    // Divider
    items.add(const DropdownMenuItem<String>(
      value: '__divider_1__',
      enabled: false,
      child: Divider(color: Colors.white12, height: 1),
    ));

    // Group 2: Sistema Imperial
    items.add(const DropdownMenuItem<String>(
      value: '__imperial_header__',
      enabled: false,
      child: Text(
        'SISTEMA ANGLOSAJÓN (IMPERIAL)',
        style: TextStyle(
          color: DesignSystem.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    ));
    items.add(const DropdownMenuItem<String>(value: 'ft', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Pies (ft)'))));
    items.add(const DropdownMenuItem<String>(value: 'yd', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Yardas (yd)'))));
    items.add(const DropdownMenuItem<String>(value: 'in', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Pulgadas (in)'))));
    items.add(const DropdownMenuItem<String>(value: 'mi', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Millas (mi)'))));

    // Divider
    items.add(const DropdownMenuItem<String>(
      value: '__divider_2__',
      enabled: false,
      child: Divider(color: Colors.white12, height: 1),
    ));

    // Group 3: Náutico
    items.add(const DropdownMenuItem<String>(
      value: '__nautical_header__',
      enabled: false,
      child: Text(
        'OTRAS UNIDADES',
        style: TextStyle(
          color: DesignSystem.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    ));
    items.add(const DropdownMenuItem<String>(value: 'NM', child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Millas Náuticas (NM)'))));

    return items;
  }

  void _updateTextFields() {
    if (widget.object['type'] == GeoObjectType.line) return;
    _latController.removeListener(_onCoordsChanged);
    _lonController.removeListener(_onCoordsChanged);

    final coords = _getCoordinatesForFormat(_currentLat, _currentLon, _currentFormat);
    _latController.text = coords['lat'] ?? '';
    _lonController.text = coords['lon'] ?? '';

    _latController.addListener(_onCoordsChanged);
    _lonController.addListener(_onCoordsChanged);
  }

  void _showFormatSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Formato de Coordenadas del Marcador',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    _buildBottomSheetItem('DD', 'Grados Decimales (DD)', setModalState),
                    _buildBottomSheetItem('DM', 'Grados y Minutos (DM)', setModalState),
                    _buildBottomSheetItem('DMS', 'Grados, Minutos y Segundos (DMS)', setModalState),
                    _buildBottomSheetItem('UTM', 'UTM (WGS84)', setModalState),
                    _buildBottomSheetItem('ON', 'Origen Nacional (EPSG:9377)', setModalState),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheetItem(String value, String label, StateSetter setModalState) {
    final bool isSelected = _selectedFormat == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = value;
          _updateTextFields();
        });
        setModalState(() {});
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? DesignSystem.primary : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: DesignSystem.primary,
                size: 20,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.white24,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
