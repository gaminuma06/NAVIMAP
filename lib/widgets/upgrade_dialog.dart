import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/design_system.dart';
import '../services/billing_service.dart';

class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const UpgradeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DesignSystem.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        side: const BorderSide(color: DesignSystem.outline, width: 0.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(DesignSystem.spacingLg),
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(DesignSystem.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: DesignSystem.spacingLg),
            Text(
              'Desbloquea NAVIMAP Pro',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: DesignSystem.spacingSm),
            const Text(
              'Esta funcionalidad requiere una suscripción activa. Actualiza a Pro para desbloquear todo el potencial de la aplicación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: DesignSystem.spacingLg),
            Container(
              padding: const EdgeInsets.all(DesignSystem.spacingMd),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                border: Border.all(color: DesignSystem.outline, width: 0.5),
              ),
              child: Column(
                children: [
                  _buildBenefitRow(
                    icon: Icons.map_outlined,
                    title: 'Importaciones Ilimitadas',
                    description: 'Agrega y organiza todos los GeoPDFs que requieras.',
                  ),
                  const SizedBox(height: DesignSystem.spacingMd),
                  _buildBenefitRow(
                    icon: Icons.satellite_alt_outlined,
                    title: 'Mapas Satelitales Offline',
                    description: 'Descarga imágenes para navegar sin conexión a internet.',
                  ),
                  const SizedBox(height: DesignSystem.spacingMd),
                  _buildBenefitRow(
                    icon: Icons.flash_on_rounded,
                    title: 'Rendimiento Mejorado',
                    description: 'Carga y renderizado más rápido de capas geográficas.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignSystem.spacingLg),
            // Si es Android y no Web, mostramos el botón de Play Store
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                  try {
                    await BillingService().buySubscription();
                  } catch (e) {
                    debugPrint('Error en compra desde diálogo: $e');
                  }
                },
                child: const Text(
                  'Suscribirse en Play Store',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: DesignSystem.spacingSm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: DesignSystem.outline),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/settings',
                    arguments: {'autoOpenActivation': true},
                  );
                },
                child: const Text(
                  'Tengo un Código de Activación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ] else ...[
              // Web o iOS: Solo Código de Activación
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/settings',
                    arguments: {'autoOpenActivation': true},
                  );
                },
                child: const Text(
                  'Tengo un Código de Activación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: DesignSystem.spacingSm),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Mantener Plan Básico',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber, size: 20),
        const SizedBox(width: DesignSystem.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
