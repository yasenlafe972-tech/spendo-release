import 'package:sanad_app/core/theme/app_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:uuid/uuid.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/models/person_account_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_details_modal_sheet.dart';
import 'package:sanad_app/features/people/presentation/widgets/add_edit_person_sheet.dart';
import 'package:sanad_app/core/widgets/spendo_confirm_delete_dialog.dart';

/// Spendo Mini Logo Painter (matches the 3-polygon official logo mark)
class SpendoMiniLogoPainter extends CustomPainter {
  const SpendoMiniLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 100.0;

    // Top trapezoid: yellow #EAB308
    final pYellow = Path()
      ..moveTo(38 * scaleX, 16 * scaleY)
      ..lineTo(78 * scaleX, 16 * scaleY)
      ..lineTo(64 * scaleX, 34 * scaleY)
      ..lineTo(24 * scaleX, 34 * scaleY)
      ..close();
    canvas.drawPath(pYellow, Paint()..color = const Color(0xFFFFD600));

    // Middle diagonal: green #00A86B
    final pGreen = Path()
      ..moveTo(24 * scaleX, 34 * scaleY)
      ..lineTo(45 * scaleX, 34 * scaleY)
      ..lineTo(76 * scaleX, 66 * scaleY)
      ..lineTo(55 * scaleX, 66 * scaleY)
      ..close();
    canvas.drawPath(pGreen, Paint()..color = const Color(0xFF00A86B));

