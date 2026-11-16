import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../models/local_models.dart';

const Color _mapInk = Color(0xFF172B36);

/// Interactive map showing support locations (Clinics, Hospitals, Schools, NGOs, Dispensing Centers) across Arua.
/// Powered by OpenStreetMap real interactive street tiles.
class InteractiveAruaMap extends StatefulWidget {
  const InteractiveAruaMap({
    super.key,
    required this.points,
    required this.selectedPoint,
    required this.onSelect,
    this.initialUseStreetMap = true,
  });

  final List<SupportPoint> points;
  final SupportPoint selectedPoint;
  final ValueChanged<SupportPoint> onSelect;
  final bool initialUseStreetMap;

  @override
  State<InteractiveAruaMap> createState() => _InteractiveAruaMapState();
}

class _InteractiveAruaMapState extends State<InteractiveAruaMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant InteractiveAruaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPoint.id != widget.selectedPoint.id) {
      try {
        _mapController.move(
          LatLng(widget.selectedPoint.latitude, widget.selectedPoint.longitude),
          14.5,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, currentZoom + 1);
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, currentZoom - 1);
    } catch (_) {}
  }

  void _recenter() {
    try {
      _mapController.move(
        LatLng(widget.selectedPoint.latitude, widget.selectedPoint.longitude),
        14.5,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildFlutterMap(),
        ),

        // Zoom & Recenter controls
        Positioned(
          top: 70,
          right: 14,
          child: Column(
            children: [
              _buildControlButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onTap: _zoomIn,
              ),
              const SizedBox(height: 6),
              _buildControlButton(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onTap: _zoomOut,
              ),
              const SizedBox(height: 6),
              _buildControlButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Recenter',
                onTap: _recenter,
              ),
            ],
          ),
        ),

        // OpenStreetMap Attribution (Legal requirement for OSM)
        Positioned(
          bottom: 6,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2.5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: const Color(0xFF116B78)),
        ),
      ),
    );
  }

  Widget _buildFlutterMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(widget.selectedPoint.latitude, widget.selectedPoint.longitude),
        initialZoom: 14.2,
        minZoom: 11.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'org.padcare.app',
        ),
        MarkerLayer(
          markers: [
            // User location pin (Blue Dot in Arua Center)
            const Marker(
              point: LatLng(3.0215, 30.9115),
              width: 28,
              height: 28,
              child: _UserLocationMarker(),
            ),
            // Facility pins
            ...widget.points.map((pt) {
              final isSelected = pt.id == widget.selectedPoint.id;
              final cat = pt.category.toLowerCase();
              final IconData icon;
              final Color pinColor;

              if (cat.contains('clinic') || cat.contains('hospital')) {
                icon = Icons.local_hospital_rounded;
                pinColor = isSelected ? const Color(0xFF116B78) : const Color(0xFF0D9488);
              } else if (cat.contains('school')) {
                icon = Icons.school_rounded;
                pinColor = isSelected ? const Color(0xFF116B78) : const Color(0xFFEA580C);
              } else if (cat.contains('dispens') || cat.contains('hub') || cat.contains('center')) {
                icon = Icons.inventory_2_rounded;
                pinColor = isSelected ? const Color(0xFF116B78) : const Color(0xFF16A34A);
              } else {
                icon = Icons.volunteer_activism_rounded;
                pinColor = isSelected ? const Color(0xFF116B78) : const Color(0xFF2563EB);
              }

              return Marker(
                point: LatLng(pt.latitude, pt.longitude),
                width: 96,
                height: 80,
                alignment: Alignment.topCenter,
                child: MapTeardropPin(
                  label: pt.pinLabel,
                  icon: icon,
                  isSelected: isSelected,
                  customColor: pinColor,
                  onTap: () {
                    widget.onSelect(pt);
                    _mapController.move(LatLng(pt.latitude, pt.longitude), 15.0);
                  },
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}

typedef _InteractiveAruaMap = InteractiveAruaMap;

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0x332563EB),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }
}

class MapTeardropPin extends StatelessWidget {
  const MapTeardropPin({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.customColor,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? customColor;

  @override
  Widget build(BuildContext context) {
    final pinColor = isSelected ? const Color(0xFF116B78) : (customColor ?? const Color(0xFF2EA8B6));
    final size = isSelected ? 38.0 : 28.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📍', style: TextStyle(fontSize: 9)),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF116B78) : _mapInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          CustomPaint(
            size: Size(size, size * 1.25),
            painter: TeardropPinPainter(
              color: pinColor,
              isSelected: isSelected,
            ),
            child: SizedBox(
              width: size,
              height: size * 1.25,
              child: Padding(
                padding: EdgeInsets.only(bottom: size * 0.25),
                child: Center(
                  child: Icon(
                    icon,
                    size: isSelected ? 18 : 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _MapTeardropPin = MapTeardropPin;

class TeardropPinPainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  const TeardropPinPainter({required this.color, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;

    final path = Path()
      ..moveTo(r, h)
      ..cubicTo(w * 0.12, h * 0.65, 0, h * 0.45, 0, r)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..cubicTo(w, h * 0.45, w * 0.88, h * 0.65, r, h)
      ..close();

    final shadowPaint = Paint()
      ..color = const Color(0x38000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    final fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.8;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant TeardropPinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isSelected != isSelected;
}

typedef _TeardropPinPainter = TeardropPinPainter;

/// Legacy stub retained for backwards compatibility. Canvas map is deprecated in favor of OpenStreetMap.
class AruaMapPainter extends CustomPainter {
  const AruaMapPainter({
    this.selectedPointId = '',
  });

  final String selectedPointId;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant AruaMapPainter oldDelegate) => false;
}

typedef _AruaMapPainter = AruaMapPainter;
