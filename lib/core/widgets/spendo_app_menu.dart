import 'dart:async';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/settings/presentation/screens/app_settings_screen.dart';

class SpendoMenuButton extends StatelessWidget {
  final Future<void> Function()? onSettingsClosed;
  final Color? color;
  final double size;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;
  final VisualDensity? visualDensity;

  const SpendoMenuButton({
    super.key,
    this.onSettingsClosed,
    this.color,
    this.size = 20,
    this.padding = const EdgeInsets.all(8),
    this.constraints,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'فتح القائمة',
    onPressed:
        () => SpendoAppMenu.open(context, onSettingsClosed: onSettingsClosed),
    icon: Icon(Remix.menu_line, size: size, color: color),
    padding: padding,
    constraints: constraints,
    visualDensity: visualDensity,
  );
}

class SpendoAppMenu {
  SpendoAppMenu._();

  static Future<void> open(
    BuildContext context, {
    Future<void> Function()? onSettingsClosed,
  }) {
    final host = context.findAncestorStateOfType<SpendoMenuHostState>();
    assert(host != null, 'Main sections must be inside SpendoMenuHost.');
    if (host == null) return Future<void>.value();
    SpendoHaptics.light();
    return host.open(onSettingsClosed);
  }
}

/// The menu belongs to the page body, so the bottom bar stays above it.
class SpendoMenuHost extends StatefulWidget {
  final Widget child;
  const SpendoMenuHost({super.key, required this.child});

  @override
  State<SpendoMenuHost> createState() => SpendoMenuHostState();
}

class SpendoMenuHostState extends State<SpendoMenuHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late final Animation<double> _curve;
  LocalHistoryEntry? _history;
  Completer<void>? _completion;
  Future<void> Function()? _onSettingsClosed;
  bool _isOpen = false;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _curve = CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic);
  }

  Future<void> open(Future<void> Function()? callback) {
    if (_isOpen) return _completion!.future;
    _onSettingsClosed = callback;
    _completion = Completer<void>();
    _history = LocalHistoryEntry(onRemove: _finishClose);
    ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    setState(() => _isOpen = true);
    _animation.forward();
    return _completion!.future;
  }

  void close() {
    if (!_isOpen) return;
    final entry = _history;
    _history = null;
    if (entry != null) {
      entry.remove();
    } else {
      _finishClose();
    }
  }

  void _finishClose() {
    _history = null;
    if (!mounted || _disposing) return;
    setState(() => _isOpen = false);
    _animation.reverse();
    if (_completion?.isCompleted == false) _completion!.complete();
  }

  Future<void> _openSettings() async {
    final callback = _onSettingsClosed;
    close();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AppSettingsScreen()));
    if (mounted && callback != null) await callback();
  }

  @override
  void dispose() {
    _disposing = true;
    _history?.remove();
    if (_completion?.isCompleted == false) _completion!.complete();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.background : const Color(0xFFF8F9FA);
    final border = dark ? AppColors.surfaceCardBorder : const Color(0xFFE5E7EB);
    final foreground = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? AppColors.textMuted : const Color(0xFF6B7280);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            if (_animation.isDismissed) return const SizedBox.shrink();
            return IgnorePointer(
              ignoring: !_isOpen,
              child: SafeArea(
                bottom: false,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ModalBarrier(
                      color: Colors.black.withValues(
                        alpha: 0.35 * _curve.value,
                      ),
                      dismissible: true,
                      onDismiss: close,
                      semanticsLabel: 'إغلاق القائمة الجانبية',
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth * 0.52).clamp(
                          0.0,
                          240.0,
                        );
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(-width * (1 - _curve.value), 0),
                            child: Material(
                              color: background,
                              child: Container(
                                width: width,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: border),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        12,
                                        16,
                                        10,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'القائمة',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                color: foreground,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'إغلاق',
                                            onPressed: close,
                                            icon: Icon(
                                              Remix.close_line,
                                              color: muted,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(height: 1, color: border),
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                      minLeadingWidth: 20,
                                      horizontalTitleGap: 10,
                                      leading: const Icon(
                                        Remix.settings_4_line,
                                        color: AppColors.spendoGreen,
                                        size: 21,
                                      ),
                                      title: Text(
                                        'الإعدادات',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: foreground,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Remix.arrow_left_s_line,
                                        color: muted,
                                        size: 18,
                                      ),
                                      onTap: _openSettings,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
