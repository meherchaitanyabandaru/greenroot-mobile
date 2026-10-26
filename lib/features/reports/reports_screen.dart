import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utilities/money.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'reports.dart';

/// Route: /reports. Every role opens it; the API decides whose rows they get.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late ReportType _type;
  DatePreset _preset = DatePreset.thisMonth;
  late DateTimeRange _range;
  ReportPage? _first;
  final List<ReportRow> _rows = [];
  int _page = 1;
  bool _loading = true, _loadingMore = false, _downloading = false;
  AppError? _error;
  int _request = 0; // only the latest request may update the screen

  bool get _driverOnly =>
      ref.read(sessionProvider).capabilities.isDriverOnly;
  bool get _buying {
    final c = ref.read(sessionProvider).capabilities;
    return !c.canSell && !c.isDriverOnly;
  }

  @override
  void initState() {
    super.initState();
    _type = _driverOnly ? ReportType.deliveries : ReportType.orders;
    _range = presetRange(_preset, DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final req = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page =
          await ref.read(reportsRepositoryProvider).fetch(_type, _range);
      if (!mounted || req != _request) return;
      setState(() {
        _first = page;
        _rows
          ..clear()
          ..addAll(page.rows);
        _page = 1;
        _loading = false;
      });
    } on AppError catch (e) {
      if (!mounted || req != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final req = _request;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(reportsRepositoryProvider)
          .fetch(_type, _range, page: _page + 1);
      if (!mounted || req != _request) return;
      setState(() {
        _rows.addAll(page.rows);
        _page = page.page;
      });
    } on AppError catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickPreset(DatePreset p) async {
    var range = presetRange(p, DateTime.now());
    if (p == DatePreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        // The API allows at most 3 years in one report.
        firstDate: DateTime(now.year - 3, now.month, now.day),
        lastDate: now,
        initialDateRange: _range,
        helpText: 'Report dates',
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _preset = p;
      _range = range;
    });
    _load();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final (bytes, name) =
          await ref.read(reportsRepositoryProvider).csv(_type, _range);
      final file = File('${(await getTemporaryDirectory()).path}/$name');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
          subject: name,);
      _snack('CSV ready: $name');
    } on AppError catch (e) {
      _snack('Could not download the CSV. ${e.message}', error: true);
    } catch (_) {
      _snack('Could not save the CSV on this phone.', error: true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.red600 : AppColors.primaryMain,
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final hasRows = _rows.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: FilledButton.icon(
          onPressed: _downloading || _loading || !hasRows ? null : _download,
          icon: _downloading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white,),
                )
              : const Icon(Icons.download_rounded),
          label: Text(_downloading ? 'Preparing CSV…' : 'Download CSV'),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryMain,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (!_driverOnly) ...[
              SegmentedButton<ReportType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ReportType.orders, label: Text('Orders')),
                  ButtonSegment(
                      value: ReportType.quotations, label: Text('Quotations'),),
                  ButtonSegment(
                      value: ReportType.deliveries, label: Text('Deliveries'),),
                ],
                selected: {_type},
                onSelectionChanged: (s) {
                  setState(() => _type = s.first);
                  _load();
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (p, label) in const [
                  (DatePreset.thisMonth, 'This month'),
                  (DatePreset.lastMonth, 'Last month'),
                  (DatePreset.thisYear, 'This year'),
                  (DatePreset.custom, 'Custom'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _preset == p,
                    onSelected: (_) => _pickPreset(p),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${fmt.format(_range.start)} – ${fmt.format(_range.end)}',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: AppLoader()),
              )
            else if (_error != null)
              ErrorState(error: _error, onRetry: _load)
            else ...[
              _Summary(type: _type, page: _first!, buying: _buying),
              const SizedBox(height: AppSpacing.lg),
              if (!hasRows)
                const EmptyState(
                  icon: Icons.insert_chart_outlined_rounded,
                  title: 'Nothing in these dates',
                  subtitle: 'Try another month or a custom range.',
                )
              else ...[
                for (final r in _rows) _RowTile(row: r),
                if (_page < _first!.totalPages)
                  Center(
                    child: _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: AppLoader(size: 28),
                          )
                        : TextButton(
                            onPressed: _loadMore,
                            child: const Text('Load more'),
                          ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final ReportType type;
  final ReportPage page;
  final bool buying;
  const _Summary({required this.type, required this.page, required this.buying});

  @override
  Widget build(BuildContext context) {
    String n(String k) => page.count(k).toString();
    String money(String k) => inr(page.count(k), paise: false);
    final cards = switch (type) {
      ReportType.orders => [
          ('Orders', n('total')),
          ('Delivered', n('delivered')),
          ('Cancelled', n('cancelled')),
          (buying ? 'Spent (delivered)' : 'Sales (delivered)', money('sales')),
          ('Paid', money('paid')),
        ],
      ReportType.quotations => [
          ('Quotations', n('total')),
          ('Accepted', n('accepted')),
          ('Pending', n('pending')),
          ('Rejected / expired', n('rejected_expired')),
        ],
      ReportType.deliveries => [
          ('Deliveries', n('total')),
          ('Delivered', n('delivered')),
          ('In progress', n('in_progress')),
          ('Cancelled', n('cancelled')),
        ],
    };
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - AppSpacing.sm) / 2;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final (label, value) in cards)
            Container(
              width: w,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: AppTypography.h3),
                  const SizedBox(height: 2),
                  Text(label,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),),
                ],
              ),
            ),
        ],
      );
    },);
  }
}

class _RowTile extends StatelessWidget {
  final ReportRow row;
  const _RowTile({required this.row});

  static String _label(String s) => s.isEmpty
      ? s
      : s[0] + s.substring(1).toLowerCase().replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final sub = [
      row.date,
      if (row.party.isNotEmpty) row.party,
      if (row.mobile != null) row.mobile!,
      if (row.orderRef != null && row.orderRef!.isNotEmpty) row.orderRef!,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.reference, style: AppTypography.label),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (row.amount != null)
                Text(inr(row.amount!, paise: false), style: AppTypography.label),
              Text(_label(row.status),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),),
            ],
          ),
        ],
      ),
    );
  }
}
