/// Represents aggregated work logs statistics for a single employer/workplace (`إحصائيات المشغّل / الورشة`).
class EmployerStats {
  final int totalDays;
  final double totalEarned;
  final double totalCollected;
  final double totalRemaining;

  const EmployerStats({
    required this.totalDays,
    required this.totalEarned,
    required this.totalCollected,
    required this.totalRemaining,
  });

  /// هل تم تحصيل كامل المستحقات
  bool get isFullyCollected => totalRemaining <= 0.01;

  /// نسبة التحصيل من 0.0 إلى 1.0
  double get collectionProgress =>
      totalEarned > 0 ? (totalCollected / totalEarned).clamp(0.0, 1.0) : 1.0;

  static const empty = EmployerStats(
    totalDays: 0,
    totalEarned: 0.0,
    totalCollected: 0.0,
    totalRemaining: 0.0,
  );
}
