import '../widgets/status_badge.dart';

class BackendLifecycleDisplay {
  final String label;
  final String title;
  final String subtitle;
  final BadgeVariant variant;

  const BackendLifecycleDisplay({
    required this.label,
    required this.title,
    this.subtitle = '',
    this.variant = BadgeVariant.neutral,
  });

  factory BackendLifecycleDisplay.fromJson(Map<String, dynamic> json) =>
      BackendLifecycleDisplay(
        label: json['label'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        variant: _variantFromJson(json['variant'] as String?),
      );
}

class BackendNextActions {
  final List<String> customer;
  final List<String> operator;
  final List<String> driver;
  final List<String> supplier;

  const BackendNextActions({
    this.customer = const [],
    this.operator = const [],
    this.driver = const [],
    this.supplier = const [],
  });

  factory BackendNextActions.fromJson(Map<String, dynamic> json) =>
      BackendNextActions(
        customer: _stringList(json['customer']),
        operator: _stringList(json['operator']),
        driver: _stringList(json['driver']),
        supplier: _stringList(json['supplier']),
      );
}

class BackendLifecycle {
  final BackendLifecycleDisplay? customer;
  final BackendLifecycleDisplay? operator;
  final BackendLifecycleDisplay? driver;
  final BackendLifecycleDisplay? requester;
  final BackendLifecycleDisplay? supplier;
  final BackendNextActions nextActions;

  const BackendLifecycle({
    this.customer,
    this.operator,
    this.driver,
    this.requester,
    this.supplier,
    this.nextActions = const BackendNextActions(),
  });

  factory BackendLifecycle.fromJson(Map<String, dynamic> json) =>
      BackendLifecycle(
        customer: _display(json['customer']),
        operator: _display(json['operator']),
        driver: _display(json['driver']),
        requester: _display(json['requester']),
        supplier: _display(json['supplier']),
        nextActions: json['next_actions'] is Map<String, dynamic>
            ? BackendNextActions.fromJson(
                json['next_actions'] as Map<String, dynamic>,
              )
            : const BackendNextActions(),
      );
}

BackendLifecycleDisplay? _display(Object? value) =>
    value is Map<String, dynamic>
        ? BackendLifecycleDisplay.fromJson(value)
        : null;

List<String> _stringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

BadgeVariant _variantFromJson(String? value) {
  switch (value?.toLowerCase()) {
    case 'success':
      return BadgeVariant.success;
    case 'warning':
      return BadgeVariant.warning;
    case 'error':
      return BadgeVariant.error;
    case 'info':
      return BadgeVariant.info;
    case 'accent':
      return BadgeVariant.accent;
    default:
      return BadgeVariant.neutral;
  }
}
