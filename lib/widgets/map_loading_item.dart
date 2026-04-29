import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class MapLoadingItem extends StatefulWidget {
  final String title;
  const MapLoadingItem({super.key, required this.title});

  @override
  State<MapLoadingItem> createState() => _MapLoadingItemState();
}

class _MapLoadingItemState extends State<MapLoadingItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignSystem.spacingMd),
      padding: const EdgeInsets.all(DesignSystem.spacingMd),
      decoration: BoxDecoration(
        color: DesignSystem.surfaceContainer,
        borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
        border: Border.all(color: DesignSystem.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Placeholder para la miniatura
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
            ),
            child: const Icon(Icons.upload_file, color: DesignSystem.primary, size: 30),
          ),
          const SizedBox(width: DesignSystem.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARGANDO: ${widget.title.toUpperCase()}',
                  style: DesignSystem.labelCaps.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Procesando cartografía...',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // Barra de progreso
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _animation.value,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(DesignSystem.primary),
                        minHeight: 4,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
