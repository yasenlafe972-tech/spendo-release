/// Represents aggregated financial statistics for debts and personal loans (`السلف والديون`).
class DebtSummaryStats {
  /// إجمالي ما لي عند الناس (أخذوا مني مصاري) - المتبقي غير المسدد
  final double totalTheyOwe;

  /// إجمالي ما علي للناس (أخذت منهم مصاري) - المتبقي غير المسدد
  final double totalIOwe;

  /// صافي الرصيد المالي (ما لي - ما علي)
  /// موجب = لك رصيد إجمالي فائض عند الناس
  /// سالب = عليك التزامات ومستحقات للناس
  final double netBalance;

  /// عدد الديون النشطة الجارية (غير المسددة)
  final int activeCount;

  /// عدد الديون التي تم سدادها بالكامل
  final int settledCount;

  const DebtSummaryStats({
    required this.totalTheyOwe,
    required this.totalIOwe,
    required this.netBalance,
    required this.activeCount,
    required this.settledCount,
  });

  /// هل الرصيد الصافي موجب لصالحي
  bool get hasPositiveBalance => netBalance > 0.01;

  /// هل الرصيد الصافي سالب علي
  bool get hasNegativeBalance => netBalance < -0.01;

  /// هل الحسابات متوازنة تماماً
  bool get isBalanced => !hasPositiveBalance && !hasNegativeBalance;
}
