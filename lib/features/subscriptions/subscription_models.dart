// ── Subscription data models ──────────────────────────────────────────────────

class SubscriptionPayment {
  final int id;
  final String? paymentCode;
  final double amount;
  final String paymentMethod;
  final String status;
  final DateTime? paymentDate;
  final String? provider;
  final String? notes;

  const SubscriptionPayment({
    required this.id,
    this.paymentCode,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.paymentDate,
    this.provider,
    this.notes,
  });

  factory SubscriptionPayment.fromJson(Map<String, dynamic> j) =>
      SubscriptionPayment(
        id: (j['id'] as num).toInt(),
        paymentCode: j['payment_code'] as String?,
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: j['payment_method'] as String? ?? '',
        status: j['payment_status'] as String? ?? j['status'] as String? ?? '',
        paymentDate: j['payment_date'] != null
            ? DateTime.tryParse(j['payment_date'] as String)
            : null,
        provider: j['provider'] as String?,
        notes: j['notes'] as String?,
      );
}

class SubscriptionModel {
  final int id;
  final String subscriptionCode;
  final int? planId;
  final String planCode;
  final String planName;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final bool autoRenew;
  final int? daysRemaining;
  final SubscriptionPayment? latestPayment;

  const SubscriptionModel({
    required this.id,
    required this.subscriptionCode,
    this.planId,
    required this.planCode,
    required this.planName,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.autoRenew,
    this.daysRemaining,
    this.latestPayment,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> j) =>
      SubscriptionModel(
        id: (j['id'] as num).toInt(),
        subscriptionCode: j['subscription_code'] as String,
        planId: j['plan_id'] != null ? (j['plan_id'] as num).toInt() : null,
        planCode: j['plan_code'] as String? ?? '',
        planName: j['plan_name'] as String? ?? '',
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: j['end_date'] != null
            ? DateTime.tryParse(j['end_date'] as String)
            : null,
        status: j['subscription_status'] as String? ?? '',
        autoRenew: j['auto_renew'] as bool? ?? false,
        daysRemaining: j['days_remaining'] != null
            ? (j['days_remaining'] as num).toInt()
            : null,
        latestPayment: j['latest_payment'] != null
            ? SubscriptionPayment.fromJson(
                j['latest_payment'] as Map<String, dynamic>)
            : null,
      );

  bool get isActive => status == 'ACTIVE';
  bool get isTrial => planCode == 'TRIAL';
  bool get isExpired => status == 'EXPIRED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isExpiringSoon =>
      isActive && daysRemaining != null && daysRemaining! <= 30;
}

class SubscriptionPlan {
  final int id;
  final String planCode;
  final String planName;
  final String? description;
  final double? sixMonthPrice;
  final double? yearlyPrice;
  final double? mrpSixMonthPrice;
  final double? mrpYearlyPrice;
  final int? maxManagers;
  final Map<String, dynamic>? features;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    required this.planCode,
    required this.planName,
    this.description,
    this.sixMonthPrice,
    this.yearlyPrice,
    this.mrpSixMonthPrice,
    this.mrpYearlyPrice,
    this.maxManagers,
    this.features,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) {
    final features = j['features'] as Map<String, dynamic>?;
    return SubscriptionPlan(
      id: (j['id'] as num).toInt(),
      planCode: j['plan_code'] as String,
      planName: j['plan_name'] as String,
      description: j['description'] as String?,
      sixMonthPrice: (j['six_month_price'] as num?)?.toDouble(),
      yearlyPrice: (j['yearly_price'] as num?)?.toDouble(),
      mrpSixMonthPrice: (features?['mrp_six_month'] as num?)?.toDouble(),
      mrpYearlyPrice: (features?['mrp_yearly'] as num?)?.toDouble(),
      maxManagers: (j['max_managers'] as num?)?.toInt(),
      features: features,
      isActive: j['is_active'] as bool? ?? true,
    );
  }

  int get sixMonthDiscountPct {
    if (sixMonthPrice == null || mrpSixMonthPrice == null || mrpSixMonthPrice! <= 0) return 0;
    if (sixMonthPrice! >= mrpSixMonthPrice!) return 0;
    return ((mrpSixMonthPrice! - sixMonthPrice!) / mrpSixMonthPrice! * 100).round();
  }

  int get yearlyDiscountPct {
    if (yearlyPrice == null || mrpYearlyPrice == null || mrpYearlyPrice! <= 0) return 0;
    if (yearlyPrice! >= mrpYearlyPrice!) return 0;
    return ((mrpYearlyPrice! - yearlyPrice!) / mrpYearlyPrice! * 100).round();
  }
}
