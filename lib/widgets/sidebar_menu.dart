import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class SidebarMenu extends StatefulWidget {
  const SidebarMenu({super.key});

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  bool _isPoliciesExpanded = false;
  bool _isOwnershipExpanded = false;

  final String _policiesText =
      'POLÍTICA DE PRIVACIDAD Y TÉRMINOS\n\n'
      '1. RESPONSABLE DEL TRATAMIENTO\n'
      'El titular y responsable de NAVIMAP es ADAN ALFONSO ARIAS ANGULO (Contacto: ingarias9006@gmail.com).\n\n'
      '2. RECOPILACIÓN Y USO DE DATOS\n'
      '• Ubicación Precisa (GPS): NAVIMAP accede a la ubicación del dispositivo en tiempo real únicamente para posicionar al usuario en el mapa y calcular distancias o áreas de forma local. Estos datos no se transmiten a ningún servidor externo ni se comparten con terceros.\n'
      '• Acceso al Almacenamiento: Se solicita permiso para acceder a archivos locales exclusivamente para permitir al usuario importar, almacenar y calibrar mapas en formato GeoPDF. No se recopila ni accede a otra información personal.\n\n'
      '3. SERVICIOS DE TERCEROS\n'
      'Esta aplicación no contiene anuncios, herramientas de seguimiento ni SDKs de terceros que recopilen información de identificación personal (PII), garantizando la total privacidad de su actividad.\n\n'
      '4. SEGURIDAD DE LA INFORMACIÓN\n'
      'Toda la información cartográfica y la configuración cargada por el usuario se guarda localmente en el dispositivo. El usuario puede eliminar permanentemente estos datos desinstalando la aplicación.\n\n'
      '5. MENORES DE EDAD\n'
      'La aplicación no recopila ni solicita deliberadamente datos de menores de edad. Su uso es meramente profesional/técnico.\n\n'
      '6. MODIFICACIONES\n'
      'El propietario se reserva el derecho de actualizar esta política para cumplir con regulaciones legales y mejoras de seguridad. Se recomienda consultar esta sección periódicamente.\n\n'
      '7. SUSCRIPCIONES Y PAGOS RECURRENTES\n'
      'Las compras y suscripciones de NAVIMAP Pro se gestionan a través de la tienda oficial (Google Play Store). El cobro se realiza mensualmente a la tarifa vigente. La suscripción se renovará automáticamente al final de cada periodo mensual a menos que desactives la renovación automática en la configuración de suscripciones de Google Play al menos 24 horas antes del fin del periodo actual. No se realizan reembolsos por periodos parciales.\n\n'
      '8. CÓDIGOS DE ACCESO Y PROMOCIONES\n'
      'Los códigos de acceso único de NAVIMAP (incluyendo planes corporativos como HLG y códigos promocionales) son personales, intransferibles y de único uso. Un código solo puede activarse en una cuenta a la vez. El titular se reserva el derecho de revocar o modificar códigos si se detecta un uso indebido o fraudulento de los mismos.\n\n'
      '9. ELIMINACIÓN DE CUENTA Y DATOS\n'
      'El usuario puede realizar la eliminación definitiva de su cuenta de usuario y de todos sus datos asociados directamente desde la sección de Configuración de la aplicación en cualquier momento.';

  final String _ownershipText =
      'PROPIEDAD INTELECTUAL Y LICENCIA\n\n'
      '1. TITULARIDAD DE DERECHOS\n'
      'NAVIMAP, incluyendo su código fuente, interfaz gráfica, algoritmos, logotipos, marcas y bases de datos, es propiedad intelectual exclusiva de ADAN ALFONSO ARIAS ANGULO. Todos los derechos están reservados conforme a las leyes nacionales e internacionales de propiedad intelectual.\n\n'
      '2. LICENCIA DE USO\n'
      'Se otorga al usuario una licencia de uso personal, no exclusiva, intransferible y limitada para ejecutar la aplicación en dispositivos compatibles autorizados, sujeta al cumplimiento de estos términos.\n\n'
      '3. RESTRICCIONES\n'
      'Queda estrictamente prohibido copiar, reproducir, modificar, distribuir, vender, alquilar, sublicenciar o realizar ingeniería inversa de la aplicación o de cualquiera de sus componentes sin la autorización expresa y por escrito del titular.\n\n'
      '4. LIMITACIÓN DE RESPONSABILIDAD\n'
      'La aplicación se entrega "tal cual" y "según disponibilidad". El titular no garantiza que sea infalible o ininterrumpida. La correcta calibración de los mapas y el uso de los datos cartográficos son responsabilidad exclusiva del usuario. El autor no asume responsabilidad alguna por pérdidas directas o indirectas derivadas de errores cartográficos o fallos de precisión en la medición.\n\n'
      '5. CONTACTO Y SOPORTE\n'
      'Para soporte técnico, consultas de licencias o sugerencias, póngase en contacto a través de: ingarias9006@gmail.com\n\n'
      '© 2026 ADAN ALFONSO ARIAS ANGULO. Todos los derechos reservados.';

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: DesignSystem.surface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DesignSystem.outline)),
            ),
            child: Center(
              child: Text(
                'NAVIMAP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: DesignSystem.primary,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSystem.spacingMd,
                vertical: DesignSystem.spacingSm,
              ),
              children: [
                // Sección de Políticas de la App
                Card(
                  color: Colors.white.withValues(alpha: 0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignSystem.radiusDefault,
                    ),
                    side: const BorderSide(
                      color: DesignSystem.outline,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.gavel,
                          color: DesignSystem.primary,
                          size: 20,
                        ),
                        title: Text(
                          'POLÍTICAS',
                          style: DesignSystem.labelCaps.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        trailing: Icon(
                          _isPoliciesExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          setState(() {
                            _isPoliciesExpanded = !_isPoliciesExpanded;
                            if (_isPoliciesExpanded) {
                              _isOwnershipExpanded = false;
                            }
                          });
                        },
                      ),
                      if (_isPoliciesExpanded)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPoliciesExpanded = false;
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 250),
                            padding: const EdgeInsets.only(
                              left: DesignSystem.spacingMd,
                              right: DesignSystem.spacingMd,
                              bottom: DesignSystem.spacingMd,
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _policiesText,
                                style: DesignSystem.bodySm.copyWith(
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignSystem.spacingSm),
                // Sección de Propiedad de la App
                Card(
                  color: Colors.white.withValues(alpha: 0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignSystem.radiusDefault,
                    ),
                    side: const BorderSide(
                      color: DesignSystem.outline,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.copyright,
                          color: DesignSystem.primary,
                          size: 20,
                        ),
                        title: Text(
                          'PROPIEDAD',
                          style: DesignSystem.labelCaps.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        trailing: Icon(
                          _isOwnershipExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          setState(() {
                            _isOwnershipExpanded = !_isOwnershipExpanded;
                            if (_isOwnershipExpanded) {
                              _isPoliciesExpanded = false;
                            }
                          });
                        },
                      ),
                      if (_isOwnershipExpanded)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isOwnershipExpanded = false;
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 250),
                            padding: const EdgeInsets.only(
                              left: DesignSystem.spacingMd,
                              right: DesignSystem.spacingMd,
                              bottom: DesignSystem.spacingMd,
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _ownershipText,
                                style: DesignSystem.bodySm.copyWith(
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DesignSystem.spacingLg),
            child: Text(
              'v1.0.0 PRO',
              style: DesignSystem.labelCaps.copyWith(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}
