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
  final double? monthlyPrice;
  final double? yearlyPrice;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    required this.planCode,
    required this.planName,
    this.description,
    this.monthlyPrice,
    this.yearlyPrice,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        id: (j['id'] as num).toInt(),
        planCode: j['plan_code'] as String,
        planName: j['plan_name'] as String,
        description: j['description'] as String?,
        monthlyPrice: j['monthly_price'] != null
            ? (j['monthly_price'] as num).toDouble()
            : null,
        yearlyPrice: j['yearly_price'] != null
            ? (j['yearly_price'] as num).toDouble()
            : null,
        isActive: j['is_active'] as bool? ?? true,
      );
}
