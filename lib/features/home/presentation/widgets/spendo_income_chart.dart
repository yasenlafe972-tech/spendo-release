import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// A high-end interactive income trend chart widget for Spendo.
///
/// Features:
/// - Smooth cubic bezier curve with Catmull-Rom spline formulation.
/// - Emerald gradient fill (`AppColors.spendoGreen` with alpha 0.25 to 0.0).
/// - Emerald stroke (width 2.5) with outer neon glow pass.
/// - Interactive scrubbing gesture tracking nearest data points with vertical
///   dashed line, glowing multi-ring indicator, and floating tooltip bubble.
/// - Integrated period filter tabs (e.g. 'هذا الأسبوع', 'هذا الشهر', 'كافة الأشهر').
/// - Fallback empty state for < 2 data points with dashed placeholder curve
///   and motivational Arabic message.
class SpendoIncomeChart extends StatefulWidget {
  /// Numerical data points to plot on the chart.
  final List<double> dataPoints;

  /// Human-readable labels corresponding to each data point along the X-axis.
  final List<String> labels;

  /// Aggregate total income for the period.
  final double totalIncome;

  /// Currently selected period label (e.g. 'هذا الأسبوع').
  final String selectedPeriod;

  /// Callback invoked when user selects a different period filter tab.
  final ValueChanged<String>? onPeriodChanged;

  /// List of available period options. Defaults to `['هذا الأسبوع', 'هذا الشهر', 'كافة الأشهر']`.
  final List<String> periods;

  /// Currency symbol string. Defaults to `'₪'`.
  final String currencySymbol;

  /// Title displayed in the card header. Defaults to `'صافي الدخل'`.
  final String title;

  /// Height of the entire chart card widget. Defaults to 320.0.
  final double height;

  /// Optional callback invoked when the user scrubs or taps a specific point index.
  final ValueChanged<int?>? onPointScrubbed;

  const SpendoIncomeChart({
    super.key,
    required this.dataPoints,
    required this.labels,
    required this.totalIncome,
    required this.selectedPeriod,
    this.onPeriodChanged,
    this.periods = const ['هذا الأسبوع', 'هذا الشهر', 'كافة الأشهر'],
    this.currencySymbol = '₪',
    this.title = 'صافي الدخل',
    this.height = 320.0,
    this.onPointScrubbed,
  });

  @override
  State<SpendoIncomeChart> createState() => _SpendoIncomeChartState();
}

