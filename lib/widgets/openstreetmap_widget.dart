import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/colors.dart';
import '../models/order.dart';
import '../services/location_service.dart';
import '../services/tile_cache_service.dart';
import 'delivery_bike_painter.dart';

/// Simplified OpenStreetMap widget - shows location and markers only (no routing)
/// Navigation is handled by external Google Maps app
class OpenStreetMapWidget extends StatefulWidget {
  final List<Order> orders;
  final Order? selectedOrder;
  final Function(Order)? onOrderSelected;
  final VoidCallback? onOrderTap;

  /// Optional: highlight a specific destination (for delivery navigation)
  final LatLng? highlightedDestination;
  final String? highlightedLabel;

  /// Controls visibility and position
  final bool showControls;
  final double controlsBottomOffset;

  const OpenStreetMapWidget({
    super.key,
    required this.orders,
    this.selectedOrder,
    this.onOrderSelected,
    this.onOrderTap,
    this.highlightedDestination,
    this.highlightedLabel,
    this.showControls = true,
    this.controlsBottomOffset = 180,
  });

  @override
  State<OpenStreetMapWidget> createState() => _OpenStreetMapWidgetState();
}

class _OpenStreetMapWidgetState extends State<OpenStreetMapWidget>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;

  // Default location (Kolkata, India) as fallback
  static const LatLng _defaultLocation = LatLng(22.5726, 88.3639);

  // Current zoom level
  double _currentZoom = 15;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Listen to location changes for map centering
    LocationService.currentLocation.addListener(_onLocationChanged);

    // Initialize location if not already done
    if (LocationService.currentLocation.value == null) {
      LocationService.initialize();
    }
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LocationService.currentLocation.removeListener(_onLocationChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _centerOnUser() async {
    final available = await LocationService.ensureLocationAvailable();
    if (available && mounted) {
      final loc = LocationService.currentLocation.value;
      if (loc != null) {
        _mapController.move(loc, _currentZoom);
      }
    }
  }

  void _zoomIn() {
    if (_currentZoom < 18) {
      setState(() => _currentZoom += 1);
      _mapController.move(_mapController.camera.center, _currentZoom);
    }
  }

  void _zoomOut() {
    if (_currentZoom > 3) {
      setState(() => _currentZoom -= 1);
      _mapController.move(_mapController.camera.center, _currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<LatLng?>(
      valueListenable: LocationService.currentLocation,
      builder: (context, currentLocation, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: LocationService.errorMessage,
          builder: (context, error, _) {
            // Show loading state
            if (currentLocation == null && error == null) {
              return Container(
                color: isDark ? AppColors.deepNavy : Colors.grey[100],
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.emeraldGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Getting your location...',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final center = currentLocation ?? _defaultLocation;

            return Stack(
              children: [
                // The Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _currentZoom,
                    minZoom: 3,
                    maxZoom: 18,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() => _currentZoom = position.zoom);
                      }
                    },
                  ),
                  children: [
                    // Map Tiles with offline caching
                    TileLayer(
                      urlTemplate: isDark
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.gkk.delivery',
                      maxZoom: 20,
                      retinaMode: RetinaMode.isHighDensity(context),
                      tileProvider: TileCacheService.getTileProvider(),
                    ),

                    // Simple dashed line from current location to destination (if any)
                    if (widget.highlightedDestination != null &&
                        currentLocation != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              currentLocation,
                              widget.highlightedDestination!,
                            ],
                            strokeWidth: 3,
                            color: AppColors.emeraldGreen.withValues(
                              alpha: 0.6,
                            ),
                            pattern: const StrokePattern.dotted(),
                          ),
                        ],
                      ),

                    // Polyline for selected order (Kitchen to Customer)
                    if (widget.selectedOrder != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              widget.selectedOrder!.location,
                              widget.selectedOrder!.deliveryLocation,
                            ],
                            strokeWidth: 4,
                            color: AppColors.emeraldGreen.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ],
                      ),

                    // Order Markers (from radar screen)
                    MarkerLayer(markers: _buildOrderMarkers()),

                    // Delivery Marker for selected order
                    if (widget.selectedOrder != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.selectedOrder!.deliveryLocation,
                            width: 50,
                            height: 60,
                            child: _buildCustomerMarker(),
                          ),
                        ],
                      ),

                    // Highlighted destination marker
                    if (widget.highlightedDestination != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.highlightedDestination!,
                            width: 50,
                            height: 60,
                            child: _buildDestinationMarker(),
                          ),
                        ],
                      ),

                    // Current Location Marker (Bike)
                    if (currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: currentLocation,
                            width: 70,
                            height: 70,
                            child: _buildBikeMarker(),
                          ),
                        ],
                      ),
                  ],
                ),

                // Map Controls - positioned based on parameter
                if (widget.showControls)
                  Positioned(
                    right: 16,
                    bottom: widget.controlsBottomOffset,
                    child: _buildMapControls(isDark),
                  ),

                // Error banner
                if (error != null) _buildErrorBanner(error, isDark),
              ],
            );
          },
        );
      },
    );
  }

  /// Build the current location bike marker
  Widget _buildBikeMarker() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.2);
        final opacity = 1.0 - _pulseController.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring
            Transform.scale(
              scale: scale,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.emeraldGreen.withValues(
                      alpha: opacity * 0.5,
                    ),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Inner circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emeraldGreen.withValues(alpha: 0.2),
                border: Border.all(color: AppColors.emeraldGreen, width: 2),
              ),
            ),
            // Bike icon
            ValueListenableBuilder<double>(
              valueListenable: LocationService.currentHeading,
              builder: (context, heading, _) => DeliveryBikeMarker(
                size: 32,
                heading: heading,
                primaryColor: AppColors.emeraldGreen,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build destination marker (for delivery navigation)
  Widget _buildDestinationMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.goldenMustard,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.goldenMustard.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _TrianglePainter(color: AppColors.goldenMustard),
        ),
      ],
    );
  }

  /// Build customer/delivery marker
  Widget _buildCustomerMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.emeraldGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.emeraldGreen.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.person_pin, color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _TrianglePainter(color: AppColors.emeraldGreen),
        ),
      ],
    );
  }

  /// Build order markers for radar screen
  List<Marker> _buildOrderMarkers() {
    if (widget.orders.isEmpty) return [];

      final overlapCount = <String, int>{};

      return widget.orders.map((order) {
        // Simple jitter if multiple orders at same coordinate
        final coordKey =
            '${order.location.latitude.toStringAsFixed(5)}_${order.location.longitude.toStringAsFixed(5)}';
        final overlap = overlapCount[coordKey] ?? 0;
        overlapCount[coordKey] = overlap + 1;

        final jitteredLocation = LatLng(
          order.location.latitude + (overlap * 0.00005),
          order.location.longitude + (overlap * 0.00005),
        );

        final isSelected = widget.selectedOrder?.id == order.id;

        return Marker(
          point: jitteredLocation,
          width: isSelected ? 80 : 70,
          height: isSelected ? 90 : 80,
          child: GestureDetector(
            onTap: () {
              if (widget.onOrderSelected != null) {
                widget.onOrderSelected!(order);
              }
              if (widget.onOrderTap != null) {
                widget.onOrderTap!();
              }
            },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Earnings + ID badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emeraldGreen,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '₹${order.earnings.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '#${order.shortId}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // Pin
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.emeraldGreen, width: 2),
                ),
                child: const Icon(
                  Icons.shopping_bag,
                  color: AppColors.emeraldGreen,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  /// Build map control buttons
  Widget _buildMapControls(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(Icons.add, _zoomIn, isDark),
          Container(
            height: 1,
            width: 30,
            color: isDark ? Colors.white12 : Colors.grey[300],
          ),
          _buildControlButton(Icons.remove, _zoomOut, isDark),
          Container(
            height: 1,
            width: 30,
            color: isDark ? Colors.white12 : Colors.grey[300],
          ),
          _buildControlButton(
            Icons.my_location,
            _centerOnUser,
            isDark,
            isAccent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    bool isAccent = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: isAccent
                ? AppColors.emeraldGreen
                : (isDark ? Colors.white70 : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error, bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple triangle painter for marker pointer
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
