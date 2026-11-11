import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../models/local_models.dart';

const Color _mapInk = Color(0xFF172B36);

/// Interactive map showing support locations (Clinics, Schools, NGOs) across Arua.
/// Supports both OpenStreetMap (real interactive street tiles) and PadCare's
/// zero-data stylized offline canvas painter.
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
  late bool _showStreetMap;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _showStreetMap = widget.initialUseStreetMap;
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant InteractiveAruaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPoint.id != widget.selectedPoint.id && _showStreetMap) {
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
          child: _showStreetMap ? _buildFlutterMap() : _buildCanvasMap(),
        ),

        // Mode switch pill: Streets vs Offline Canvas
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeTab(
                  label: 'Streets',
                  icon: Icons.map_rounded,
                  active: _showStreetMap,
                  onTap: () => setState(() => _showStreetMap = true),
                ),
                _buildModeTab(
                  label: 'Offline Canvas',
                  icon: Icons.palette_outlined,
                  active: !_showStreetMap,
                  onTap: () => setState(() => _showStreetMap = false),
                ),
              ],
            ),
          ),
        ),

        // Zoom & Recenter controls (Streets mode only)
        if (_showStreetMap)
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
        if (_showStreetMap)
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

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF116B78) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
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
              final icon = pt.category == 'Clinics'
                  ? Icons.local_hospital_rounded
                  : (pt.category == 'Schools' ? Icons.school_rounded : Icons.volunteer_activism_rounded);

              final pinColor = isSelected
                  ? const Color(0xFF116B78)
                  : (pt.category == 'Schools'
                      ? const Color(0xFFEA580C)
                      : (pt.category == 'Clinics' ? const Color(0xFF0D9488) : const Color(0xFF16A34A)));

              return Marker(
                point: LatLng(pt.latitude, pt.longitude),
                width: 78,
                height: 78,
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

  Widget _buildCanvasMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            CustomPaint(
              size: Size(w, h),
              painter: AruaMapPainter(
                selectedPointId: widget.selectedPoint.id,
              ),
            ),
            ...widget.points.map((pt) {
              final x = pt.mapOffsetPercent.dx * w;
              final y = pt.mapOffsetPercent.dy * h;
              final isSelected = pt.id == widget.selectedPoint.id;
              final icon = pt.category == 'Clinics'
                  ? Icons.local_hospital_rounded
                  : (pt.category == 'Schools' ? Icons.school_rounded : Icons.volunteer_activism_rounded);
              final pinColor = isSelected
                  ? const Color(0xFF116B78)
                  : (pt.category == 'Schools'
                      ? const Color(0xFFEA580C)
                      : (pt.category == 'Clinics' ? const Color(0xFF0D9488) : const Color(0xFF16A34A)));

              return Positioned(
                left: x - 35,
                top: y - 55,
                child: MapTeardropPin(
                  label: pt.pinLabel,
                  icon: icon,
                  isSelected: isSelected,
                  customColor: pinColor,
                  onTap: () => widget.onSelect(pt),
                ),
              );
            }),
          ],
        );
      },
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFF116B78) : _mapInk,
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

class AruaMapPainter extends CustomPainter {
  const AruaMapPainter({
    required this.selectedPointId,
  });

  final String selectedPointId;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = const Color(0xFFE4F3EE);
    canvas.drawRect(Offset.zero & size, basePaint);

    final parkPaint = Paint()..color = const Color(0xFFD2EADB);
    final park1 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.04, size.height * 0.08, size.width * 0.36, size.height * 0.24),
        const Radius.circular(36),
      ));
    canvas.drawPath(park1, parkPaint);

    final park2 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.65, size.height * 0.12, size.width * 0.35, size.height * 0.28),
        const Radius.circular(46),
      ));
    canvas.drawPath(park2, parkPaint);

    final park3 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.42, size.height * 0.64, size.width * 0.52, size.height * 0.32),
        const Radius.circular(44),
      ));
    canvas.drawPath(park3, parkPaint);

    final riverPaint = Paint()
      ..color = const Color(0xFFA6D9D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(size.width * 0.12, 0)
      ..cubicTo(
        size.width * 0.28, size.height * 0.32,
        size.width * 0.14, size.height * 0.62,
        size.width * 0.46, size.height,
      );
    canvas.drawPath(riverPath, riverPaint);

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFDFD7C2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    final roadFillPaint = Paint()
      ..color = const Color(0xFFFBF6EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.50, size.height * 0.48);

    final roadPaths = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.72, size.height * 0.28)
      ..lineTo(size.width * 0.86, 0)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.24, size.height * 0.38)
      ..lineTo(0, size.height * 0.34)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.28, size.height * 0.68)
      ..lineTo(0, size.height * 0.86)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.62, size.height * 0.68)
      ..lineTo(size.width * 0.84, size.height)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width, size.height * 0.54)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.44, 0);

    canvas.drawPath(roadPaths, roadBorderPaint);
    canvas.drawPath(roadPaths, roadFillPaint);

    final minorBorderPaint = Paint()
      ..color = const Color(0xFFE5DEC8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final minorFillPaint = Paint()
      ..color = const Color(0xFFFBF6EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final minorPaths = Path()
      ..moveTo(size.width * 0.24, size.height * 0.38)
      ..lineTo(size.width * 0.42, size.height * 0.16)
      ..lineTo(size.width * 0.72, size.height * 0.28)
      ..moveTo(size.width * 0.28, size.height * 0.68)
      ..lineTo(size.width * 0.62, size.height * 0.68);

    canvas.drawPath(minorPaths, minorBorderPaint);
    canvas.drawPath(minorPaths, minorFillPaint);

    canvas.drawCircle(center, 13, Paint()..color = const Color(0xFFDFD7C2));
    canvas.drawCircle(center, 10, Paint()..color = const Color(0xFFFBF6EB));
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF498877));

    _drawTree(canvas, Offset(size.width * 0.15, size.height * 0.15));
    _drawTree(canvas, Offset(size.width * 0.24, size.height * 0.13));
    _drawTree(canvas, Offset(size.width * 0.78, size.height * 0.21));
    _drawTree(canvas, Offset(size.width * 0.74, size.height * 0.36));
    _drawTree(canvas, Offset(size.width * 0.12, size.height * 0.53));
    _drawTree(canvas, Offset(size.width * 0.58, size.height * 0.83));

    _drawHighwayBadge(canvas, Offset(size.width * 0.22, size.height * 0.24), '18');
  }

  void _drawTree(Canvas canvas, Offset pos) {
    final foliage = Paint()..color = const Color(0xFF3F7F70);
    final trunk = Paint()..color = const Color(0xFF8D735C)..strokeWidth = 2;
    canvas.drawLine(pos, Offset(pos.dx, pos.dy + 8), trunk);

    final path = Path()
      ..moveTo(pos.dx, pos.dy - 6)
      ..lineTo(pos.dx - 6, pos.dy + 2)
      ..lineTo(pos.dx + 6, pos.dy + 2)
      ..close()
      ..moveTo(pos.dx, pos.dy - 2)
      ..lineTo(pos.dx - 8, pos.dy + 6)
      ..lineTo(pos.dx + 8, pos.dy + 6)
      ..close();
    canvas.drawPath(path, foliage);
  }

  void _drawHighwayBadge(Canvas canvas, Offset pos, String number) {
    final rect = Rect.fromCenter(center: pos, width: 22, height: 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF2E7D32),
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant AruaMapPainter oldDelegate) =>
      oldDelegate.selectedPointId != selectedPointId;
}

typedef _AruaMapPainter = AruaMapPainter;
