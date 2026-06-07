import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import '../services/offline_map_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _offlineService = OfflineMapService();

  @override
  void initState() {
    super.initState();
    _offlineService.checkDownloadStatus();
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
                              onTap: isDownloading ? null : _showDownloadDialog,
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
        ],
      ),
    );
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
}
