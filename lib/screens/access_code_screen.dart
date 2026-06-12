import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';
import '../services/access_service.dart';

class AccessCodeScreen extends StatefulWidget {
  const AccessCodeScreen({super.key});

  @override
  State<AccessCodeScreen> createState() => _AccessCodeScreenState();
}

class _AccessCodeScreenState extends State<AccessCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleActivation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'El código no puede estar vacío.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('No se encontró una sesión activa.');
      }

      final registeredPlan = await AccessService().registerAccessCode(user.uid, code);
      if (registeredPlan != null) {
        if (mounted) {
          // Redirigir a la pantalla principal
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        setState(() {
          _errorMessage =
              'Código inválido, inactivo o ya utilizado por otra cuenta.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: DesignSystem.surface,
      appBar: AppBar(
        title: const Text('ACTIVACIÓN DE LICENCIA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: DesignSystem.error),
            tooltip: 'Cerrar Sesión',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DesignSystem.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: DesignSystem.surfaceContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: DesignSystem.secondary, width: 2),
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    color: DesignSystem.secondary,
                    size: 35,
                  ),
                ),
              ),
              const SizedBox(height: DesignSystem.spacingLg),
              Center(
                child: Text(
                  'Hola, ${user?.displayName ?? "Usuario"}',
                  style: GoogleFonts.spaceGrotesk(
                    textStyle: DesignSystem.headlineMd,
                    color: Colors.white,
                  ),
                ),
              ),
              Center(
                child: Text(
                  user?.email ?? '',
                  style: DesignSystem.bodySm.copyWith(color: Colors.white54),
                ),
              ),
              const SizedBox(height: DesignSystem.spacingXl),
              
              Text(
                'Ingresa tu Código Único de Acceso',
                style: DesignSystem.bodyLg.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignSystem.spacingSm),
              Text(
                'Este código vincula tu cuenta al sistema NAVIMAP de la empresa y define tu nivel de suscripción.',
                style: DesignSystem.bodySm.copyWith(color: Colors.white30),
              ),
              const SizedBox(height: DesignSystem.spacingMd),

              // Input de Código
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: 'NAVIMAP-XXXX-XXXX',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 0),
                  filled: true,
                  fillColor: DesignSystem.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                    borderSide: const BorderSide(color: DesignSystem.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                    borderSide: const BorderSide(color: DesignSystem.secondary, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.key, color: Colors.white54),
                ),
              ),
              const SizedBox(height: DesignSystem.spacingSm),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: DesignSystem.spacingSm),
                  child: Text(
                    _errorMessage!,
                    style: DesignSystem.bodySm.copyWith(color: DesignSystem.error),
                  ),
                ),

              const SizedBox(height: DesignSystem.spacingLg),

              // Botón Activar
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: DesignSystem.secondary,
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignSystem.secondary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DesignSystem.radiusDefault,
                          ),
                        ),
                      ),
                      onPressed: _handleActivation,
                      child: Text(
                        'Activar Acceso',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
