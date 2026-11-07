import 'package:flutter/material.dart';

/// Global notifier that increments an epoch for a tab whenever the user switches to it,
/// allowing persistent tabs to replay their signature banking entry cascade & rolling numbers.
class BankingMotionController {
  BankingMotionController._();

  static final ValueNotifier<int> activeTabIndex = ValueNotifier<int>(0);
  static final List<ValueNotifier<int>> _tabEpochs = List.generate(
    5,
    (_) => ValueNotifier<int>(1),
  );

  static ValueNotifier<int> epochForTab(int tabIndex) =>
      _tabEpochs[tabIndex.clamp(0, _tabEpochs.length - 1)];

  static void notifyTabActivated(int tabIndex) {
    activeTabIndex.value = tabIndex;
    final clamped = tabIndex.clamp(0, _tabEpochs.length - 1);
    _tabEpochs[clamped].value = _tabEpochs[clamped].value + 1;
  }
}

/// Revolut / Apple Wallet style rolling number counter.
/// Smoothly rolls from 0 (or previous value) to [value] whenever [value] changes
/// or when the parent tab is activated.
class BankingRollingNumber extends StatelessWidget {
  final double value;
  final String Function(double val) formatter;
  final TextStyle style;
  final TextDirection? textDirection;
  final int? tabIndex;
  final Duration duration;

  const BankingRollingNumber({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.textDirection,
    this.tabIndex,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    if (tabIndex != null) {
      return ValueListenableBuilder<int>(
        valueListenable: BankingMotionController.epochForTab(tabIndex!),
        builder: (context, epoch, _) {
          return _buildTween(Key('roll_${tabIndex}_${epoch}_$value'));
        },
      );
    }
    return _buildTween(ValueKey<double>(value));
  }

  Widget _buildTween(Key tweenKey) {
    return TweenAnimationBuilder<double>(
      key: tweenKey,
      tween: Tween<double>(begin: 0.0, end: value),
      duration: duration,
      curve: Curves.easeOutExpo,
      builder: (context, animatedVal, _) {
        return Text(
          formatter(animatedVal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: textDirection,
          style: style,
        );
      },
    );
  }
}

/// Staggered spring card cascade for banking sections (Hero card -> Quick stats -> Actions -> List).
/// Replays smoothly every time the user navigates to [tabIndex].
class BankingCascadeItem extends StatefulWidget {
  final int tabIndex;
  final int staggerIndex;
  final Widget child;

  const BankingCascadeItem({
    super.key,
    required this.tabIndex,
    required this.staggerIndex,
    required this.child,
  });

  @override
  State<BankingCascadeItem> createState() => _BankingCascadeItemState();
}

class _BankingCascadeItemState extends State<BankingCascadeItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  late final ValueNotifier<int> _epochNotifier;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 380 + (widget.staggerIndex * 55)),
    );

    final intervalStart =
        (widget.staggerIndex * 0.09).clamp(0.0, 0.45).toDouble();
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(intervalStart, 1.0, curve: Curves.easeOutQuart),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.065),
      end: Offset.zero,
    ).animate(curved);
    _scale = Tween<double>(begin: 0.965, end: 1.0).animate(curved);

    _epochNotifier = BankingMotionController.epochForTab(widget.tabIndex);
    _epochNotifier.addListener(_onTabActivated);
    _controller.forward(from: 0.0);
  }

  void _onTabActivated() {
    if (!mounted) return;
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _epochNotifier.removeListener(_onTabActivated);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}
