import '../../../../core/theme/app_theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/israel_gov_api_service.dart';
import '../../../../core/services/receipt_ocr_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../models/vehicle_model.dart';
import '../widgets/fuel_expense_sheet.dart';
import '../../../settings/presentation/screens/app_settings_screen.dart';

class VehicleTrackerScreen extends StatefulWidget {
  const VehicleTrackerScreen({super.key});

  @override
  State<VehicleTrackerScreen> createState() => _VehicleTrackerScreenState();
}

class _VehicleTrackerScreenState extends State<VehicleTrackerScreen> {
  static const String _storageKey = 'spendo_vehicle_tracker_v5';
  VehicleDataState _state = VehicleDataState.initial();
  bool _isLoading = true;
  bool _showAllHistory = true;
  String _selectedMonthKey = 'all';
  bool _isOdometerEditOpen = false;
  late final TextEditingController _odometerController;

  GovVehicleInfo? _govInfo;
  double _officialFuelPrice = 7.68;
  bool _isGovSyncing = false;

  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121413) : const Color(0xFFF8F9FA);
  static Color get surfaceField => _isDark ? const Color(0xFF171A19) : const Color(0xFFFFFFFF);
  static Color get surfaceBorder => _isDark ? const Color(0xFF242927) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF00A86B);
  static const Color brandYellow = Color(0xFFEAB308);
  static const Color brandRed = Color(0xFFEF4444);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);
  static Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _odometerController =
        TextEditingController(text: _state.currentOdometer.toString());
    DatabaseHelper.dataVersionNotifier.addListener(_loadState);
    _loadState();
  }

  @override
  void dispose() {
    DatabaseHelper.dataVersionNotifier.removeListener(_loadState);
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final cachedGov = await IsraelGovApiService.getCachedVehicleInfo();
    final cachedFuelPrice = await IsraelGovApiService.getCachedFuel95Price();

    if (raw != null && raw.isNotEmpty) {
      try {
        final loadedState = VehicleDataState.fromJson(raw);
        final rawCount = (jsonDecode(raw)['history'] as List?)?.length ?? 0;
        if (loadedState.history.length < rawCount) {
          await prefs.setString(_storageKey, loadedState.toJson());
        }
        if (mounted) {
          setState(() {
            _state = loadedState;
            _govInfo = cachedGov;
            _officialFuelPrice = cachedFuelPrice;
            _odometerController.text = _state.currentOdometer.toString();
            _isLoading = false;
          });
        }
        _syncWithIsraelGovApi();
        return;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _govInfo = cachedGov;
        _officialFuelPrice = cachedFuelPrice;
        _isLoading = false;
      });
    }
    _syncWithIsraelGovApi();
  }

  /// مزامنة بيانات المركبة وتاريخ التست وسعر البنزين الرسمي مباشرة من بوابة الحكومة الإسرائيلية (data.gov.il)
  Future<void> _syncWithIsraelGovApi({String? customPlate}) async {
    if (_isGovSyncing) return;
    if (mounted) setState(() => _isGovSyncing = true);

    try {
      // استخراج رقم النمرة من اسم المركبة (مثال: 55-505-403) أو استخدام الرقم الممرر
      String plateToQuery = customPlate ?? '';
      if (plateToQuery.isEmpty) {
        final digits = _state.vehicleName.replaceAll(RegExp(r'[^0-9]'), '');
        plateToQuery = digits.length >= 7 ? digits : '55505403';
      }

      final results = await Future.wait([
        IsraelGovApiService.fetchVehicleByPlate(plateToQuery),
        IsraelGovApiService.fetchOfficialFuel95Price(),
      ]);

      final info = results[0] as GovVehicleInfo?;
      final fuelPrice = results[1] as double;

      if (!mounted) return;
      setState(() {
        if (info != null) {
          _govInfo = info;
        }
        _officialFuelPrice = fuelPrice;
        _isGovSyncing = false;
      });

      // تحديث تاريخ التست (טסט) واسم الكتنوع التجاري تلقائياً
      if (info != null) {
        final cleanTitle = info.rawPlate == '55505403'
            ? 'SYM Joyride 200 (55-505-403)'
            : _state.vehicleName;
        await _saveState(_state.copyWith(
          vehicleName: cleanTitle,
          testExpiry: info.testExpiryDate ?? _state.testExpiry,
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _isGovSyncing = false);
    }
  }

  Future<void> _saveState(VehicleDataState newState) async {
    setState(() {
      _state = newState;
      _odometerController.text = newState.currentOdometer.toString();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, newState.toJson());
  }

  Color _getStatusColor(MaintenancePart part) {
    final remaining = part.remainingKm(_state.currentOdometer);
    final ratio = part.remainingRatio(_state.currentOdometer);
    if (remaining <= 0) return brandRed; // أحمر: تجاوز الموعد
    if (remaining < 600 || ratio <= 0.25) {
      return brandYellow; // أصفر: اقترب الموعد
    }
    return brandGreen; // أخضر: متزن ومريح للعين
  }

  IconData _getPartIcon(MaintenancePart part) {
    final remaining = part.remainingKm(_state.currentOdometer);
    if (remaining <= 0) {
      return Remix.error_warning_line;
    }
    switch (part.iconName) {
      case 'oil':
        return Remix.drop_line;
      case 'gear':
        return Remix.settings_5_line;
      case 'belt':
        return Remix.links_line;
      case 'tire':
        return Remix.lifebuoy_line;
      case 'disc':
        return Remix.disc_line;
      default:
        return Remix.disc_line;
    }
  }

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: surfaceMain,
        body: Center(
          child: CircularProgressIndicator(color: brandGreen),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: surfaceMain,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderBar(),
                const SizedBox(height: 12),
                _buildHeroOdometerCard(),
                const SizedBox(height: 10),
                _buildInsuranceAndTestRow(),
                const SizedBox(height: 10),
                _buildMaintenanceGrid(),
                const SizedBox(height: 12),
                _buildQuickActionButtons(),
                const SizedBox(height: 12),
                _buildMonthlySummaryAndHistory(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. الترويسة العلوية (أيقونات نظيفة بدون أي خلفية)
  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Remix.motorbike_line,
                color: brandGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المركبة والصيانة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textWhite,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'متابعة صحة الدراجة ومصروف الوقود',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  SpendoHaptics.light();
                  _showInvoiceParserSheet();
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(
                    Remix.file_edit_line,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () async {
                  SpendoHaptics.light();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AppSettingsScreen(),
                    ),
                  );
                  _loadState();
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(
                    Remix.settings_4_line,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. بطاقة المركبة والعداد (مدمجة وأنيقة بدون فراغات ضخمة)
  Widget _buildHeroOdometerCard() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vehicle Name + Subtitle + Update Button
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xB3242927),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Remix.dashboard_3_line,
                        color: brandGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _state.vehicleName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textWhite,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    SpendoHaptics.light();
                                    _showEditVehicleNameDialog();
                                  },
                                  child: const Icon(
                                    Remix.pencil_line,
                                    color: Color(0xFF6B7280),
                                    size: 12,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'لوحة قيادة المركبة والعداد',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    SpendoHaptics.light();
                    setState(() {
                      _isOdometerEditOpen = !_isOdometerEditOpen;
                      if (_isOdometerEditOpen) {
                        _odometerController.text =
                            _state.currentOdometer.toString();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: surfaceMain,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: brandGreen.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Remix.add_line,
                          color: brandGreen,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'تحديث العداد',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: brandGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Current Odometer Row
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'قراءة الكيلومترات الحالية:',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    SpendoHaptics.light();
                    _showUpdateOdometerSheet();
                  },
                  child: Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatNumber(_state.currentOdometer),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textWhite,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'كم',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: brandYellow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Inline Quick Odometer Edit Box
          if (_isOdometerEditOpen) ...[
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: surfaceBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _odometerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 12,
                          color: textWhite,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          hintText: 'أدخل العداد الجديد...',
                          hintStyle: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                          fillColor: surfaceMain,
                          filled: true,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: surfaceBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: surfaceBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: brandGreen),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () {
                      final val = int.tryParse(_odometerController.text.trim());
                      if (val != null && val > 0) {
                        SpendoHaptics.success();
                        _saveState(_state.copyWith(currentOdometer: val));
                        setState(() => _isOdometerEditOpen = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'حفظ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // شريط بيانات وزارة المواصلات وسعر البنزين الرسمي (data.gov.il)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xB3242927)),
              ),
            ),
            child: InkWell(
              onTap: () {
                SpendoHaptics.light();
                _showIsraelGovVehicleSheet();
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _isGovSyncing
                              ? Remix.loader_4_line
                              : Remix.government_line,
                          size: 13,
                          color: brandGreen,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _govInfo != null
                                ? 'רשמי (data.gov.il): ${_govInfo!.manufacturer} ${_govInfo!.modelName} • ${_govInfo!.year} • ${_govInfo!.engineCc > 0 ? '${_govInfo!.engineCc} סמ"ק' : _govInfo!.fuelType}'
                                : 'بيانات وزارة المواصلات (data.gov.il) • اضغط للمزامنة برقم النمرة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: brandYellow.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: brandYellow.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'بنزين 95: ${_officialFuelPrice.toStringAsFixed(2)} ₪/لتر',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: brandYellow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// نافذة عرض ومزامنة بيانات المركبة الرسمية وسعر البنزين من بوابة الحكومة الإسرائيلية (data.gov.il)
  void _showIsraelGovVehicleSheet() {
    final digits = _state.vehicleName.replaceAll(RegExp(r'[^0-9]'), '');
    final plateCtrl = TextEditingController(
      text: _govInfo?.rawPlate ?? (digits.length >= 7 ? digits : '55505403'),
    );
    bool isSearching = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
            final bottomPad = MediaQuery.of(ctx).padding.bottom;
            final info = _govInfo;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: keyboardInset > 0
                        ? keyboardInset + 10
                        : (bottomPad > 0 ? bottomPad + 10 : 16),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 34,
                            height: 4,
                            decoration: BoxDecoration(
                              color: surfaceBorder,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Remix.government_line,
                                    color: brandGreen, size: 19),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'بيانات وزارة المواصلات',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textWhite,
                                      ),
                                    ),
                                    Text(
                                      'سحب مباشر ومجاني لبيانات الترخيص والكراج المعتمد',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(Remix.close_line,
                                  color: Color(0xFF9CA3AF), size: 19),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(color: surfaceBorder, height: 1),
                        const SizedBox(height: 10),

                        // حقل إدخال رقم اللوحة (النمرة) للبحث الفوري في data.gov.il
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: brandYellow),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'IL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: brandYellow,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: plateCtrl,
                                        keyboardType: TextInputType.number,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          color: textWhite,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'رقم النمرة (7 أو 8 أرقام)',
                                          hintStyle: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B7280)),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 40),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: isSearching
                                  ? null
                                  : () async {
                                      final q = plateCtrl.text.trim();
                                      if (q.length < 6) return;
                                      setSheetState(() {
                                        isSearching = true;
                                        errorMsg = null;
                                      });
                                      final fetched = await IsraelGovApiService
                                          .fetchVehicleByPlate(q);
                                      final fuel = await IsraelGovApiService
                                          .fetchOfficialFuel95Price();
                                      if (!mounted) return;
                                      setState(() {
                                        if (fetched != null) {
                                          _govInfo = fetched;
                                        }
                                        _officialFuelPrice = fuel;
                                      });
                                      if (fetched != null) {
                                        SpendoHaptics.success();
                                        final newTitle = fetched.rawPlate == '55505403'
                                            ? 'SYM Joyride 200 (55-505-403)'
                                            : '${fetched.manufacturer} ${fetched.modelName} (${fetched.plateNumber})';
                                        await _saveState(_state.copyWith(
                                          vehicleName: newTitle,
                                          testExpiry: fetched.testExpiryDate ??
                                              _state.testExpiry,
                                        ));
                                      }
                                      setSheetState(() {
                                        isSearching = false;
                                        if (fetched == null) {
                                          errorMsg =
                                              'لم يتم العثور على مركبة أو دراجة بهذا الرقم في سجل وزارة المواصلات';
                                        }
                                      });
                                    },
                              icon: Icon(
                                isSearching
                                    ? Remix.loader_4_line
                                    : Remix.refresh_line,
                                size: 15,
                              ),
                              label: Text(
                                isSearching ? 'جاري السحب...' : 'سحب من الوزارة',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                        if (errorMsg != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorMsg!,
                            style: const TextStyle(
                                fontSize: 10.5, color: brandRed),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // بطاقة البيانات الرسمية المسحوبة من משרד התחבורה
                        if (info != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceField,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: surfaceBorder),
                            ),
                            child: Column(
                              children: [
                                _buildGovRow('رقم اللوحة (מספר רישוי)',
                                    info.plateNumber,
                                    highlight: true),
                                _buildGovRow('الشركة والموديل (תוצר ודגם)',
                                    '${info.manufacturer} • ${info.modelName} (${info.vehicleType})'),
                                _buildGovRow(
                                    'سنة الصنع ونزول الشارع',
                                    '${info.year} (${info.roadEntryMonth.isNotEmpty ? info.roadEntryMonth : 'רשמי'})'),
                                if (info.engineCc > 0)
                                  _buildGovRow('حجم المحرك والقوة',
                                      '${info.engineCc} סמ"ק • ${info.horsePower} כ"ס'),
                                if (info.frontTire.isNotEmpty ||
                                    info.rearTire.isNotEmpty)
                                  _buildGovRow('مقاس الإطارات الرسمي (צמיגים)',
                                      'أمامي: ${info.frontTire} | خلفي: ${info.rearTire}'),
                                if (info.chassisVin.isNotEmpty)
                                  _buildGovRow('رقم الشاصي (מספר שלדה)',
                                      info.chassisVin),
                                if (info.testExpiryDate != null)
                                  _buildGovRow(
                                    'موعد انتهاء التست (טסט)',
                                    '${info.testExpiryDate!.day.toString().padLeft(2, '0')}/${info.testExpiryDate!.month.toString().padLeft(2, '0')}/${info.testExpiryDate!.year}',
                                    highlight: true,
                                  ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 10),

                        // سجل الكراج المرخص المرتبط بالمركبة
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Remix.database_2_line,
                                      size: 14, color: brandGreen),
                                  SizedBox(width: 6),
                                  Text(
                                    'سجلات الدولة المفتوحة المرتبطة بمركبتك',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textWhite,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildGovRow(
                                'الكراج المرخص (מוסכים מורשים)',
                                'אור אמנוני מוסך אופנועים (#90766) • כרמיאל',
                                highlight: true,
                              ),
                              _buildGovRow(
                                'عنوان وهاتف الكراج الرسمي',
                                "רח' הנפח 20 א.תעשיה כרמיאל • 054-5991666",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGovRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: highlight ? brandGreen : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2.5 شريط التأمين والترخيص (التست) المدمج مع عداد الأيام المتبقية
  Widget _buildInsuranceAndTestRow() {
    return Row(
      children: [
        Expanded(
          child: _buildDocExpiryCard(
            title: 'تأمين المركبة (ביטוח)',
            icon: Remix.shield_check_line,
            expiryDate: _state.insuranceExpiry,
            onTap: () => _pickDocExpiryDate(isInsurance: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDocExpiryCard(
            title: 'ترخيص / تست (טסט)',
            icon: Remix.file_shield_2_line,
            expiryDate: _state.testExpiry,
            onTap: () => _pickDocExpiryDate(isInsurance: false),
          ),
        ),
      ],
    );
  }

  Widget _buildDocExpiryCard({
    required String title,
    required IconData icon,
    required DateTime expiryDate,
    required VoidCallback onTap,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysLeft = target.difference(today).inDays;

    final Color statusColor;
    final String remainingText;
    if (daysLeft < 0) {
      statusColor = brandRed;
      remainingText = 'منتهي منذ ${daysLeft.abs()} يوم';
    } else if (daysLeft == 0) {
      statusColor = brandRed;
      remainingText = 'ينتهي اليوم';
    } else if (daysLeft <= 30) {
      statusColor = brandYellow;
      remainingText = 'باقي $daysLeft يوم';
    } else {
      statusColor = brandGreen;
      remainingText = 'باقي $daysLeft يوم';
    }

    final formattedDate =
        '${expiryDate.day.toString().padLeft(2, '0')}/${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.year}';

    return InkWell(
      onTap: () {
        SpendoHaptics.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: surfaceField,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: daysLeft <= 30
                ? statusColor.withValues(alpha: 0.4)
                : surfaceBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: textWhite,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Remix.calendar_event_line,
                  size: 11,
                  color: Color(0xFF6B7280),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    remainingText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocExpiryDate({required bool isInsurance}) async {
    final initialDate =
        isInsurance ? _state.insuranceExpiry : _state.testExpiry;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: isInsurance
          ? 'تحديد تاريخ انتهاء التأمين (ביטוח)'
          : 'تحديد تاريخ انتهاء التست (טסט)',
      cancelText: 'إلغاء',
      confirmText: 'حفظ التاريخ',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: brandGreen,
              onPrimary: const Color(0xFF0A0B0B),
              surface: surfaceField,
              onSurface: Colors.white,
              secondary: brandYellow,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: surfaceMain,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: surfaceBorder),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      SpendoHaptics.success();
      if (isInsurance) {
        await _saveState(_state.copyWith(insuranceExpiry: picked));
      } else {
        await _saveState(_state.copyWith(testExpiry: picked));
      }
    }
  }

  // 3. شبكة بطاقات صحة القطع والصيانة (2×2 صغيرة ومرتبة وأيقونات بلا خلفية)
  Widget _buildMaintenanceGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _state.parts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final part = _state.parts[index];
        final remaining = part.remainingKm(_state.currentOdometer);
        final statusColor = _getStatusColor(part);
        final healthRatio = part.remainingRatio(_state.currentOdometer);

        final isExceeded = remaining <= 0;
        final isWarning =
            !isExceeded && (remaining < 600 || healthRatio <= 0.25);

        final borderColor = isExceeded
            ? brandRed.withValues(alpha: 0.4)
            : (isWarning ? brandYellow.withValues(alpha: 0.3) : surfaceBorder);

        final percentage = isExceeded ? 0 : (healthRatio * 100).round();

        final statusText = remaining > 0
            ? 'נותרו עוד ${_formatNumber(remaining)} ק"מ'
            : (remaining == 0
                ? 'נותרו עוד 0 ק"מ'
                : 'חריגה של ${_formatNumber(remaining.abs())} ק"מ!');

        return InkWell(
          onTap: () {
            SpendoHaptics.light();
            _showResetPartSheet(part);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: Icon + Percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      _getPartIcon(part),
                      color: statusColor,
                      size: 16,
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),

                // Middle: Part Title + Service subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      part.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 9,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),

                // Bottom: Progress bar + Remaining text
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 4,
                      decoration: BoxDecoration(
                        color: surfaceMain,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerRight,
                        widthFactor:
                            isExceeded ? 1.0 : healthRatio.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isExceeded ? FontWeight.bold : FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. أزرار الإجراءات السريعة (تعبئة وقود بالأخضر + تسجيل صيانة بالأصفر)
  Widget _buildQuickActionButtons() {
    return Row(
      children: [
        // تعبئة وقود
        Expanded(
          child: InkWell(
            onTap: () {
              SpendoHaptics.light();
              _showFuelExpenseSheet();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceField,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: brandGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Remix.gas_station_line,
                    size: 15,
                    color: brandGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'تعبئة وقود',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // تسجيل صيانة
        Expanded(
          child: InkWell(
            onTap: () {
              SpendoHaptics.light();
              _showMaintenanceExpenseSheet();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceField,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: brandYellow.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Remix.tools_line,
                    size: 15,
                    color: brandYellow,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'تسجيل صيانة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 5. قسم تصفية المصاريف والملخص وسجل الفواتير
  Widget _buildMonthlySummaryAndHistory() {
    // Unique months sorted desc
    final monthKeys = <String>{};
    for (final item in _state.history) {
      final key =
          '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      monthKeys.add(key);
    }
    final sortedMonthKeys = monthKeys.toList()..sort((a, b) => b.compareTo(a));

    // Filter items
    final filteredHistory = _selectedMonthKey == 'all'
        ? _state.history
        : _state.history.where((e) {
            final key =
                '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
            return key == _selectedMonthKey;
          }).toList();

    final displayHistory = _showAllHistory
        ? filteredHistory
        : filteredHistory.take(5).toList();

    final fuelItems = filteredHistory
        .where((e) => e.category == ExpenseCategory.fuel)
        .toList();

    final fuelTotal = fuelItems.fold(0.0, (sum, e) => sum + e.amount);
    final fuelLitersTotal =
        fuelItems.fold(0.0, (sum, e) => sum + (e.liters ?? 0.0));

    final maintenanceTotal = filteredHistory
        .where((e) => e.category == ExpenseCategory.maintenance)
        .fold(0.0, (sum, e) => sum + e.amount);

    final totalSpent = fuelTotal + maintenanceTotal;

    // تجميع مصروف الوقود الشهري (قديش كلفك كل شهر)
    final allFuelMonthKeys = <String>{};
    for (final item in _state.history) {
      if (item.category == ExpenseCategory.fuel) {
        final key =
            '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
        allFuelMonthKeys.add(key);
      }
    }
    final sortedFuelMonthKeys = allFuelMonthKeys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter title
          Row(
            children: [
              const Icon(
                Remix.calendar_2_line,
                size: 14,
                color: brandGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'تصفية المصاريف حسب الشهر',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal month chips
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildMonthChipItem(
                  keyName: 'all',
                  label: 'الكل (${_state.history.length})',
                ),
                ...sortedMonthKeys.map((k) {
                  final count = _state.history.where((e) {
                    final itemKey =
                        '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
                    return itemKey == k;
                  }).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildMonthChipItem(
                      keyName: k,
                      label:
                          '${ArabicDateHelper.formatMonthYearKey(k)} ($count)',
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3-Column Summary Box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: surfaceMain,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaceBorder),
            ),
            child: Row(
              children: [
                // Fuel
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'مصروف الوقود',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.ltr,
                        children: [
                          const Text(
                            '₪',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: brandGreen,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatNumber(fuelTotal.round()),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: brandGreen,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      if (fuelItems.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          '${fuelItems.length} تعبئات${fuelLitersTotal > 0 ? ' • ${fuelLitersTotal.toStringAsFixed(1)} لتر' : ''}',
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: surfaceBorder),
                // Maintenance
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'مصروف الصيانة',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.ltr,
                        children: [
                          const Text(
                            '₪',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: brandYellow,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatNumber(maintenanceTotal.round()),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: brandYellow,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: surfaceBorder),
                // Total
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'إجمالي المصاريف',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.ltr,
                        children: [
                          Text(
                            '₪',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatNumber(totalSpent.round()),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: textWhite,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (sortedFuelMonthKeys.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceMain,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Remix.gas_station_line, size: 13, color: brandGreen),
                      const SizedBox(width: 5),
                      Text(
                        'سجل تكلفة الوقود الشهري (حسب الفواتير والفروع)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: textWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...sortedFuelMonthKeys.map((mKey) {
                    final mFuelList = _state.history.where((e) {
                      if (e.category != ExpenseCategory.fuel) return false;
                      final k =
                          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
                      return k == mKey;
                    }).toList();
                    final mSum =
                        mFuelList.fold(0.0, (s, e) => s + e.amount);
                    final mLiters = mFuelList.fold(
                        0.0, (s, e) => s + (e.liters ?? 0.0));
                    final branches = mFuelList
                        .map((e) => (e.provider ?? '').trim())
                        .where((p) => p.isNotEmpty)
                        .toSet()
                        .join('، ');

                    return InkWell(
                      onTap: () {
                        SpendoHaptics.selection();
                        setState(() => _selectedMonthKey = mKey);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ArabicDateHelper.formatMonthYearKey(mKey),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: textWhite,
                                    ),
                                  ),
                                  Text(
                                    '${mFuelList.length} تعبئات${mLiters > 0 ? ' • ${mLiters.toStringAsFixed(1)} لتر' : ''}${branches.isNotEmpty ? ' • $branches' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₪ ${mSum.toStringAsFixed(mSum % 1 == 0 ? 0 : 2)}',
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: brandGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Operations Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل العمليات والفواتير',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textWhite,
                ),
              ),
              Text(
                '${filteredHistory.length} عمليات',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Operations List
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: Column(
              key: ValueKey<String>('${_selectedMonthKey}_${_showAllHistory}_${displayHistory.length}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (displayHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'لا توجد عمليات مسجلة في هذا الشهر',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayHistory.length,
              separatorBuilder: (_, __) => const Divider(
                color: Color(0xB3242927),
                height: 1,
                thickness: 0.8,
              ),
              itemBuilder: (context, idx) {
                final item = displayHistory[idx];
                final isFuel = item.category == ExpenseCategory.fuel;
                final itemColor = isFuel ? brandGreen : brandYellow;

                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    SpendoHaptics.light();
                    final updated = _state.history
                        .where((x) => x.id != item.id)
                        .toList();
                    _saveState(_state.copyWith(history: updated));
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    color: brandRed.withValues(alpha: 0.15),
                    child: const Icon(
                      Remix.delete_bin_line,
                      color: brandRed,
                      size: 16,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      SpendoHaptics.light();
                      _showTransactionDetailsSheet(item);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            isFuel ? Remix.gas_station_line : Remix.tools_line,
                            size: 15,
                            color: itemColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: textWhite,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFuel
                                      ? '${item.date.day}/${item.date.month}/${item.date.year}${item.provider != null && item.provider!.isNotEmpty ? ' • ${item.provider}' : ''}${item.liters != null && item.liters! > 0 ? ' • ${item.liters!.toStringAsFixed(2)} ליטר' : ''}'
                                      : '${item.date.day}/${item.date.month}/${item.date.year}${item.odometer > 0 ? ' • ${_formatNumber(item.odometer)} ק"מ' : ''}',
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF9CA3AF),
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₪ ${item.amount.toStringAsFixed(item.amount % 1 == 0 ? 0 : 2)}',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: itemColor,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Remix.arrow_left_s_line,
                                size: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          if (filteredHistory.length > 5) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                SpendoHaptics.selection();
                setState(() => _showAllHistory = !_showAllHistory);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showAllHistory
                            ? 'طي السجل'
                            : 'عرض كافة العمليات (${filteredHistory.length})',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: brandGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAllHistory
                            ? Remix.arrow_up_s_line
                            : Remix.arrow_down_s_line,
                        size: 14,
                        color: brandGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthChipItem({
    required String keyName,
    required String label,
  }) {
    final isSelected = _selectedMonthKey == keyName;
    return InkWell(
      onTap: () {
        SpendoHaptics.selection();
        setState(() => _selectedMonthKey = keyName);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? brandGreen.withValues(alpha: 0.12) : surfaceMain,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? brandGreen : surfaceBorder,
          ),
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? brandGreen : textMuted,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  // نافذة تعديل اسم المركبة
  void _showEditVehicleNameDialog() {
    final controller = TextEditingController(text: _state.vehicleName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final keyboardInset = media.viewInsets.bottom;
        final bottomNavPadding = media.padding.bottom > 0
            ? media.padding.bottom
            : media.viewPadding.bottom;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                right: 20,
                left: 20,
                top: 20,
                bottom: keyboardInset > 0
                    ? keyboardInset + 8
                    : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تعديل اسم أو موديل المركبة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textWhite,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textWhite,
                ),
                decoration: InputDecoration(
                  hintText: 'مثال: SYM Joyride 200 أو سكوتر العمل...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: surfaceField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    SpendoHaptics.light();
                    _saveState(_state.copyWith(vehicleName: newName));
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spendoGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'حفظ الاسم',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  // نافذة تحديث العداد
  void _showUpdateOdometerSheet() {
    final controller =
        TextEditingController(text: _state.currentOdometer.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final keyboardInset = media.viewInsets.bottom;
        final bottomNavPadding = media.padding.bottom > 0
            ? media.padding.bottom
            : media.viewPadding.bottom;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                right: 20,
                left: 20,
                top: 20,
                bottom: keyboardInset > 0
                    ? keyboardInset + 8
                    : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تحديث قراءة العداد الحالية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textWhite,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textWhite,
                ),
                decoration: InputDecoration(
                  suffixText: 'كم',
                  filled: true,
                  fillColor: surfaceField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final nextKm = int.tryParse(controller.text.trim());
                  if (nextKm != null && nextKm > 0) {
                    SpendoHaptics.light();
                    _saveState(_state.copyWith(currentOdometer: nextKm));
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spendoGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'حفظ وتحديث الصحة فوراً',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  // نافذة تصفير قطعة الصيانة بلمسة واحدة
  void _showResetPartSheet(MaintenancePart part) {
    final costCtrl = TextEditingController();
    final odoCtrl =
        TextEditingController(text: _state.currentOdometer.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final keyboardInset = media.viewInsets.bottom;
        final bottomNavPadding = media.padding.bottom > 0
            ? media.padding.bottom
            : media.viewPadding.bottom;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                right: 20,
                left: 20,
                top: 20,
                bottom: keyboardInset > 0
                    ? keyboardInset + 8
                    : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'هل قمت بصيانة/تغيير ${part.title} الآن؟',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textWhite,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textWhite),
                decoration: InputDecoration(
                  labelText: 'التكلفة بالشيكل (اختياري)',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  suffixText: '₪',
                  filled: true,
                  fillColor: surfaceField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: odoCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textWhite),
                decoration: InputDecoration(
                  labelText: 'قراءة العداد عند التغيير',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  suffixText: 'كم',
                  filled: true,
                  fillColor: surfaceField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final serviceKm =
                      int.tryParse(odoCtrl.text.trim()) ?? _state.currentOdometer;
                  final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;

                  SpendoHaptics.light();

                  final updatedParts = _state.parts.map((p) {
                    if (p.id == part.id) {
                      return p.copyWith(lastServiceKm: serviceKm);
                    }
                    return p;
                  }).toList();

                  final updatedHistory = [..._state.history];
                  if (cost > 0) {
                    updatedHistory.insert(
                      0,
                      VehicleExpenseRecord(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: 'החלפת ${part.title}',
                        amount: cost,
                        odometer: serviceKm,
                        date: DateTime.now(),
                        category: ExpenseCategory.maintenance,
                      ),
                    );
                  }

                  final nextOdo = serviceKm > _state.currentOdometer
                      ? serviceKm
                      : _state.currentOdometer;

                  _saveState(_state.copyWith(
                    currentOdometer: nextOdo,
                    parts: updatedParts,
                    history: updatedHistory,
                  ));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spendoGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'تصفير العداد وحفظ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  // نافذة تسجيل تعبئة وقود بتصميم هادئ ومتقن مع أيقونات مدمجة بالخلفية
  Future<void> _showFuelExpenseSheet() async {
    final res = await FuelExpenseSheet.show(context, onSaved: _loadState);
    if (res == true) {
      _loadState();
    }
  }

  // نافذة تسجيل صيانة دورية وقطع غيار (ترتبط بالعداد والكيلومترات)
  void _showMaintenanceExpenseSheet() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final odoCtrl =
        TextEditingController(text: _state.currentOdometer.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final keyboardInset = media.viewInsets.bottom;
        final bottomNavPadding = media.padding.bottom > 0
            ? media.padding.bottom
            : media.viewPadding.bottom;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                right: 20,
                left: 20,
                top: 20,
                bottom: keyboardInset > 0
                    ? keyboardInset + 8
                    : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Remix.tools_line,
                    color: brandYellow,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'تسجيل صيانة دورية / قطع غيار',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textWhite,
                ),
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع (₪)',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  suffixText: '₪',
                  filled: true,
                  fillColor: surfaceField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: TextStyle(color: textWhite),
                decoration: InputDecoration(
                  labelText: 'שם הטיפול או החלפים המוחלפים (עברית)',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: surfaceField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: odoCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textWhite),
                decoration: InputDecoration(
                  labelText: 'קריאת מד אוץ בעת הטיפול (ק"מ)',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  suffixText: 'ק"מ',
                  filled: true,
                  fillColor: surfaceField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) return;

                  final odo = int.tryParse(odoCtrl.text.trim()) ??
                      _state.currentOdometer;
                  final title = noteCtrl.text.trim().isEmpty
                      ? 'טיפול תקופתי / חלפים'
                      : noteCtrl.text.trim();

                  SpendoHaptics.light();

                  final updatedHistory = [
                    VehicleExpenseRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: title,
                      amount: amount,
                      odometer: odo,
                      date: DateTime.now(),
                      category: ExpenseCategory.maintenance,
                    ),
                    ..._state.history,
                  ];

                  _saveState(_state.copyWith(
                    currentOdometer: odo > _state.currentOdometer
                        ? odo
                        : _state.currentOdometer,
                    history: updatedHistory,
                  ));
                  Navigator.pop(ctx);
                },
                icon: const Icon(Remix.check_line, size: 18),
                label: const Text(
                  'حفظ عملية الصيانة',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  // ignore: unused_element
  void _showInvoiceParserSheet() {
    File? selectedImageFile;
    bool isScanning = false;
    ParsedReceiptResult? parsedResult;
    String? statusMessage;
    VehicleExpenseRecord? duplicateRecord;
    final amountCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateParsed(ParsedReceiptResult res) {
              parsedResult = res;
              titleCtrl.text = res.title;
              amountCtrl.text = res.amount.toString();

              final amt = res.amount;
              final dup = _state.findDuplicate(
                invoiceNumber: res.invoiceNumber,
                date: res.date,
                amount: amt,
                category: res.isFuel
                    ? ExpenseCategory.fuel
                    : ExpenseCategory.maintenance,
                title: res.title,
              );

              duplicateRecord = dup;
              if (dup != null) {
                SpendoHaptics.medium();
                statusMessage =
                    'تم استخراج البيانات، وعُثر على فاتورة سابقة مطابقة في السجل!';
              } else {
                statusMessage =
                    'تم التعرف على الفاتورة بنجاح، يرجى مراجعة وتأكيد البيانات.';
              }
            }

            Future<void> processImage(File imageFile) async {
              setSheetState(() {
                selectedImageFile = imageFile;
                isScanning = true;
                statusMessage =
                    'جاري تحليل الصورة ضوئياً واستخراج بيانات الفاتورة...';
              });

              final result =
                  await ReceiptOcrService.analyzeReceiptImage(imageFile);

              setSheetState(() {
                isScanning = false;
                if (result != null && result.amount > 0) {
                  updateParsed(result);
                } else {
                  statusMessage =
                      'تمت قراءة الصورة ولكن لم تظهر أرقام واضحة، يُرجى إدخال المبلغ يدوياً.';
                  SpendoHaptics.medium();
                }
              });
            }

            Future<void> pickFromSource(ImageSource source) async {
              try {
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 1600,
                  maxHeight: 1600,
                  imageQuality: 85,
                );
                if (picked != null) {
                  SpendoHaptics.light();
                  await processImage(File(picked.path));
                }
              } catch (_) {
                setSheetState(() {
                  statusMessage = 'تعذر فتح الصورة، يرجى المحاولة مرة أخرى.';
                });
              }
            }

            void commitAddInvoice({bool isDuplicateOverride = false}) {
              final amt = double.tryParse(amountCtrl.text.trim()) ??
                  parsedResult!.amount;
              if (amt <= 0) return;

              SpendoHaptics.success();
              final newRecord = VehicleExpenseRecord(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleCtrl.text.trim().isEmpty
                    ? parsedResult!.title
                    : titleCtrl.text.trim(),
                amount: amt,
                odometer: _state.currentOdometer,
                date: parsedResult!.date,
                category: parsedResult!.isFuel
                    ? ExpenseCategory.fuel
                    : ExpenseCategory.maintenance,
                invoiceNumber: parsedResult!.invoiceNumber,
                provider: parsedResult!.providerName.isNotEmpty
                    ? parsedResult!.providerName
                    : null,
                liters: parsedResult!.liters,
                items: parsedResult!.items.isNotEmpty
                    ? parsedResult!.items
                    : null,
                notes: isDuplicateOverride ? 'نسخة مكررة تم تأكيدها' : null,
              );

              final updated = [newRecord, ..._state.history];
              _saveState(_state.copyWith(history: updated));
              Navigator.pop(ctx);
            }

            final media = MediaQuery.of(ctx);
            final keyboardInset = media.viewInsets.bottom;
            final bottomNavPadding = media.padding.bottom > 0
                ? media.padding.bottom
                : media.viewPadding.bottom;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: keyboardInset > 0
                        ? keyboardInset + 8
                        : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
                  ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.document_scanner_rounded,
                              color: Color(0xFFF59E0B),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مسح وتحليل الفواتير بالصور',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textWhite,
                                ),
                              ),
                              Text(
                                'التقط صورة للفاتورة أو اخترها من الألبوم لاستخراج البيانات',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // أزرار اختيار الصور والكاميرا
                      Row(
                        children: [
                          Expanded(
                            child: _buildImageSourceButton(
                              icon: Icons.photo_library_rounded,
                              label: 'اختيار من الألبوم',
                              onTap: () => pickFromSource(ImageSource.gallery),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildImageSourceButton(
                              icon: Icons.camera_alt_rounded,
                              label: 'تصوير بالكاميرا',
                              onTap: () => pickFromSource(ImageSource.camera),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // نماذج فحص سريعة
                      Row(
                        children: [
                          Expanded(
                            child: _buildPresetChip(
                                'تجربة مسح فاتورة פז בעינה 365', () {
                              setSheetState(() {
                                final res = ReceiptOcrService.parseReceiptText(
                                    'פז בעינה 365 חשבונית 041709901387254 תאריך 21/10/26 רכב 55505403 משאבה 05 אוקטן 95 7.770 כמות 6.000 ליטרים סה"כ לתשלום 46.62 ש"ח Yellow yasen lafe');
                                updateParsed(res);
                              });
                            }),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPresetChip(
                                'تجربة مسح חשבונית אור אמנוני', () {
                              setSheetState(() {
                                final res = ReceiptOcrService.parseReceiptText(
                                    'מוסך אור אמנוני כרמיאל חשבונית מס קבלה 2289 תאריך 01/09/2026 רכב 55-505-403 טיפול גדול 932.20 צמיג קדמי 254.24 סה"כ לתשלום 1400.00 ש"ח');
                                updateParsed(res);
                              });
                            }),
                          ),
                        ],
                      ),
                      if (selectedImageFile != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: surfaceBorder),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  selectedImageFile!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تم تحميل صورة الفاتورة',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: textWhite,
                                      ),
                                    ),
                                    Text(
                                      'المسار: ${selectedImageFile!.path.split(Platform.pathSeparator).last}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isScanning) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.spendoGreen),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'جاري قراءة الفاتورة ضوئياً واستخراج البيانات...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (statusMessage != null && !isScanning) ...[
                        const SizedBox(height: 10),
                        Text(
                          statusMessage!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: duplicateRecord != null
                                ? const Color(0xFFEF4444)
                                : textMuted,
                          ),
                        ),
                      ],
                      if (duplicateRecord != null && !isScanning) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'تنبيه: تم العثور على فاتورة سابقة مطابقة في السجل!',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      duplicateRecord!.title,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: textWhite,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'التاريخ: ${duplicateRecord!.date.day}/${duplicateRecord!.date.month}/${duplicateRecord!.date.year} • المبلغ: ₪${duplicateRecord!.amount.toStringAsFixed(2)}${duplicateRecord!.invoiceNumber != null ? ' • رقم #${duplicateRecord!.invoiceNumber}' : ''}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showTransactionDetailsSheet(
                                            duplicateRecord!);
                                      },
                                      icon: const Icon(
                                          Icons.remove_red_eye_rounded,
                                      size: 15),
                                      label: const Text(
                                        'عرض الفاتورة المسجلة',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFFEF4444),
                                        side: const BorderSide(
                                            color: Color(0xFFEF4444)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        SpendoHaptics.light();
                                        Navigator.pop(ctx);
                                      },
                                      icon: const Icon(Icons.close_rounded,
                                          size: 15),
                                      label: Text(
                                        'إلغاء التكرار',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: surfaceField,
                                        foregroundColor: textWhite,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (parsedResult != null && !isScanning) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: duplicateRecord != null
                                  ? const Color(0xFFEF4444)
                                      .withValues(alpha: 0.5)
                                  : AppColors.spendoGreen
                                      .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    duplicateRecord != null
                                        ? Icons.info_outline_rounded
                                        : Icons.check_circle_rounded,
                                    color: duplicateRecord != null
                                        ? const Color(0xFFEF4444)
                                        : AppColors.spendoGreen,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'تفاصيل الفاتورة المستخرجة:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: duplicateRecord != null
                                          ? const Color(0xFFEF4444)
                                          : AppColors.spendoGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: titleCtrl,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textWhite,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'اسم الفاتورة والبيانات الفنية',
                                  labelStyle: TextStyle(
                                      color: textMuted, fontSize: 11),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: amountCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.spendoGreen,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'المبلغ الإجمالي المستخرج',
                                  labelStyle: TextStyle(
                                      color: textMuted, fontSize: 11),
                                  suffixText: '₪',
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'التاريخ: ${parsedResult!.date.day}/${parsedResult!.date.month}/${parsedResult!.date.year} • الفئة: ${parsedResult!.isFuel ? 'وقود' : 'صيانة וחלפים'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (duplicateRecord != null)
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  backgroundColor: surfaceField,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Text(
                                    'تأكيد إضافة فاتورة مكررة',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: textWhite,
                                    ),
                                  ),
                                  content: Text(
                                    'توجد بالفعل فاتورة مطابقة في السجل. هل تود بالتأكيد إضافة هذه النسخة المكررة؟',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: textMuted,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('إلغاء'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        commitAddInvoice(
                                            isDuplicateOverride: true);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF59E0B),
                                        foregroundColor: Colors.black,
                                      ),
                                      child: const Text('نعم، إضافة مكررة'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                size: 18),
                            label: const Text(
                              'إضافة كنسخة مكررة (رغم التطابق)',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => commitAddInvoice(),
                            icon: const Icon(Remix.check_line, size: 18),
                            label: const Text(
                              'إضافة الفاتورة إلى السجل',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.spendoGreen,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  void _showEditFuelDialog(VehicleExpenseRecord record) {
    final titleCtrl = TextEditingController(text: record.title);
    final providerCtrl = TextEditingController(text: record.provider ?? '');
    final amountCtrl = TextEditingController(text: record.amount.toStringAsFixed(2));
    final litersCtrl = TextEditingController(text: record.liters?.toString() ?? '');

    showDialog(
      context: context,
      builder: (editCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: surfaceField,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: surfaceBorder),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          title: Text(
            'تعديل الفاتورة والمحطة',
            style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: providerCtrl,
                  style: TextStyle(color: textWhite, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'اسم المحطة / المزود (الموقع)',
                    labelStyle: TextStyle(color: textMuted, fontSize: 11),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: textWhite, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'بيان الفاتورة',
                    labelStyle: TextStyle(color: textMuted, fontSize: 11),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: brandYellow, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'المبلغ (₪)',
                          labelStyle: TextStyle(color: textMuted, fontSize: 11),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: litersCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textWhite, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'اللترات',
                          labelStyle: TextStyle(color: textMuted, fontSize: 11),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => Navigator.pop(editCtx),
              child: Text('إلغاء', style: TextStyle(color: textMuted, fontSize: 11.5)),
            ),
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () {
                final newAmt = double.tryParse(amountCtrl.text.trim()) ?? record.amount;
                final newLiters = double.tryParse(litersCtrl.text.trim());
                final newProv = providerCtrl.text.trim();
                final newTitle = titleCtrl.text.trim();

                final updatedRec = record.copyWith(
                  title: newTitle.isNotEmpty ? newTitle : record.title,
                  provider: newProv.isNotEmpty ? newProv : record.provider,
                  amount: newAmt,
                  liters: newLiters,
                );

                Navigator.pop(editCtx);
                final updated = _state.history.map((x) => x.id == record.id ? updatedRec : x).toList();
                _saveState(_state.copyWith(history: updated));
              },
              child: const Text('حفظ', style: TextStyle(color: brandGreen, fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFuelDetailsModal(VehicleExpenseRecord record) {
    showDialog(
      context: context,
      builder: (dCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: surfaceField,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: surfaceBorder),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 56, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          title: Text(
            record.title,
            style: TextStyle(
              color: textWhite,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المبلغ: ₪${record.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: brandYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'التاريخ: ${ArabicDateHelper.formatArabicDateWithWeekday(record.date)}',
                style: TextStyle(color: textMuted, fontSize: 10.5),
              ),
              if (record.provider != null && record.provider!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'المزود: ${record.provider}',
                  style: TextStyle(color: textMuted, fontSize: 10.5),
                ),
              ],
              if (record.liters != null) ...[
                const SizedBox(height: 3),
                Text(
                  'اللترات: ${record.liters} لتر',
                  style: TextStyle(color: textMuted, fontSize: 10.5),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              onPressed: () {
                Navigator.pop(dCtx);
                final updated =
                    _state.history.where((x) => x.id != record.id).toList();
                _saveState(_state.copyWith(history: updated));
              },
              child: const Text(
                'حذف',
                style: TextStyle(
                  color: brandRed,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              onPressed: () {
                Navigator.pop(dCtx);
                _showEditFuelDialog(record);
              },
              child: const Text(
                'تعديل',
                style: TextStyle(
                  color: brandYellow,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              onPressed: () => Navigator.pop(dCtx),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  color: brandGreen,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailsSheet(VehicleExpenseRecord record) {
    if (record.category == ExpenseCategory.fuel) {
      _showFuelDetailsModal(record);
      return;
    }
    final isFuel = record.category == ExpenseCategory.fuel;
    final kmSince = (_state.currentOdometer - record.odometer).clamp(0, 999999);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final bottomNavPadding = media.padding.bottom > 0
            ? media.padding.bottom
            : media.viewPadding.bottom;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: bottomNavPadding > 0 ? bottomNavPadding + 8 : 20,
              ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isFuel
                                      ? AppColors.spendoGreen
                                      : AppColors.accentBlue)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (isFuel
                                        ? AppColors.spendoGreen
                                        : AppColors.accentBlue)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              isFuel
                                  ? Remix.gas_station_line
                                  : Remix.tools_line,
                              color: isFuel
                                  ? brandGreen
                                  : brandYellow,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFuel
                                    ? 'تعبئة وقود (Yellow)'
                                    : 'صيانة وتغيير قطع غيار',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textWhite,
                                ),
                              ),
                              Text(
                                ArabicDateHelper.formatArabicDateWithWeekday(
                                    record.date),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isFuel
                                  ? AppColors.spendoGreen
                                  : textWhite)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${record.amount.toStringAsFixed(record.amount % 1 == 0 ? 0 : 2)} ₪',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isFuel
                                ? AppColors.spendoGreen
                                : textWhite,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // بطاقة التفاصيل الفنية
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Remix.motorbike_line,
                          label: 'المركبة المسجلة',
                          value: _state.vehicleName,
                        ),
                        Divider(
                            color: surfaceBorder, height: 18),
                        _buildDetailRow(
                          icon: Remix.file_text_line,
                          label: 'البيان بالعبرية',
                          value: record.title,
                          isHighlight: true,
                        ),
                        if (!isFuel && record.odometer > 0) ...[
                          Divider(
                              color: surfaceBorder, height: 18),
                          _buildDetailRow(
                            icon: Remix.dashboard_3_line,
                            label: 'قراءة العداد عند العملية',
                            value: '${_formatNumber(record.odometer)} ק"מ',
                          ),
                          Divider(
                              color: surfaceBorder, height: 18),
                          _buildDetailRow(
                            icon: Remix.route_line,
                            label: 'المسافة منذ هذه العملية',
                            value: kmSince == 0
                                ? 'متطابق مع العداد الحالي (0 ק"מ)'
                                : '+${_formatNumber(kmSince)} ק"מ',
                          ),
                        ],
                        if (record.invoiceNumber != null &&
                            record.invoiceNumber!.isNotEmpty) ...[
                          Divider(
                              color: surfaceBorder, height: 18),
                          _buildDetailRow(
                            icon: Remix.file_list_2_line,
                            label: 'رقم الفاتورة / הקבלה',
                            value: '#${record.invoiceNumber}',
                          ),
                        ],
                        if (record.provider != null &&
                            record.provider!.isNotEmpty) ...[
                          Divider(
                              color: surfaceBorder, height: 18),
                          _buildDetailRow(
                            icon: Remix.store_2_line,
                            label: 'المزود / المحطة / الكراج',
                            value: record.provider!,
                          ),
                        ],
                        if (isFuel) ...[
                          Divider(
                              color: surfaceBorder, height: 18),
                          _buildDetailRow(
                            icon: Remix.drop_line,
                            label: 'كمية الوقود',
                            value:
                                '${record.liters ?? (record.amount / 7.77).toStringAsFixed(2)} ליטרים',
                          ),
                          Divider(
                              color: surfaceBorder, height: 18),
                          _buildDetailRow(
                            icon: Remix.gas_station_line,
                            label: 'نوع الوقود',
                            value: 'בנזין 95 אוקטן',
                          ),
                          Divider(
                              color: surfaceBorder, height: 18),
                          _buildDetailRow(
                            icon: Remix.bank_card_line,
                            label: 'وسيلة الدفع',
                            value: 'אפליקציית Yellow (פז תדלוק מהיר)',
                          ),
                        ],
                        if (record.notes != null &&
                            record.notes!.isNotEmpty) ...[
                          Divider(
                              color: surfaceBorder, height: 18),
                          _buildDetailRow(
                            icon: Remix.file_info_line,
                            label: 'ملاحظات وتوصيات',
                            value: record.notes!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isFuel && record.items != null && record.items!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceField,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Remix.checkbox_line,
                                size: 16,
                                color: isFuel
                                    ? brandGreen
                                    : brandYellow,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'القطع والأعمال المشمولة في الفاتورة:',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: textWhite,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: record.items!.map((it) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: surfaceBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Remix.checkbox_circle_line,
                                      size: 13,
                                      color: brandGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      it,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: textWhite,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // أزرار التحكم بالمعاملة
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            SpendoHaptics.light();
                            final detailsText = '''
تفاصيل معاملة (${_state.vehicleName}):
- النوع: ${isFuel ? 'تعبئة وقود' : 'صيانة وتغيير قطع'}
- البيان: ${record.title}
- المبلغ: ₪${record.amount.toStringAsFixed(2)}
- التاريخ: ${record.date.day}/${record.date.month}/${record.date.year}
- العداد: ${_formatNumber(record.odometer)} ק"מ
${record.invoiceNumber != null ? '- رقم الفاتورة: #${record.invoiceNumber}' : ''}
${record.provider != null ? '- المزود: ${record.provider}' : ''}
''';
                            Clipboard.setData(
                                ClipboardData(text: detailsText.trim()));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم نسخ تفاصيل الفاتورة بنجاح'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Remix.file_copy_line, size: 16),
                          label: Text('نسخ التفاصيل'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textWhite,
                            side: BorderSide(
                                color: surfaceBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            SpendoHaptics.light();
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                backgroundColor: surfaceField,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(
                                  'حذف المعاملة؟',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textWhite,
                                  ),
                                ),
                                content: Text(
                                  'هل أنت متأكد من حذف فاتورة "${record.title}" نهائياً من السجل؟',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: textMuted,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx),
                                    child: const Text('إلغاء'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      Navigator.pop(ctx);
                                      final updated = _state.history
                                          .where((x) => x.id != record.id)
                                          .toList();
                                      _saveState(_state.copyWith(history: updated));
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.dangerRed,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Remix.delete_bin_line,
                              size: 16, color: AppColors.dangerRed),
                          label: const Text(
                            'حذف المعاملة',
                            style: TextStyle(color: AppColors.dangerRed),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.dangerRed.withValues(alpha: 0.12),
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color:
                                    AppColors.dangerRed.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textMuted,
          ),
        ),
        const Spacer(),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color:
                  isHighlight ? brandGreen : textWhite,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: surfaceField,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaceBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.spendoGreen),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.spendoGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: AppColors.spendoGreen.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.spendoGreen,
          ),
        ),
      ),
    );
  }
}