    // Bottom trapezoid: white #F3F4F6
    final pWhite = Path()
      ..moveTo(36 * scaleX, 66 * scaleY)
      ..lineTo(76 * scaleX, 66 * scaleY)
      ..lineTo(62 * scaleX, 84 * scaleY)
      ..lineTo(22 * scaleX, 84 * scaleY)
      ..close();
    canvas.drawPath(pWhite, Paint()..color = const Color(0xFFF3F4F6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Modal Popup for Person Accounts & Passwords (خزنة الحسابات).
/// Precisely mirrors the Obsidian Dark 2x2 Grid Prototype.
class PersonAccountsModalSheet extends StatefulWidget {
  final PersonModel person;
  final VoidCallback? onAccountsChanged;

  const PersonAccountsModalSheet({
    super.key,
    required this.person,
    this.onAccountsChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required PersonModel person,
    VoidCallback? onAccountsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => PersonAccountsModalSheet(
        person: person,
        onAccountsChanged: onAccountsChanged,
      ),
    );
  }

  @override
  State<PersonAccountsModalSheet> createState() => _PersonAccountsModalSheetState();
}

class _PersonAccountsModalSheetState extends State<PersonAccountsModalSheet> {
  // Theme Design Tokens
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121417) : const Color(0xFFFFFFFF);
  static Color get surfaceCell => _isDark ? const Color(0xFF16191E) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF22262E) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF0F766E);
  static Color get brandYellow =>
      const Color(0xFFFFD600);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);
  static Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);

  final PeopleRepository _repository = PeopleRepository();
  List<PersonAccountModel> _accounts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Grid mode: 2x2 by default as requested
  bool _isTwoColumns = true;

  // Reveal all passwords toggle
  bool _allPasswordsVisible = false;

  // Visibility map per account id
  final Map<String, bool> _visiblePasswords = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final list = await _repository.getAccountsForPerson(widget.person.id);
    if (!mounted) return;
    setState(() {
      _accounts = list;
      _isLoading = false;
    });
    widget.onAccountsChanged?.call();
  }

  List<PersonAccountModel> get _filteredAccounts {
    if (_searchQuery.trim().isEmpty) return _accounts;
    final q = _searchQuery.toLowerCase().trim();
    return _accounts.where((acc) {
      final serviceMatches = acc.service.toLowerCase().contains(q);
      final emailMatches = acc.email.toLowerCase().contains(q);
      return serviceMatches || emailMatches;
    }).toList();
  }

  void _copy(String text, String message) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: surfaceCell,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: brandGreen, width: 0.8),
        ),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(Remix.checkbox_circle_line, color: brandYellow, size: 15),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(color: textWhite, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAllPasswords() {
    setState(() {
      _allPasswordsVisible = !_allPasswordsVisible;
      for (final acc in _accounts) {
        _visiblePasswords[acc.id] = _allPasswordsVisible;
      }
    });
  }

  void _toggleSinglePassword(String id) {
    setState(() {
      _visiblePasswords[id] = !(_visiblePasswords[id] ?? false);
    });
  }

  void _toggleGridMode() {
    setState(() {
      _isTwoColumns = !_isTwoColumns;
    });
    _copy('', _isTwoColumns ? 'تم التبديل لعرض بطاقتين في كل سطر' : 'تم التبديل لعرض بطاقة واحدة في السطر');
  }

  Future<void> _confirmDelete(PersonAccountModel account) async {
    final confirmed = await SpendoConfirmDeleteDialog.show(
      context,
      title: 'حذف الحساب',
      itemName: account.service,
      itemIcon: Remix.key_2_line,
      description: 'هل أنت متأكد من حذف هذا الحساب وكلمة المرور الخاصة به نهائياً؟',
      confirmLabel: 'حذف الحساب',
    );

    if (confirmed == true) {
      await _repository.deleteAccount(account.id);
      _loadAccounts();
    }
  }

  Future<void> _showAddEditAccountModal([PersonAccountModel? existing]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _AddEditAccountSheet(
        person: widget.person,
        account: existing,
      ),
    );

    if (result == true) {
      _loadAccounts();
    }
  }

  void _openProfileModal() {
    Navigator.pop(context);
    PersonDetailsModalSheet.show(
      context: context,
      person: widget.person,
      onEdit: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => AddEditPersonSheet(
            person: widget.person,
            onSave: (p) async {
              await _repository.updatePerson(p);
              _loadAccounts();
            },
          ),
        );
      },
      onDelete: () async {
        await _repository.deletePerson(widget.person.id);
        widget.onAccountsChanged?.call();
      },
      onAccountsChanged: () {
        _loadAccounts();
        widget.onAccountsChanged?.call();
      },
    );
  }

  IconData _getServiceIcon(String service) {
    final s = service.toLowerCase().trim();
    if (s.contains('apple') || s.contains('icloud')) return Remix.apple_line;
    if (s.contains('davinci') || s.contains('ai') || s.contains('gpt') || s.contains('openai')) return Remix.sparkling_line;
    if (s.contains('mapbox') || s.contains('map')) return Remix.compass_3_line;
    if (s.contains('nsave') || s.contains('bank') || s.contains('wallet')) return Remix.wallet_3_line;
    if (s.contains('paypal')) return Remix.paypal_line;
    if (s.contains('oracle') || s.contains('cloud')) return Remix.cloud_line;
    if (s.contains('amazon') || s.contains('prime')) return Remix.amazon_line;
    if (s.contains('google') || s.contains('gmail')) return Remix.google_line;
    if (s.contains('facebook') || s.contains('meta')) return Remix.facebook_line;
    if (s.contains('netflix')) return Remix.movie_2_line;
    if (s.contains('twitter') || s == 'x') return Remix.twitter_x_line;
    if (s.contains('mail.ru')) return Remix.mail_line;
    return Remix.apps_2_line;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAccounts;
    final primaryEmail = (widget.person.email != null && widget.person.email!.trim().isNotEmpty)
        ? widget.person.email!.trim()
        : 'yasenlafi972@gmail.com';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: surfaceBorder, width: 1.0),
          left: BorderSide(color: surfaceBorder, width: 1.0),
          right: BorderSide(color: surfaceBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header (LTR): Mini Logo + Key Icon + Title + My Profile Pill + Close (X)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceCell,
                  border: Border(bottom: BorderSide(color: surfaceBorder)),
                ),
                child: Row(
                  children: [
                    // Mini Spendo Logo
                    const CustomPaint(
                      size: Size(16, 16),
                      painter: SpendoMiniLogoPainter(),
                    ),
                    const SizedBox(width: 8),

                    // Yellow Key Icon
                    Icon(Remix.key_2_line, color: brandYellow, size: 16),
                    const SizedBox(width: 8),

                    // Title
                    Text(
                      'Accounts & passwords',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: textWhite,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // My profile Pill button
                    InkWell(
                      onTap: _openProfileModal,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: surfaceMain,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: brandGreen.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Remix.user_line, size: 10, color: brandGreen),
                            const SizedBox(width: 4),
                            Text(
                              widget.person.name.isNotEmpty ? widget.person.name : 'My profile',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: brandGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Close (X) button without circular background
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Remix.close_line, size: 18, color: Color(0xFFA1A1AA)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Search Bar + "+ New" Button
            Directionality(
              textDirection: TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Search Input
                    Expanded(
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: surfaceCell,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Remix.search_line, size: 13, color: Color(0xFFA1A1AA)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => setState(() => _searchQuery = val),
                                style: TextStyle(fontSize: 11.5, color: textWhite),
                                decoration: const InputDecoration(
                                  hintText: 'Search service or email...',
                                  hintStyle: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Icon(Remix.close_circle_line, size: 13, color: Color(0xFF71717A)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // "+ New" Button
                    InkWell(
                      onTap: () => _showAddEditAccountModal(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: brandGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Remix.add_line, size: 14, color: Color(0xFF0A0B0D)),
                            SizedBox(width: 3),
                            Text(
                              'New',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A0B0D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Quick Toolbar: Count | Copy Email | Toggle All | Grid 2x2
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: surfaceCell,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Row(
                  children: [
                    // Count
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${filtered.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: brandYellow,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'حسابات',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    VerticalDivider(width: 1, thickness: 1, color: surfaceBorder),

                    // Copy Email
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () => _copy(primaryEmail, 'تم نسخ الإيميل الأساسي'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Remix.at_line, color: brandGreen, size: 11),
                            SizedBox(width: 4),
                            Text(
                              'نسخ إيميلي',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    VerticalDivider(width: 1, thickness: 1, color: surfaceBorder),

                    // Reveal All Passwords
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _toggleAllPasswords,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _allPasswordsVisible ? Remix.eye_off_line : Remix.eye_line,
                              color: brandYellow,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _allPasswordsVisible ? 'إخفاء الكل' : 'إظهار الكل',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    VerticalDivider(width: 1, thickness: 1, color: surfaceBorder),

                    // Toggle Columns (2x2 vs 1x1)
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _toggleGridMode,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isTwoColumns ? Remix.layout_grid_line : Remix.list_check_2,
                              color: brandGreen,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _isTwoColumns ? '2×2' : '1×1',
                              style: const TextStyle(
                                fontSize: 9.5,
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
            ),
            const SizedBox(height: 8),

            // 4. Accounts Cards List / Grid (2 per line by default)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: brandGreen))
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Remix.key_2_line,
                                  size: 36,
                                  color: Color(0xFF3F3F46),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'لا توجد حسابات مطابقة للبحث'
                                      : 'لا توجد حسابات مضافة بعد في الخزنة',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF71717A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddEditAccountModal(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: surfaceCell,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: surfaceBorder),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  icon: const Icon(Remix.add_line, size: 14),
                                  label: const Text(
                                    'إضافة أول حساب',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: _buildCardsGrid(filtered),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsGrid(List<PersonAccountModel> list) {
    if (!_isTwoColumns) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _buildAccountCard(list[i]),
      );
    }

    // 2x2 Grid (side-by-side cards without gaps)
    final rowsCount = (list.length / 2).ceil();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rowsCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, rowIndex) {
        final idx1 = rowIndex * 2;
        final idx2 = idx1 + 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildAccountCard(list[idx1])),
            const SizedBox(width: 8),
            Expanded(
              child: idx2 < list.length
                  ? _buildAccountCard(list[idx2])
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountCard(PersonAccountModel account) {
    final isRevealed = _visiblePasswords[account.id] ?? false;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceCell,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Service Name + Action Cell (Pencil + Trash)
            Container(
              height: 30,
              decoration: BoxDecoration(
                color: surfaceCell,
                border: Border(bottom: BorderSide(color: surfaceBorder)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(_getServiceIcon(account.service), size: 12, color: brandGreen),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      account.service,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textWhite,
                      ),
                    ),
                  ),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: surfaceBorder)),
                      color: surfaceCell,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _showAddEditAccountModal(account),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Remix.pencil_line, size: 11, color: Color(0xFFA1A1AA)),
                          ),
                        ),
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: () => _confirmDelete(account),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Remix.delete_bin_6_line, size: 11, color: Color(0xFF71717A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Row 2: Mail Icon + Email + '@' Copy Button
            Container(
              height: 29,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: surfaceBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _copy(account.email, 'تم نسخ إيميل ${account.service}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            const Icon(Remix.mail_line, size: 11, color: Color(0xFFA1A1AA)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                account.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: textWhite,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _copy(account.email, 'تم نسخ إيميل ${account.service}'),
                    child: Container(
                      width: 28,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceCell,
                        border: Border(left: BorderSide(color: surfaceBorder)),
                      ),
                      child: const Text(
                        '@',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: brandGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Row 3: Key Icon + Password + Eye Toggle & Copy Button
            SizedBox(
              height: 29,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _copy(account.password, 'تم نسخ باسورد ${account.service}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Icon(Remix.key_2_line, size: 11, color: brandYellow),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                isRevealed ? account.password : '••••••••••',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: isRevealed ? FontWeight.w600 : FontWeight.w800,
                                  color: isRevealed ? brandYellow : const Color(0xFFA1A1AA),
                                  letterSpacing: isRevealed ? 0.2 : 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 29,
                    decoration: BoxDecoration(
                      color: surfaceCell,
                      border: Border(left: BorderSide(color: surfaceBorder)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _toggleSinglePassword(account.id),
                          child: Container(
                            width: 24,
                            alignment: Alignment.center,
                            child: Icon(
                              isRevealed ? Remix.eye_off_line : Remix.eye_line,
                              size: 11,
                              color: isRevealed ? brandYellow : const Color(0xFFA1A1AA),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 29, color: surfaceBorder),
                        InkWell(
                          onTap: () => _copy(account.password, 'تم نسخ باسورد ${account.service}'),
                          child: Container(
                            width: 26,
                            alignment: Alignment.center,
                            child: Icon(Remix.file_copy_line, size: 11, color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom Sheet to Add or Edit a Person Account
class _AddEditAccountSheet extends StatefulWidget {
  final PersonModel person;
  final PersonAccountModel? account;

  const _AddEditAccountSheet({
    required this.person,
    this.account,
  });

  @override
  State<_AddEditAccountSheet> createState() => _AddEditAccountSheetState();
}

class _AddEditAccountSheetState extends State<_AddEditAccountSheet> {
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121417) : const Color(0xFFFFFFFF);
  static Color get surfaceCell => _isDark ? const Color(0xFF16191E) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF22262E) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF0F766E);
  static Color get brandYellow =>
      const Color(0xFFFFD600);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);
  static Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);

  final PeopleRepository _repository = PeopleRepository();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _serviceController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isSaving = false;

  final List<String> _presets = [
    'Apple',
    'DaVinci AI',
    'Mapbox',
    'Nsave',
    'PayPal',
    'cloud.oracle',
    'Amazon Prime',
    'Google',
    'Netflix',
    'mail.ru',
  ];

  @override
  void initState() {
    super.initState();
    _serviceController = TextEditingController(text: widget.account?.service ?? '');
    _emailController = TextEditingController(
      text: widget.account?.email ?? (widget.person.email ?? 'yasenlafi972@gmail.com'),
    );
    _passwordController = TextEditingController(text: widget.account?.password ?? '');
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generateStrongPassword() {
    const chars = r'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
    final rand = Random.secure();
    final pass = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
    setState(() {
      _passwordController.text = pass;
      _obscurePassword = false;
    });
    HapticFeedback.lightImpact();
  }

  void _selectPreset(String preset) {
    setState(() {
      _serviceController.text = preset;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final service = _serviceController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final now = DateTime.now();

    if (widget.account == null) {
      final newAcc = PersonAccountModel(
        id: const Uuid().v4(),
        personId: widget.person.id,
        service: service,
        email: email,
        password: password,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.addAccount(newAcc);
    } else {
      final updatedAcc = widget.account!.copyWith(
        service: service,
        email: email,
        password: password,
        updatedAt: now,
      );
      await _repository.updateAccount(updatedAcc);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;

    return Container(
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: surfaceBorder, width: 1.0),
          left: BorderSide(color: surfaceBorder, width: 1.0),
          right: BorderSide(color: surfaceBorder, width: 1.0),
        ),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Remix.shield_keyhole_line, size: 16, color: brandGreen),
                        const SizedBox(width: 8),
                        Text(
                          isEdit ? 'تعديل حساب ${widget.account!.service}' : 'إضافة حساب جديد للخزنة',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textWhite,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Remix.close_line, size: 18, color: Color(0xFFA1A1AA)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Preset Chips
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Row(
                      children: _presets.map((preset) {
                        final isSelected = _serviceController.text.trim().toLowerCase() == preset.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _selectPreset(preset),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isSelected ? brandGreen.withValues(alpha: 0.15) : surfaceCell,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? brandGreen : surfaceBorder,
                                ),
                              ),
                              child: Text(
                                preset,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? brandGreen : textMuted,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Field 1: Service / App Name
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: surfaceCell,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SERVICE / APP NAME *',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA1A1AA),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Remix.apps_2_line, size: 13, color: brandGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _serviceController,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textWhite),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Apple, PayPal, Netflix...',
                                  hintStyle: TextStyle(fontSize: 11, color: Color(0xFF52525B)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Field 2: Email or Username + Quick Fill Bar
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceCell,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: surfaceBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EMAIL OR USERNAME *',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA1A1AA),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Remix.mail_line, size: 13, color: brandYellow),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _emailController,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontFamily: 'monospace',
                                        color: textWhite,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'yasenlafi972@gmail.com',
                                        hintStyle: TextStyle(fontSize: 11, color: Color(0xFF52525B)),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Quick fill bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: surfaceCell,
                            border: Border(top: BorderSide(color: surfaceBorder)),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'اختيار سريع:',
                                style: TextStyle(fontSize: 9.5, color: Color(0xFFA1A1AA)),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => setState(() => _emailController.text = 'yasenlafi972@gmail.com'),
                                child: const Text(
                                  'yasenlafi972@gmail.com',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontFamily: 'monospace',
                                    color: brandGreen,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('|', style: TextStyle(color: Color(0xFF52525B), fontSize: 9.5)),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => setState(() => _emailController.text = 'yasenlafe972@gmail.com'),
                                child: Text(
                                  'yasenlafe972@gmail.com',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontFamily: 'monospace',
                                    color: brandYellow,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Field 3: Password + Generate Strong Password Button
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: surfaceCell,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PASSWORD *',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA1A1AA),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Remix.key_2_line, size: 13, color: brandYellow),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: textWhite,
                                ),
                                decoration: const InputDecoration(
hintText: 'Enter password...',
                                  hintStyle: TextStyle(fontSize: 11, color: Color(0xFF52525B)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  _obscurePassword ? Remix.eye_line : Remix.eye_off_line,
                                  size: 13,
                                  color: const Color(0xFFA1A1AA),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: _generateStrongPassword,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: surfaceMain,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: surfaceBorder),
                                ),
                                child: Text(
                                  'توليد قوي',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: brandYellow,
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
                const SizedBox(height: 14),

                // Save Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: const Color(0xFF0A0B0D),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Remix.check_line, size: 16, color: Color(0xFF0A0B0D)),
                      const SizedBox(width: 6),
                      Text(
                        _isSaving ? 'جارٍ الحفظ...' : 'حفظ الحساب في الخزنة',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A0B0D),
                        ),
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
  }
}