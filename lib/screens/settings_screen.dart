import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/design_system.dart';
import '../services/offline_map_service.dart';
import '../services/subscription_service.dart';
import '../services/access_service.dart';
import '../services/auth_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../services/billing_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'library_screen.dart' show MapStore;
import '../services/layer_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _offlineService = OfflineMapService();
  bool _didCheckArguments = false;
  bool _isYearlySelected = true; // El plan anual es el recomendado por defecto

  @override
  void initState() {
    super.initState();
    _offlineService.checkDownloadStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCheckArguments) {
      _didCheckArguments = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args['autoOpenActivation'] == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showActivationDialog(context);
          }
        });
      }
    }
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SubscriptionService().planNotifier,
      builder: (context, plan, _) {
        final planLower = plan.toLowerCase();
        final isHlg = planLower == 'hlg';
        final isPro = planLower == 'pro' || isHlg;

        // Título de la suscripción
        String titleText = 'NAVIMAP Basic (Plan Gratuito)';
        if (isHlg) {
          titleText = 'Hacienda La Gloria (Acceso Corporativo)';
        } else if (planLower == 'pro') {
          titleText = 'NAVIMAP Pro (Acceso Completo)';
        }

        // Color de borde de la tarjeta
        Color borderCol = isPro ? Colors.amber : DesignSystem.outline;
        if (isHlg) {
          borderCol = const Color(0xFF00E676); // verde HLG
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white.withValues(alpha: 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
            side: BorderSide(
              color: borderCol,
              width: isPro ? 1.5 : 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignSystem.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPro ? Icons.star_rounded : Icons.lock_person_rounded,
                      color: isHlg ? const Color(0xFF00E676) : (isPro ? Colors.amber : Colors.white54),
                      size: 24,
                    ),
                    const SizedBox(width: DesignSystem.spacingSm),
                    Expanded(
                      child: Text(
                        titleText,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isHlg ? const Color(0xFF00E676).withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isHlg ? const Color(0xFF00E676) : Colors.amber, width: 0.5),
                        ),
                        child: Text(
                          isHlg ? 'HLG CORPO' : 'PRO',
                          style: TextStyle(
                            color: isHlg ? const Color(0xFF00E676) : Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: DesignSystem.spacingSm),
                Text.rich(
                  TextSpan(
                    children: [
                      if (isHlg) ...[
                        const TextSpan(
                          text: 'Dispones acceso corporativo ilimitado provisto y gestionado directamente por Hacienda la Gloria, gracias al ingeniero Adan Arias.',
                        ),
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.water_drop,
                              size: 13,
                              color: Color(0xFF00B0FF),
                            ),
                          ),
                        ),
                      ] else ...[
                        TextSpan(
                          text: isPro
                              ? 'Dispones de importaciones GeoPDF ilimitadas y descargas de mapas satelitales habilitadas.'
                              : 'Límite de 3 GeoPDFs en biblioteca. La descarga de mapas satelitales offline requiere suscripción.',
                        ),
                      ],
                    ],
                  ),
                  style: DesignSystem.bodySm.copyWith(color: Colors.white54),
                ),
                if (!isPro) ...[
                  const SizedBox(height: DesignSystem.spacingMd),
                  ValueListenableBuilder<List<ProductDetails>>(
                    valueListenable: BillingService().productsList,
                    builder: (context, products, _) {
                      String monthlyPrice = '\$7.49 USD';
                      String yearlyPrice = '\$79.99 USD';

                      for (var prod in products) {
                        if (prod.id == BillingService.subscriptionMonthlyId) {
                          monthlyPrice = prod.price;
                        } else if (prod.id == BillingService.subscriptionYearlyId) {
                          yearlyPrice = prod.price;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: DesignSystem.spacingMd),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DesignSystem.outline, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isYearlySelected = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isYearlySelected
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !_isYearlySelected ? Colors.amber : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Plan Mensual',
                                        style: TextStyle(
                                          color: !_isYearlySelected ? Colors.white : Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$monthlyPrice / mes',
                                        style: TextStyle(
                                          color: !_isYearlySelected ? Colors.amber : Colors.white54,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isYearlySelected = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isYearlySelected
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isYearlySelected ? Colors.amber : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Plan Anual',
                                            style: TextStyle(
                                              color: _isYearlySelected ? Colors.white : Colors.white70,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF388E3C),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'AHORRA 10%',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 7,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$yearlyPrice / año',
                                        style: TextStyle(
                                          color: _isYearlySelected ? Colors.amber : Colors.white54,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Botón nativo de Play Store (visible en Android)
                      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
                        ValueListenableBuilder<bool>(
                          valueListenable: BillingService().isPurchasePending,
                          builder: (context, isPending, _) {
                            return ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                                ),
                              ),
                              icon: isPending 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.shopping_bag_outlined, size: 18),
                              label: Text(
                                isPending ? 'PROCESANDO...' : 'Suscribirse en Play Store',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: isPending ? null : () async {
                                try {
                                    final chosenProductId = _isYearlySelected
                                        ? BillingService.subscriptionYearlyId
                                        : BillingService.subscriptionMonthlyId;
                                    await BillingService().buySubscription(productId: chosenProductId);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
                                          backgroundColor: DesignSystem.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                            );
                          },
                        ),
                        const SizedBox(height: DesignSystem.spacingSm),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignSystem.secondary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 38),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    DesignSystem.radiusDefault,
                                  ),
                                ),
                              ),
                              onPressed: () => _showActivationDialog(context),
                              child: const Text(
                                'Activar con Código',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: DesignSystem.spacingSm),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                minimumSize: const Size(0, 38),
                              ),
                              onPressed: () => _showPaymentInstructions(context),
                              child: const Text(
                                'Obtener Código',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActivationDialog(BuildContext context) {
    final codeController = TextEditingController();
    bool isDialogLoading = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: DesignSystem.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                side: const BorderSide(color: DesignSystem.outline),
              ),
              title: Text(
                'Activar NAVIMAP Pro',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Introduce tu código único de activación para desbloquear el plan Pro.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: DesignSystem.spacingMd),
                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'CÓDIGO DE ACTIVACIÓN',
                      hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 0, fontSize: 12),
                      filled: true,
                      fillColor: DesignSystem.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                        borderSide: const BorderSide(color: DesignSystem.outline),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: DesignSystem.spacingSm),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: DesignSystem.error, fontSize: 12),
                    ),
                  ],

                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                isDialogLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: DesignSystem.secondary),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignSystem.secondary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            setDialogState(() {
                              dialogError = 'El código no puede estar vacío.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isDialogLoading = true;
                            dialogError = null;
                          });

                          try {
                            final user = AuthService().currentUser;
                            if (user == null) {
                              throw Exception('Inicia sesión para registrar el código.');
                            }

                            final registeredPlan = await AccessService().registerAccessCode(user.uid, code);
                            if (registeredPlan != null) {
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              // Actualizar el plan reactivamente sin activar el banner global en segundo plano
                              SubscriptionService().updateSubscriptionState(registeredPlan, true, enableCelebration: false);
                              
                              if (context.mounted) {
                                // Mostrar la celebración localmente en el contexto de configuración
                                _showCelebrationDialog(context, registeredPlan);
                                
                                final isHlg = registeredPlan.toLowerCase() == 'hlg';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isHlg 
                                      ? '¡Acceso Hacienda La Gloria activado exitosamente!' 
                                      : '¡Plan Pro activado exitosamente!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                dialogError = 'Código inválido o ya utilizado.';
                              });
                            }
                          } catch (e) {
                            String errorMsg = e.toString().replaceAll('Exception: ', '');
                            if (errorMsg.contains('permission-denied') || errorMsg.contains('permission_denied') || errorMsg.contains('insufficient permissions')) {
                              errorMsg = 'Error de permisos de Firebase. Asegúrate de haber publicado las Reglas de Seguridad en tu consola de Firestore (pestaña Rules) según la guía de configuración.';
                            }
                            setDialogState(() {
                              dialogError = errorMsg;
                            });
                          } finally {
                            setDialogState(() {
                              isDialogLoading = false;
                            });
                          }
                        },
                        child: const Text('ACTIVAR'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPaymentInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DesignSystem.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
            side: const BorderSide(color: DesignSystem.outline),
          ),
          title: Text(
            'Obtener NAVIMAP Pro',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El plan Pro requiere una licencia comercial o un código único de acceso. Puedes conseguirlo de las siguientes maneras:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: DesignSystem.spacingMd),
              const Text(
                '1. Código Corporativo:\nContacta al departamento de sistemas o administrador de GIS de tu empresa para que te asigne una licencia.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: DesignSystem.spacingSm),
              const Text(
                '2. Pago Web / En Línea:\nIngresa a navimap.com/suscripcion para pagar de forma segura con tarjeta de crédito, Apple Pay o Google Pay, y generar tu código de activación instantáneo.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO'),
            ),
          ],
        );
      },
    );
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final MapController mapController = MapController();
        LatLngBounds? currentBounds;
        int tileCount = 0;
        double estimatedSizeMB = 0.0;
        final dialogTileProvider = kIsWeb
            ? WebNetworkTileProvider()
            : CancellableNetworkTileProvider(silenceExceptions: true);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void updateEstimation(LatLngBounds? bounds) {
              if (bounds == null) return;
              final count = _offlineService.estimateTileCount(bounds);
              setStateDialog(() {
                currentBounds = bounds;
                tileCount = count;
                estimatedSizeMB = count * 0.025; // Aprox 25 KB por tesela
              });
            }

            final isTooLarge = estimatedSizeMB > 190.0;
            final isInsane = estimatedSizeMB > 300.0;

            return Dialog(
              backgroundColor: const Color(0xFF141414),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                side: const BorderSide(color: DesignSystem.outline, width: 0.5),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: 600,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            color: DesignSystem.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'SELECCIONAR ÁREA DE DESCARGA',
                              style: DesignSystem.labelCaps.copyWith(
                                color: Colors.white,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      color: DesignSystem.outline,
                      height: 1,
                      thickness: 0.5,
                    ),

                    // Explicación
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Ajusta el zoom y mueve el mapa para enmarcar la región que deseas descargar. Todo lo visible dentro de este cuadro estará disponible sin conexión.',
                        style: DesignSystem.bodySm.copyWith(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),

                    // Mapa
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            DesignSystem.radiusDefault,
                          ),
                          border: Border.all(
                            color: DesignSystem.outline,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            DesignSystem.radiusDefault,
                          ),
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: mapController,
                                options: MapOptions(
                                  initialCenter: const LatLng(
                                    8.623083,
                                    -73.732583,
                                  ),
                                  initialZoom: 13.0,
                                  onMapReady: () {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          updateEstimation(
                                            mapController.camera.visibleBounds,
                                          );
                                        });
                                  },
                                  onPositionChanged: (camera, hasGesture) {
                                    updateEstimation(camera.visibleBounds);
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                                    userAgentPackageName: 'com.navimap.app',
                                    tileProvider: dialogTileProvider,
                                  ),
                                ],
                              ),
                              // Retícula o bordes indicadores en el mapa para marcar que todo lo visible es lo que se descarga
                              IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: DesignSystem.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Información de peso y advertencias
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Imágenes estimadas:',
                                style: DesignSystem.bodySm.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                              Text(
                                '$tileCount teselas',
                                style: DesignSystem.bodySm.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Peso estimado de descarga:',
                                style: DesignSystem.bodySm.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                              Text(
                                '${estimatedSizeMB.toStringAsFixed(1)} MB',
                                style: DesignSystem.bodySm.copyWith(
                                  color: isTooLarge
                                      ? Colors.orangeAccent
                                      : DesignSystem.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (isTooLarge) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isInsane
                                    ? Colors.redAccent.withValues(alpha: 0.1)
                                    : Colors.orangeAccent.withValues(
                                        alpha: 0.1,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isInsane
                                      ? Colors.redAccent
                                      : Colors.orangeAccent,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isInsane
                                        ? Icons.error_outline
                                        : Icons.warning_amber_outlined,
                                    color: isInsane
                                        ? Colors.redAccent
                                        : Colors.orangeAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isInsane
                                          ? 'Área excesivamente grande. Haz zoom in para delimitar un área menor.'
                                          : 'Área muy grande. Se sugiere reducir el área (hacer zoom in) para evitar descargas lentas.',
                                      style: TextStyle(
                                        color: isInsane
                                            ? Colors.redAccent
                                            : Colors.orangeAccent,
                                        fontSize: 10,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Botones de acción
                    const Divider(
                      color: DesignSystem.outline,
                      height: 1,
                      thickness: 0.5,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'CANCELAR',
                              style: DesignSystem.labelCaps.copyWith(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isInsane
                                  ? Colors.white24
                                  : DesignSystem.primary,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onPressed: (currentBounds == null || isInsane)
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _startBoundsDownload(currentBounds!);
                                  },
                            child: Text(
                              'ACEPTAR',
                              style: DesignSystem.labelCaps.copyWith(
                                color: (currentBounds == null || isInsane)
                                    ? Colors.white30
                                    : Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startBoundsDownload(LatLngBounds bounds) {
    _offlineService.downloadMap(bounds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.surface,
      appBar: AppBar(
        title: const Text('AJUSTES DEL SISTEMA', style: DesignSystem.labelCaps),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSettingsHeader('SUSCRIPCIÓN'),
          _buildSubscriptionCard(context),
          _buildSettingsHeader('SISTEMA'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white.withValues(alpha: 0.02),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
              side: const BorderSide(color: DesignSystem.outline, width: 0.5),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: _offlineService.downloadingNotifier,
              builder: (context, isDownloading, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: _offlineService.progressNotifier,
                  builder: (context, progress, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _offlineService.downloadedNotifier,
                      builder: (context, isDownloaded, _) {
                        final progressPercent = (progress * 100).toInt();

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Descargar Mapas para Uso Offline',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (isDownloading)
                                    Text(
                                      ' $progressPercent%',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    )
                                  else if (isDownloaded)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: isDownloading
                                    ? const Text(
                                        'Descargando mapa satelital de Google...',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      )
                                    : (isDownloaded
                                          ? const Text(
                                              'Mapa satelital guardado localmente.',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            )
                                          : const Text(
                                              'Descarga de imágenes satelitales para navegación sin internet.',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            )),
                              ),
                              trailing: isDownloading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.green,
                                            ),
                                      ),
                                    )
                                  : (isDownloaded
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _offlineService
                                                  .deleteOfflineTiles();
                                            },
                                          )
                                        : const Icon(
                                            Icons.chevron_right,
                                            color: Colors.white54,
                                          )),
                              onTap: isDownloading
                                  ? null
                                  : () {
                                      final isPro = SubscriptionService().isPro;
                                      if (!isPro) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: DesignSystem.surface,
                                            title: Row(
                                              children: [
                                                const Icon(Icons.star_rounded, color: Colors.amber),
                                                const SizedBox(width: DesignSystem.spacingSm),
                                                Text(
                                                  'Plan Pro Requerido',
                                                  style: GoogleFonts.spaceGrotesk(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: const Text(
                                              'La descarga de mapas satelitales para uso offline está reservada para usuarios Pro. '
                                              'Contacta a tu administrador para actualizar tu plan y desbloquear esta función.',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('ENTENDIDO'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: DesignSystem.secondary,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _showActivationDialog(context);
                                                },
                                                child: const Text('TENGO UN CÓDIGO'),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        _showDownloadDialog();
                                      }
                                    },
                            ),
                            if (isDownloading) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white10,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.green,
                                        ),
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildSettingsHeader('CUENTA'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white.withValues(alpha: 0.02),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
              side: const BorderSide(color: DesignSystem.outline, width: 0.5),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'Cierra tu sesión de usuario en este dispositivo.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.white24,
              ),
              onTap: () => _showLogoutConfirmation(context),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => _showDeleteAccountConfirmation(context),
              child: const Text(
                'Eliminar Cuenta y Datos',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: DesignSystem.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
            side: const BorderSide(color: DesignSystem.outline),
          ),
          title: Text(
            'Eliminar Cuenta',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '¿Estás completamente seguro de que deseas eliminar tu cuenta? Esta acción borrará de forma permanente tu perfil y todos tus mapas guardados en este dispositivo. Esta acción es irreversible.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteAccount(context);
              },
              child: const Text('ELIMINAR MI CUENTA'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Validar si la sesión es reciente antes de proceder con el borrado de datos
        final lastSignIn = user.metadata.lastSignInTime;
        if (lastSignIn != null) {
          final diff = DateTime.now().difference(lastSignIn);
          if (diff.inMinutes > 5) {
            throw FirebaseAuthException(
              code: 'requires-recent-login',
              message: 'Por seguridad, por favor cierra sesión e inicia sesión de nuevo para poder eliminar tu cuenta.',
            );
          }
        }

        final uid = user.uid;
        
        // 1. Borrar documento de Firestore y limpiar cache local
        await AccessService().clearLocalCache();
        SubscriptionService().updateSubscriptionState('free', false);
        
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        } catch (e) {
          debugPrint('Error eliminando doc de Firestore: $e');
          String errorMsg = e.toString();
          if (errorMsg.contains('permission-denied') || errorMsg.contains('permission_denied') || errorMsg.contains('insufficient permissions')) {
            throw Exception('Error de permisos al borrar los datos de la base de datos. Asegúrate de haber publicado las Reglas de Seguridad en tu consola de Firestore.');
          }
          rethrow;
        }

        // 2. Borrar de Firebase Auth
        await user.delete();

        // 3. Cerrar sesión
        await AuthService().signOut();

        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu cuenta ha sido eliminada exitosamente.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por seguridad, por favor cierra sesión e inicia sesión de nuevo para poder eliminar tu cuenta.'),
              backgroundColor: DesignSystem.error,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar la cuenta: ${e.message}'),
              backgroundColor: DesignSystem.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    }
  }

  Widget _buildSettingsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: DesignSystem.labelCaps.copyWith(
          color: DesignSystem.primary,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showCelebrationDialog(BuildContext context, String plan) {
    final planLower = plan.toLowerCase();
    if (planLower == 'hlg') {
      _showHlgCelebrationDialog(context);
    } else if (planLower == 'pro') {
      _showProCelebrationDialog(context);
    }
  }

  void _showHlgCelebrationDialog(BuildContext context) {
    final themeColor = const Color(0xFF00E676); // Verde HLG
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131313),
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.15),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(DesignSystem.spacingLg),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.domain_verification_rounded,
                  color: themeColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.withValues(alpha: 0.25), width: 0.8),
                ),
                child: Text(
                  'ACCESO CORPORATIVO HLG',
                  style: GoogleFonts.spaceGrotesk(
                    color: themeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '¡Bienvenido a NaviMap!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Gracias al Ingeniero Adan Arias y a la provisión directa de Hacienda La Gloria, tienes acceso ilimitado a todas las herramientas geográficas, capas y mapas georreferenciados de la plataforma.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Icon(
                          Icons.water_drop,
                          size: 13,
                          color: Color(0xFF00B0FF),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'COMENZAR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProCelebrationDialog(BuildContext context) {
    final themeColor = const Color(0xFFFFD700); // Dorado
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131313),
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(DesignSystem.spacingLg),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.05),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: themeColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Text(
                  'NAVIMAP PRO',
                  style: GoogleFonts.spaceGrotesk(
                    color: themeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Bienvenido a NAVIMAP Pro!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '¡Gracias por suscribirte! Ahora tienes acceso a todas las herramientas avanzadas y mapas ilimitados.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'COMENZAR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            '¿Cerrar Sesión?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '¡Atención! Al cerrar sesión se eliminarán todos los mapas importados y las capas creadas en este dispositivo.\n\nPor favor, asegúrate de respaldar tu información exportando tus mapas y capas antes de proceder.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                
                // 1. Limpiar mapas del disco
                try {
                  final docDir = await getApplicationDocumentsDirectory();
                  final metadataFile = File('${docDir.path}/maps_metadata.json');
                  if (await metadataFile.exists()) {
                    final content = await metadataFile.readAsString();
                    final list = jsonDecode(content) as List<dynamic>;
                    final mapsDir = Directory('${docDir.path}/imported_maps');
                    final thumbnailsDir = Directory('${docDir.path}/map_thumbnails');
                    
                    for (var item in list) {
                      final name = item['title'] as String;
                      final pdfFile = File('${mapsDir.path}/$name');
                      if (await pdfFile.exists()) {
                        await pdfFile.delete();
                      }
                      final thumbFile = File('${thumbnailsDir.path}/$name.png');
                      if (await thumbFile.exists()) {
                        await thumbFile.delete();
                      }
                    }
                    await metadataFile.delete();
                  }
                } catch (e) {
                  debugPrint('Error eliminando mapas persistidos: $e');
                }
                
                // 2. Limpiar cache de mapas en memoria
                MapStore.bytesCache.clear();
                MapStore.mockMaps.clear();
                
                // 3. Limpiar capas guardadas
                try {
                  LayerStore.layers.clear();
                  LayerStore.mapLayerObjects.clear();
                  await LayerStore.saveLayers();
                } catch (e) {
                  debugPrint('Error limpiando capas: $e');
                }
                
                // 4. Limpiar calibraciones de georreferencia
                try {
                  final docDir = await getApplicationDocumentsDirectory();
                  final calFile = File('${docDir.path}/map_calibrations_cache.json');
                  if (await calFile.exists()) {
                    await calFile.delete();
                  }
                } catch (e) {
                  debugPrint('Error limpiando calibraciones: $e');
                }
                
                // 5. Limpiar caché de la licencia local
                await AccessService().clearLocalCache();
                
                // 6. Resetear estado de suscripción en memoria
                SubscriptionService().updateSubscriptionState('free', false);
                
                // 7. Cerrar sesión en Firebase
                await AuthService().signOut();
                
                // 8. Redirigir al inicio limpiando la pila
                navigator.pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text('CERRAR SESIÓN', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
