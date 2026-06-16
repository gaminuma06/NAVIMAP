import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isSignUpMode = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        // Al loguearse exitosamente, el AuthWrapper de main.dart se encargará
        // de redirigir a la pantalla adecuada (AccessCode o Library).
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      if (!errStr.contains('popup_closed') && !errStr.contains('canceled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de inicio de sesión: $e'),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);
    try {
      NaviMapUser? user;
      if (_isSignUpMode) {
        user = await AuthService().signUpWithEmail(email, password);
      } else {
        user = await AuthService().signInWithEmail(email, password);
      }

      if (user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Icono Táctico / Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: DesignSystem.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: DesignSystem.primary, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.satellite_alt_rounded,
                  color: DesignSystem.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: DesignSystem.spacingMd),
              // Título
              Text(
                'NAVIMAP',
                style: GoogleFonts.spaceGrotesk(
                  textStyle: DesignSystem.headlineLg,
                  color: Colors.white,
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: DesignSystem.spacingXs),
              Text(
                'SISTEMA DE INFORMACIÓN GEOGRÁFICA',
                style: DesignSystem.labelCaps.copyWith(
                  color: Colors.white54,
                  fontSize: 9,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 32),

              // Formulario Correo/Contraseña
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSignUpMode ? 'CREAR CUENTA NUEVA' : 'INICIAR SESIÓN MANUAL',
                      style: DesignSystem.labelCaps.copyWith(
                        color: DesignSystem.secondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: DesignSystem.spacingSm),
                    // Campo Correo
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                        filled: true,
                        fillColor: DesignSystem.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                          borderSide: const BorderSide(color: DesignSystem.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                          borderSide: const BorderSide(color: DesignSystem.secondary),
                        ),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa tu correo electrónico.';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return 'Ingresa un correo válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: DesignSystem.spacingMd),
                    // Campo Contraseña
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                        filled: true,
                        fillColor: DesignSystem.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                          borderSide: const BorderSide(color: DesignSystem.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                          borderSide: const BorderSide(color: DesignSystem.secondary),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54, size: 20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu contraseña.';
                        }
                        if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: DesignSystem.spacingLg),

                    // Botón de Acción
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: DesignSystem.secondary),
                          )
                        : Column(
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignSystem.secondary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      DesignSystem.radiusDefault,
                                    ),
                                  ),
                                ),
                                onPressed: _handleEmailAuth,
                                child: Text(
                                  _isSignUpMode ? 'CREAR CUENTA' : 'ENTRAR',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: DesignSystem.spacingSm),
                              // Botón de alternancia
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isSignUpMode = !_isSignUpMode;
                                    _formKey.currentState?.reset();
                                  });
                                },
                                child: Text(
                                  _isSignUpMode
                                      ? '¿Ya tienes cuenta? Inicia sesión aquí'
                                      : '¿No tienes cuenta? Regístrate aquí',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),

              const SizedBox(height: DesignSystem.spacingMd),
              // Separador "O"
              Row(
                children: [
                  const Expanded(child: Divider(color: DesignSystem.outline, endIndent: 10)),
                  Text('O', style: DesignSystem.bodySm.copyWith(color: Colors.white30)),
                  const Expanded(child: Divider(color: DesignSystem.outline, indent: 10)),
                ],
              ),
              const SizedBox(height: DesignSystem.spacingMd),

              // Botón de Google
              if (!_isLoading)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusDefault,
                      ),
                    ),
                    elevation: 1,
                  ),
                  onPressed: _handleGoogleSignIn,
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.login_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  label: Text(
                    'Continuar con Google',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

