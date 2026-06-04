import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import '../services/layer_store.dart';

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

  final List<int> _colorOptions = [
    0xFFFF1744, // Rojo
    0xFF2979FF, // Azul
    0xFF00E676, // Verde
    0xFFFFEA00, // Amarillo
    0xFFFF9100, // Naranja
    0xFFD500F9, // Morado
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.object['name']);
    _latController = TextEditingController(
      text: widget.object['latitude']?.toString() ?? '',
    );
    _lonController = TextEditingController(
      text: widget.object['longitude']?.toString() ?? '',
    );
    _selectedColor = widget.object['color'] as int? ?? 0xFFFF1744;
    _createdAt = widget.object['createdAt'] as String? ?? DateTime.now().toIso8601String();
  }

  @override
  void dispose() {
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
    final newLat = double.parse(_latController.text.trim());
    final newLon = double.parse(_lonController.text.trim());

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
                  labelText: 'Latitud',
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
                  labelText: 'Longitud',
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
}
