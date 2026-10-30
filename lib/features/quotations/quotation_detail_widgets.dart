part of 'quotation_detail_screen.dart';

class _ManagerPickerSheet extends StatefulWidget {
  final int nurseryId;
  const _ManagerPickerSheet({required this.nurseryId});

  @override
  State<_ManagerPickerSheet> createState() => _ManagerPickerSheetState();
}

class _ManagerPickerSheetState extends State<_ManagerPickerSheet> {
  List<NurseryManager>? _managers;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final managers = await ApiClient.instance.get<List<NurseryManager>>(
        ApiConstants.nurseryManagers(widget.nurseryId),
        fromJson: (json) {
          final map = json as Map<String, dynamic>;
          final list = map['managers'] as List<dynamic>? ??
              map['users'] as List<dynamic>? ??
              [];
          return list
              .cast<Map<String, dynamic>>()
              .map(NurseryManager.fromJson)
              .toList();
        },
      );
      if (mounted) {
        setState(() {
          _managers = managers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 8,),
            child: Row(children: [
              const Expanded(child: Text('Assign Manager', style: AppTypography.h3)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),),
            ],),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        AppLoader(),)
                : _error != null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Failed to load managers',
                            style: AppTypography.body
                                .copyWith(color: AppColors.red600),),
                        TextButton(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _load();
                            },
                            child: const Text('Retry'),),
                      ],),)
                    : _managers == null || _managers!.isEmpty
                        ? Center(
                            child: Text('No managers in this nursery',
                                style: AppTypography.body
                                    .copyWith(color: AppColors.textMuted),),)
                        : ListView.separated(
                            controller: ctrl,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenPadding,
                                vertical: AppSpacing.md,),
                            itemCount: _managers!.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: AppColors.border,),
                            itemBuilder: (_, i) {
                              final m = _managers![i];
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.forest100,
                                  child: Text(
                                      m.name.isNotEmpty
                                          ? m.name[0].toUpperCase()
                                          : '?',
                                      style: AppTypography.body.copyWith(
                                          color: AppColors.primaryMain,
                                          fontWeight: FontWeight.w700,),),
                                ),
                                title: Text(m.name,
                                    style: AppTypography.body
                                        .copyWith(fontWeight: FontWeight.w600),),
                                subtitle: Text(m.identityLabel,
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,),),
                                trailing: const Icon(Icons.chevron_right,
                                    size: 18, color: AppColors.textMuted,),
                                onTap: () => Navigator.pop(context, m.userId),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _InfoCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label = status;
    switch (status) {
      case 'INTERNAL_DRAFT':
        bg = AppColors.border;
        fg = AppColors.textSecondary;
        label = 'Internal';
        break;
      case 'CUSTOMER_DRAFT':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        label = 'Draft';
        break;
      case 'CUSTOMER_SENT':
        bg = AppColors.blue100;
        fg = AppColors.blue600;
        label = 'Sent to Customer';
        break;
      case 'CUSTOMER_ACCEPTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Customer Accepted';
        break;
      case 'CUSTOMER_REJECTED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        label = 'Customer Rejected';
        break;
      case 'CONVERTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Converted to Order';
        break;
      case 'EXPIRED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        label = 'Expired';
        break;
      case 'CUSTOMER_REQUESTED':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        label = 'Customer Request';
        break;
      case 'REQUEST_DECLINED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        label = 'Declined';
        break;
      case 'REQUEST_CANCELLED':
        bg = AppColors.border;
        fg = AppColors.textSecondary;
        label = 'Cancelled';
        break;
      // Legacy
      case 'DRAFT':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        label = 'Draft';
        break;
      case 'SENT':
      case 'APPROVED':
        bg = AppColors.blue100;
        fg = AppColors.blue600;
        label = 'Sent';
        break;
      case 'BUYER_ACCEPTED':
      case 'ACCEPTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Accepted';
        break;
      default:
        bg = AppColors.red100;
        fg = AppColors.red600;
    }
    // Fade+scale "pulse" on status change (same treatment as the shared
    // StatusBadge in core/widgets/status_badge.dart) -- this screen has its
    // own badge because quotation statuses map to bespoke labels/colors.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: AppTypography.caption
                .copyWith(color: fg, fontWeight: FontWeight.w700),),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuOption({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Row(children: [
      Icon(icon, size: 18, color: c),
      const SizedBox(width: 10),
      Text(label, style: AppTypography.body.copyWith(color: c)),
    ],);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

// All timestamps in GreenRoot are displayed in IST (UTC+5:30), 12-hour with AM/PM.
String _fmt(String iso) {
  try {
    final ist =
        DateTime.parse(iso).toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${DateFormat("d MMM yyyy, h:mm a").format(ist)} IST';
  } catch (_) {
    return iso;
  }
}

String _qty(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

String _monthAbbr(int month) => const [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month];

String _fmtDate(DateTime dt) {
  final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${DateFormat("d MMM yyyy, h:mm a").format(ist)} IST';
}
