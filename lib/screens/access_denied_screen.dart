import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';
import '../services/access_service.dart';

class AccessDeniedScreen extends StatefulWidget {
  final bool requiresOnline;

  const AccessDeniedScreen({
    super.key,
    required this.requiresOnline,
  });

  @override
  State<AccessDeniedScreen> createState() => _AccessDeniedScreenState();
}

class _AccessDeniedScreenState extends State<AccessDeniedScreen> {
  bool _isChecking = false;

  Future<void> _handleRetry(BuildContext context) async {
    setState(() => _isChecking = true);
    try {
      final user = AuthService().currentUser;
      if (user != null) {
        final status = await AccessService().checkUserAccess(user.uid);
        if (status.active && !status.requiresOnline && mounted) {
          // Si ya es válido, volver a cargar la app
          Navigator.pushReplacementNamed(context, '/');
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.requiresOnline
                  ? 'Aún no se puede establecer conexión a Internet.'
                  : 'El acceso sigue denegado por el administrador.',
            ),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar: $e'),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await AuthService().signOut();
    await AccessService().clearLocalCache();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignSystem.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono de bloqueo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: DesignSystem.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: DesignSystem.error, width: 2),
                ),
                child: Icon(
                  widget.requiresOnline
                      ? Icons.wifi_off_rounded
                      : Icons.block_flipped,
                  color: DesignSystem.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: DesignSystem.spacingLg),

              // Título
              Text(
                widget.requiresOnline
                    ? 'CONEXIÓN REQUERIDA'
                    : 'ACCESO BLOQUEADO',
                style: GoogleFonts.spaceGrotesk(
                  textStyle: DesignSystem.headlineMd,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: DesignSystem.spacingMd),

              // Mensaje
              Text(
                widget.requiresOnline
                    ? 'No se ha podido comprobar tu licencia local en los últimos 7 días. Conéctate a Internet (Wi-Fi o datos móviles) para verificar el estado de tu suscripción y continuar usando la aplicación.'
                    : 'Tu acceso al sistema NAVIMAP ha sido suspendido o revocado por el administrador corporativo. Si crees que esto es un error, por favor ponte en contacto con soporte.',
                textAlign: TextAlign.center,
                style: DesignSystem.bodyMd.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: DesignSystem.spacingXl),

              // Botones
              _isChecking
                  ? const CircularProgressIndicator(color: DesignSystem.error)
                  : Column(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesignSystem.error,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(200, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DesignSystem.radiusDefault,
                              ),
                            ),
                          ),
                          onPressed: () => _handleRetry(context),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar Validación'),
                        ),
                        const SizedBox(height: DesignSystem.spacingMd),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white54,
                          ),
                          onPressed: () => _handleLogout(context),
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar Sesión'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