class _SpendoIncomeChartState extends State<SpendoIncomeChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late final AnimationController _scrubController;
  Timer? _hideTooltipTimer;

  @override
  void initState() {
    super.initState();
    _scrubController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _hideTooltipTimer?.cancel();
    _scrubController.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPosition, double chartWidth) {
    if (widget.dataPoints.length < 2) return;

    _hideTooltipTimer?.cancel();

    const double chartLeft = 20.0;
    final double chartRight = chartWidth - 20.0;
    final double stepWidth =
        (chartRight - chartLeft) / (widget.dataPoints.length - 1);

    final double clampedX = localPosition.dx.clamp(chartLeft, chartRight);
    final int nearestIndex = ((clampedX - chartLeft) / stepWidth)
        .round()
        .clamp(0, widget.dataPoints.length - 1);

    if (_selectedIndex != nearestIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = nearestIndex;
      });
      widget.onPointScrubbed?.call(nearestIndex);
    }

    _scrubController.forward();
  }

  void _handleTouchEnd() {
    _hideTooltipTimer?.cancel();
    _hideTooltipTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        _scrubController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _selectedIndex = null;
            });
            widget.onPointScrubbed?.call(null);
          }
        });
      }
    });
  }

  static String formatNumber(double amount) {
    final bool isNegative = amount < 0;
    final double absVal = amount.abs();
    final String intPart = absVal.truncate().toString();
    final String formattedInt = intPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '${isNegative ? '-' : ''}$formattedInt';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasEnoughData = widget.dataPoints.length >= 2;
    final double displayedAmount = (_selectedIndex != null &&
            _selectedIndex! < widget.dataPoints.length)
        ? widget.dataPoints[_selectedIndex!]
        : widget.totalIncome;

    final String displayedSubtitle = (_selectedIndex != null &&
            _selectedIndex! < widget.labels.length)
        ? 'في ${widget.labels[_selectedIndex!]}'
        : 'إجمالي الفترة المحددة';

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: AppColors.surfaceCardBorder,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: Stack(
          children: [
            // Embedded subtle background watermark icon
            Positioned(
              left: -15,
              top: -15,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_graph_rounded,
                  size: 135,
                  color: AppColors.spendoGreen.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
          // 1. Header: Period Filter Tabs & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPeriodTabs(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    width: 7.0,
                    height: 7.0,
                    decoration: const BoxDecoration(
                      color: AppColors.spendoGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.spendoGlow,
                          blurRadius: 6.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10.0),

          // 2. Metrics: Dynamic Total & Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  displayedSubtitle,
                  key: ValueKey<String>(displayedSubtitle),
                  style: TextStyle(
                    color: _selectedIndex != null
                        ? AppColors.spendoMint
                        : AppColors.textMuted,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.currencySymbol,
                    style: const TextStyle(
                      color: AppColors.spendoGreen,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      formatNumber(displayedAmount),
                      key: ValueKey<double>(displayedAmount),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12.0),

          // 3. Chart Area / Fallback Empty State
          Expanded(
            child: hasEnoughData
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanDown: (details) => _handleTouch(
                            details.localPosition, constraints.maxWidth),
                        onPanUpdate: (details) => _handleTouch(
                            details.localPosition, constraints.maxWidth),
                        onPanEnd: (_) => _handleTouchEnd(),
                        onPanCancel: () => _handleTouchEnd(),
                        onTapDown: (details) => _handleTouch(
                            details.localPosition, constraints.maxWidth),
                        onTapUp: (_) => _handleTouchEnd(),
                        child: AnimatedBuilder(
                          animation: _scrubController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(
                                  constraints.maxWidth, constraints.maxHeight),
                              painter: _SpendoIncomeChartPainter(
                                dataPoints: widget.dataPoints,
                                labels: widget.labels,
                                selectedIndex: _selectedIndex,
                                scrubProgress: _scrubController.value,
                                currencySymbol: widget.currencySymbol,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  )
                : _buildEmptyState(),
          ),
        ],
      ),
    ),
  ],
),
),
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCell,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.surfaceCellBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.periods.map((period) {
          final bool isSelected = period == widget.selectedPeriod;
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                HapticFeedback.lightImpact();
                widget.onPeriodChanged?.call(period);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.spendoGreen.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9.0),
                border: Border.all(
                  color: isSelected
                      ? AppColors.spendoGreen.withValues(alpha: 0.45)
                      : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Text(
                period,
                style: TextStyle(
                  color:
                      isSelected ? AppColors.spendoMint : AppColors.textMuted,
                  fontSize: 11.0,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: const _GhostChartPainter(),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceCell.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: AppColors.surfaceCellBorder,
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38.0,
                    height: 38.0,
                    decoration: BoxDecoration(
                      color: AppColors.spendoGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.spendoGreen.withValues(alpha: 0.25),
                        width: 1.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.spendoGreen,
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  const Text(
                    'بانتظار تسجيل المزيد من أيام العمل لرسم المنحنى',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  const Text(
                    'سجل يوميات عملك لرؤية تحليلات الدخل التفاعلية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter for rendering the smooth Catmull-Rom cubic bezier curve,
/// emerald gradient fill, glowing stroke, vertical scrubber, floating tooltip, and labels.
class _SpendoIncomeChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> labels;
  final int? selectedIndex;
  final double scrubProgress;
  final String currencySymbol;

  _SpendoIncomeChartPainter({
    required this.dataPoints,
    required this.labels,
    required this.selectedIndex,
    required this.scrubProgress,
    required this.currencySymbol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    const double paddingLeft = 20.0;
    final double paddingRight = size.width - 20.0;
    const double topPadding = 44.0;
    final double bottomPadding = size.height - 24.0;

    final double chartWidth = paddingRight - paddingLeft;
    final double chartHeight = bottomPadding - topPadding;

    final double rawMax = dataPoints.reduce(math.max);
    final double rawMin = dataPoints.reduce(math.min);
    final double minVal = math.min(0.0, rawMin);
    final double range = rawMax == minVal
        ? (rawMax == 0 ? 100.0 : rawMax * 1.2)
        : (rawMax - minVal) * 1.15;

    final List<Offset> points = [];
    final double stepX = chartWidth / (dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = paddingLeft + i * stepX;
      final double normalized = (dataPoints[i] - minVal) / range;
      final double y = bottomPadding - (normalized * chartHeight);
      points.add(Offset(x, y));
    }

    // Grid guide lines
    final Paint gridPaint = Paint()
      ..color = AppColors.surfaceCardBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      final double gridY = topPadding + (chartHeight * i / 4.0);
      _drawDashedHorizontal(
          canvas, paddingLeft, paddingRight, gridY, gridPaint);
    }

    // Smooth Catmull-Rom cubic bezier curve
    final Path curvePath = Path();
    curvePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = i > 0 ? points[i - 1] : points[i];
      final Offset p1 = points[i];
      final Offset p2 = points[i + 1];
      final Offset p3 = i < points.length - 2 ? points[i + 2] : p2;

      final double cp1X = p1.dx + (p2.dx - p0.dx) / 6.0;
      final double cp1Y =
          (p1.dy + (p2.dy - p0.dy) / 6.0).clamp(topPadding, bottomPadding);

      final double cp2X = p2.dx - (p3.dx - p1.dx) / 6.0;
      final double cp2Y =
          (p2.dy - (p3.dy - p1.dy) / 6.0).clamp(topPadding, bottomPadding);

      curvePath.cubicTo(cp1X, cp1Y, cp2X, cp2Y, p2.dx, p2.dy);
    }

    // Emerald gradient fill
    final Path fillPath = Path.from(curvePath)
      ..lineTo(points.last.dx, bottomPadding)
      ..lineTo(points.first.dx, bottomPadding)
      ..close();

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.spendoGreen.withValues(alpha: 0.25),
          AppColors.spendoGreen.withValues(alpha: 0.05),
          AppColors.spendoGreen.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(
          Rect.fromLTRB(paddingLeft, topPadding, paddingRight, bottomPadding));

    canvas.drawPath(fillPath, fillPaint);

    // Glowing stroke
    final Paint glowPaint = Paint()
      ..color = AppColors.spendoGreen.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawPath(curvePath, glowPaint);

    // Crisp emerald stroke
    final Paint strokePaint = Paint()
      ..color = AppColors.spendoGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(curvePath, strokePaint);

    // Data dots
    final Paint dotBgPaint = Paint()
      ..color = AppColors.surfaceCard
      ..style = PaintingStyle.fill;
    final Paint dotFillPaint = Paint()
      ..color = AppColors.spendoGreen
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final Offset pt = points[i];
      canvas.drawCircle(pt, 4.0, dotBgPaint);
      canvas.drawCircle(pt, 2.5, dotFillPaint);
    }

    // Scrubbing overlay
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length &&
        scrubProgress > 0.0) {
      final Offset activePoint = points[selectedIndex!];
      final double activeValue = dataPoints[selectedIndex!];
      final String activeLabel =
          selectedIndex! < labels.length ? labels[selectedIndex!] : '';

      // Vertical dashed line
      final Paint dashPaint = Paint()
        ..color = AppColors.spendoGreen.withValues(alpha: 0.6 * scrubProgress)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      _drawDashedVertical(
        canvas,
        activePoint.dx,
        topPadding - 8.0,
        bottomPadding,
        dashPaint,
      );

      // Glowing cursor
      final Paint pulsePaint = Paint()
        ..color = AppColors.spendoGreen.withValues(alpha: 0.22 * scrubProgress)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(activePoint, 13.0, pulsePaint);

      final Paint ringPaint = Paint()
        ..color = AppColors.spendoGreen.withValues(alpha: 0.9 * scrubProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(activePoint, 6.5, ringPaint);

      final Paint corePaint = Paint()
        ..color = Colors.white.withValues(alpha: scrubProgress)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(activePoint, 3.5, corePaint);

      // Floating tooltip
      _drawFloatingTooltip(
        canvas,
        size,
        activePoint,
        activeValue,
        activeLabel,
        paddingLeft,
        paddingRight,
        topPadding,
      );
    }

    // Bottom labels
    _drawLabels(canvas, size, points, bottomPadding);
  }

  void _drawDashedHorizontal(
    Canvas canvas,
    double startX,
    double endX,
    double y,
    Paint paint,
  ) {
    const double dashWidth = 4.0;
    const double dashSpace = 4.0;
    double currentX = startX;
    while (currentX < endX) {
      canvas.drawLine(
        Offset(currentX, y),
        Offset(math.min(currentX + dashWidth, endX), y),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawDashedVertical(
    Canvas canvas,
    double x,
    double startY,
    double endY,
    Paint paint,
  ) {
    const double dashHeight = 4.0;
    const double dashSpace = 4.0;
    double currentY = startY;
    while (currentY < endY) {
      canvas.drawLine(
        Offset(x, currentY),
        Offset(x, math.min(currentY + dashHeight, endY)),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  void _drawFloatingTooltip(
    Canvas canvas,
    Size size,
    Offset point,
    double value,
    String label,
    double minX,
    double maxX,
    double minY,
  ) {
    final String formattedVal =
        '${_SpendoIncomeChartState.formatNumber(value)} $currencySymbol';

    final TextSpan valSpan = TextSpan(
      text: formattedVal,
      style: TextStyle(
        color: Colors.white.withValues(alpha: scrubProgress),
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        fontFamily: 'Cairo',
      ),
    );
    final TextPainter valPainter = TextPainter(
      text: valSpan,
      textDirection: TextDirection.rtl,
    )..layout();

    TextPainter? lblPainter;
    if (label.isNotEmpty) {
      final TextSpan lblSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.textMuted.withValues(alpha: scrubProgress),
          fontSize: 10.0,
          fontWeight: FontWeight.w600,
          fontFamily: 'Cairo',
        ),
      );
      lblPainter = TextPainter(
        text: lblSpan,
        textDirection: TextDirection.rtl,
      )..layout();
    }

    final double contentWidth =
        math.max(valPainter.width, lblPainter?.width ?? 0.0);
    final double bubbleWidth = contentWidth + 20.0;
    final double bubbleHeight = valPainter.height +
        (lblPainter != null ? lblPainter.height + 1.0 : 0.0) +
        10.0;

    final double bubbleLeft =
        (point.dx - bubbleWidth / 2.0).clamp(minX, maxX - bubbleWidth);

    double bubbleTop = point.dy - bubbleHeight - 12.0;
    if (bubbleTop < 2.0) {
      bubbleTop = point.dy + 14.0;
    }

    final RRect bubbleRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
      const Radius.circular(10.0),
    );

    final Paint haloPaint = Paint()
      ..color = AppColors.spendoGreen.withValues(alpha: 0.28 * scrubProgress)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawRRect(bubbleRRect, haloPaint);

    final Paint bgPaint = Paint()
      ..color = const Color(0xFF141418).withValues(alpha: 0.96 * scrubProgress)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bubbleRRect, bgPaint);

    final Paint borderPaint = Paint()
      ..color = AppColors.spendoGreen.withValues(alpha: 0.5 * scrubProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bubbleRRect, borderPaint);

    final double valX = bubbleLeft + (bubbleWidth - valPainter.width) / 2.0;
    valPainter.paint(canvas, Offset(valX, bubbleTop + 5.0));

    if (lblPainter != null) {
      final double lblX = bubbleLeft + (bubbleWidth - lblPainter.width) / 2.0;
      lblPainter.paint(
          canvas, Offset(lblX, bubbleTop + 5.0 + valPainter.height + 1.0));
    }
  }

  void _drawLabels(
    Canvas canvas,
    Size size,
    List<Offset> points,
    double bottomPadding,
  ) {
    final int count = labels.length;
    if (count == 0) return;

    for (int i = 0; i < count && i < points.length; i++) {
      final bool isCurrent = (selectedIndex == i && scrubProgress > 0.0);
      final bool shouldShow = _shouldRenderLabel(i, count) || isCurrent;
      if (!shouldShow) continue;

      final TextSpan span = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: isCurrent ? AppColors.spendoMint : AppColors.textMuted,
          fontSize: 10.5,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          fontFamily: 'Cairo',
        ),
      );

      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.rtl,
      )..layout();

      final double lx =
          (points[i].dx - tp.width / 2.0).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(lx, bottomPadding + 6.0));
    }
  }

  bool _shouldRenderLabel(int index, int totalCount) {
    if (totalCount <= 7) return true;
    if (totalCount <= 14) return index % 2 == 0 || index == totalCount - 1;
    final int interval = (totalCount / 5).ceil();
    return index % interval == 0 || index == totalCount - 1;
  }

  @override
  bool shouldRepaint(covariant _SpendoIncomeChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.scrubProgress != scrubProgress ||
        oldDelegate.dataPoints != dataPoints ||
        oldDelegate.labels != labels ||
        oldDelegate.currencySymbol != currencySymbol;
  }
}

/// A subtle ghost wavy dashed curve painter used in the empty fallback state.
class _GhostChartPainter extends CustomPainter {
  const _GhostChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double paddingLeft = 20.0;
    final double paddingRight = size.width - 20.0;
    const double top = 20.0;
    final double bottom = size.height - 20.0;
    final double midY = (top + bottom) / 2.0;

    final Paint gridPaint = Paint()
      ..color = AppColors.surfaceCardBorder.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, paddingLeft, paddingRight, midY - 24.0, gridPaint);
    _drawDashedLine(canvas, paddingLeft, paddingRight, midY + 24.0, gridPaint);

    final Path wavePath = Path();
    const int segments = 6;
    final double segWidth = (paddingRight - paddingLeft) / segments;

    wavePath.moveTo(paddingLeft, midY);
    for (int i = 0; i < segments; i++) {
      final double x1 = paddingLeft + (i + 0.5) * segWidth;
      final double y1 = midY + (i.isEven ? -16.0 : 16.0);
      final double x2 = paddingLeft + (i + 1) * segWidth;
      final double y2 = midY;
      wavePath.quadraticBezierTo(x1, y1, x2, y2);
    }

    final Paint wavePaint = Paint()
      ..color = AppColors.surfaceCardBorder.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(wavePath, wavePaint);
  }

  void _drawDashedLine(
    Canvas canvas,
    double startX,
    double endX,
    double y,
    Paint paint,
  ) {
    const double dashWidth = 5.0;
    const double dashSpace = 5.0;
    double currentX = startX;
    while (currentX < endX) {
      canvas.drawLine(
        Offset(currentX, y),
        Offset(math.min(currentX + dashWidth, endX), y),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
