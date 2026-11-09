import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/services/location_service.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialCity;
  final String? initialAddress;

  const MapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialCity,
    this.initialAddress,
  });

  static Future<LocationResult?> pick(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String? initialCity,
    String? initialAddress,
  }) {
    return Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          initialCity: initialCity,
          initialAddress: initialAddress,
        ),
      ),
    );
  }

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  late final MapController _mapController;
  late final TextEditingController _addressController;

  LatLng _currentCenter = const LatLng(32.8530, 35.1970); // Default: Galilee center
  LatLng? _selectedPoint;
  double _currentZoom = 14.0;
  bool _isLocatingUser = false;

  // Design Tokens
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF);
  static Color get surfaceField => _isDark ? const Color(0xFF171A19) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF242927) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF0F766E);
  static const Color brandYellow = Color(0xFFFFD600);
  static Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);

  // Pre-configured coordinates for common towns & work sites
  static final Map<String, LatLng> _townCoordinates = {
    'طمرة': const LatLng(32.8530, 35.1970),
    'كابول': const LatLng(32.8680, 35.2100),
    'طمرة+ قبول': const LatLng(32.8600, 35.2030),
    'طمرة+ كبول': const LatLng(32.8600, 35.2030),
    'טמרה': const LatLng(32.8530, 35.1970),
    'קבול': const LatLng(32.8680, 35.2100),
    'טמרה+ קבול': const LatLng(32.8600, 35.2030),
    'سخنين': const LatLng(32.8660, 35.3000),
    'סכנין': const LatLng(32.8660, 35.3000),
    'مجد الكروم': const LatLng(32.9190, 35.2570),
    'دير الاسد': const LatLng(32.9300, 35.2700),
    'البعنة': const LatLng(32.9260, 35.2650),
    'شفاعمرو': const LatLng(32.8050, 35.1700),
    'شفا عمرو': const LatLng(32.8050, 35.1700),
    'שפרעם': const LatLng(32.8050, 35.1700),
    'مغار': const LatLng(32.8900, 35.4050),
    'كفر كنا': const LatLng(32.7470, 35.3380),
    'كفركنا': const LatLng(32.7470, 35.3380),
    'الناصرة': const LatLng(32.7000, 35.3000),
    'נצרת': const LatLng(32.7000, 35.3000),
    'الرينة': const LatLng(32.7230, 35.3180),
    'كفر مندا': const LatLng(32.8120, 35.2600),
    'عرابة': const LatLng(32.8550, 35.3380),
    'عكا': const LatLng(32.9280, 35.0820),
    'دبرات': const LatLng(32.6950, 35.3850),
    'דבראת': const LatLng(32.6950, 35.3850),
    'موضيعين': const LatLng(31.8900, 35.0100),
    'القدس': const LatLng(31.7683, 35.2137),
    'ירושלים': const LatLng(31.7683, 35.2137),
    'تل ابيب': const LatLng(32.0853, 34.7818),
    'رام الله': const LatLng(31.9038, 35.2034),
    'حيفا': const LatLng(32.7940, 34.9896),
    'חיפה': const LatLng(32.7940, 34.9896),
    'كريات بيالك': const LatLng(32.8333, 35.0833),
    'קרית ביאליק': const LatLng(32.8333, 35.0833),
    'مبوا حوران': const LatLng(31.8480, 35.0350),
    'مبؤوت حوران': const LatLng(31.8480, 35.0350),
    'مبؤوت حرون': const LatLng(31.8480, 35.0350),
    'مبؤوت حورون': const LatLng(31.8480, 35.0350),
    'מצפה אביב': const LatLng(32.8320, 35.2070),
    'يركا': const LatLng(32.9550, 35.1950),
    'ابو سنان': const LatLng(32.9580, 35.1700),
    'كفر ياسيف': const LatLng(32.9530, 35.1630),
    'كرمئيل': const LatLng(32.9130, 35.2960),
    'כרמיאל': const LatLng(32.9130, 35.2960),
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // 1. Initial coordinates from passed data
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _currentCenter = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _selectedPoint = _currentCenter;
      _currentZoom = 15.0;
    } else if (widget.initialCity != null && widget.initialCity!.trim().isNotEmpty) {
      final cityKey = widget.initialCity!.trim();
      final match = _findTownCoordinates(cityKey);
      if (match != null) {
        _currentCenter = match;
        _selectedPoint = match;
        _currentZoom = 14.5;
      }
    }

    _addressController = TextEditingController(
      text: widget.initialAddress ?? widget.initialCity ?? '',
    );
  }

  LatLng? _findTownCoordinates(String text) {
    final clean = text.trim();
    for (final entry in _townCoordinates.entries) {
      if (clean.toLowerCase().contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(clean.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _onTapMap(TapPosition tapPosition, LatLng point) {
    SpendoHaptics.light();
    setState(() {
      _selectedPoint = point;
    });
  }

  Future<void> _flyToCurrentGps() async {
    SpendoHaptics.light();
    setState(() => _isLocatingUser = true);
    try {
      final loc = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;
      if (loc != null) {
        final pt = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _selectedPoint = pt;
          _currentCenter = pt;
          _currentZoom = 16.0;
          _isLocatingUser = false;
        });
        _mapController.move(pt, 16.0);
        SpendoHaptics.success();
      } else {
        setState(() => _isLocatingUser = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديد موقع GPS، يرجى تفعيل الموقع أو تحديده يدوياً من الخريطة'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLocatingUser = false);
    }
  }

  void _jumpToTown(String townName, LatLng coords) {
    SpendoHaptics.selection();
    setState(() {
      _selectedPoint = coords;
      _currentCenter = coords;
      _currentZoom = 14.5;
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = townName;
      }
    });
    _mapController.move(coords, 14.5);
  }

  void _confirmSelection() {
    final pt = _selectedPoint ?? _currentCenter;
    SpendoHaptics.success();
    Navigator.pop(
      context,
      LocationResult(
        latitude: pt.latitude,
        longitude: pt.longitude,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : widget.initialCity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePoint = _selectedPoint ?? _currentCenter;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0B0B),
        appBar: AppBar(
          backgroundColor: surfaceMain,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Remix.arrow_right_line, color: textWhite),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحديد موقع العمل على الخريطة',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textWhite),
              ),
              Text(
                'انقر على أي شارع أو بلد لتثبيت مكان العمل بدقة',
                style: TextStyle(fontSize: 9.5, color: textMuted),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Remix.check_line, size: 15),
                label: const Text('تثبيت', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _confirmSelection,
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // 1. الخريطة التفاعلية بالكامل
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: _currentZoom,
                minZoom: 6.0,
                maxZoom: 18.5,
                onTap: _onTapMap,
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture) {
                    _currentCenter = pos.center;
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.finance.spendo',
                  tileBuilder: (context, tileWidget, tile) {
                    // Slight dark mode tint for the map to match Obsidian palette
                    return ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.85, 0, 0, 0, 0,
                        0, 0.85, 0, 0, 0,
                        0, 0, 0.85, 0, 0,
                        0, 0, 0, 1.0, 0,
                      ]),
                      child: tileWidget,
                    );
                  },
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: activePoint,
                      width: 50,
                      height: 50,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: brandGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Remix.map_pin_fill,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. شريط القفز السريع للبلدات الأكثر تكراراً
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: surfaceMain.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaceBorder),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Remix.navigation_line, size: 13, color: brandYellow),
                        const SizedBox(width: 6),
                        Text(
                          'انتقال سريع للبلد / المنطقة:',
                          style: TextStyle(color: textWhite, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${activePoint.latitude.toStringAsFixed(4)}, ${activePoint.longitude.toStringAsFixed(4)}',
                          style: TextStyle(color: textMuted, fontSize: 9.5, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          'طمرة',
                          'كابول',
                          'سخنين',
                          'شفاعمرو',
                          'مجد الكروم',
                          'دير الاسد',
                          'كفر كنا',
                          'الناصرة',
                          'عكا',
                          'حيفا',
                          'القدس',
                          'دبرات',
                        ].map((town) {
                          final coords = _townCoordinates[town];
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () {
                                if (coords != null) _jumpToTown(town, coords);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: surfaceBorder),
                                ),
                                child: Text(
                                  town,
                                  style: TextStyle(color: textWhite, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. أزرار التحكم الجانبية (تكبير، تصغير، موقعي الحالي)
            Positioned(
              left: 12,
              bottom: 120,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_gps',
                    backgroundColor: surfaceMain,
                    foregroundColor: brandYellow,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: surfaceBorder),
                    ),
                    onPressed: _isLocatingUser ? null : _flyToCurrentGps,
                    child: _isLocatingUser
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: brandYellow),
                          )
                        : const Icon(Remix.crosshair_2_line, size: 18),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_in',
                    backgroundColor: surfaceMain,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: surfaceBorder),
                    ),
                    onPressed: () {
                      final z = (_mapController.camera.zoom + 1).clamp(6.0, 18.0);
                      _mapController.move(_mapController.camera.center, z);
                    },
                    child: const Icon(Remix.add_line, size: 18),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_out',
                    backgroundColor: surfaceMain,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: surfaceBorder),
                    ),
                    onPressed: () {
                      final z = (_mapController.camera.zoom - 1).clamp(6.0, 18.0);
                      _mapController.move(_mapController.camera.center, z);
                    },
                    child: const Icon(Remix.subtract_line, size: 18),
                  ),
                ],
              ),
            ),

            // 4. البطاقة السفلية لتأكيد المكان وتسمية الشارع / الورشة
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: surfaceMain.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: surfaceBorder),
                    boxShadow: const [
                      BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Remix.map_pin_2_line, color: brandGreen, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              style: TextStyle(color: textWhite, fontSize: 12.5, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'اكتب اسم الشارع أو تفصيل المكان (اختياري)',
                                hintStyle: TextStyle(color: textMuted, fontSize: 11),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(color: surfaceBorder, height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Remix.check_line, size: 16),
                              label: const Text(
                                'تثبيت هذا الموقع لمكان العمل',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                              onPressed: _confirmSelection,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
