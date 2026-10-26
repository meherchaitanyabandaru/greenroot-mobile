import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/reports/reports.dart';
import 'package:greenroot_mobile/features/reports/reports_screen.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fixtures.dart';

class _FakeRepo extends ReportsRepository {
  _FakeRepo() : super(ApiClient.instance);
  final calls = <ReportType>[];
  int csvCalls = 0;
  AppError? fail;
  Map<String, dynamic> body = {
    'summary': {'total': 3, 'delivered': 1, 'cancelled': 1, 'sales': 1500, 'paid': 1000},
    'rows': [
      {'reference': 'ORD-1', 'date': '2026-10-26', 'party': 'Ravi', 'mobile': '98xxxxx210', 'status': 'IN_TRANSIT', 'amount': 1500},
    ],
    'pagination': {'page': 1, 'per_page': 20, 'total': 3, 'total_pages': 1},
  };
  final csvGate = Completer<void>();

  @override
  Future<ReportPage> fetch(ReportType type, DateTimeRange range, {int page = 1}) async {
    calls.add(type);
    if (fail != null) throw fail!;
    return ReportPage.fromJson(body);
  }

  @override
  Future<(List<int>, String)> csv(ReportType type, DateTimeRange range) async {
    csvCalls++;
    await csvGate.future;
    throw const UnknownError(); // the API refused or the network dropped
  }
}

Future<_FakeRepo> _open(WidgetTester t, {String who = 'owner', _FakeRepo? repo}) async {
  final r = repo ?? _FakeRepo();
  await t.pumpWidget(ProviderScope(
    overrides: [signedInAs(who), reportsRepositoryProvider.overrideWithValue(r)],
    child: const MaterialApp(home: ReportsScreen()),
  ),);
  await t.pump();
  await t.pump();
  return r;
}

void main() {
  setUpAll(FakeApiClient.new); // sets up config, logger and ApiClient

  test('date presets: this month, last month across the year end, this year', () {
    final jan5 = DateTime(2026, 1, 5, 18, 30);
    expect(presetRange(DatePreset.thisMonth, jan5), DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)));
    expect(presetRange(DatePreset.lastMonth, jan5), DateTimeRange(start: DateTime(2025, 12, 1), end: DateTime(2025, 12, 31)));
    expect(presetRange(DatePreset.thisYear, DateTime(2026, 3, 1)), DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 3, 1)));
    expect(presetRange(DatePreset.lastMonth, DateTime(2024, 3, 10)).end, DateTime(2024, 2, 29));
    expect(ymd(DateTime(2026, 2, 3)), '2026-02-03');
  });

  test('counts the API leaves out read as 0', () {
    final p = ReportPage.fromJson({'summary': {'total': 2}, 'rows': [], 'pagination': {}});
    expect(p.count('total'), 2);
    expect(p.count('cancelled'), 0);
    expect(p.totalPages, 1);
  });

  testWidgets('owner: summary and rows; switching type reloads that report', (t) async {
    final repo = await _open(t);
    expect(find.text('Sales (delivered)'), findsOneWidget);
    expect(find.text('₹1,500'), findsWidgets);
    expect(find.text('ORD-1'), findsOneWidget);
    expect(find.text('In transit'), findsOneWidget);
    await t.tap(find.text('Quotations'));
    await t.pump();
    await t.pump();
    expect(repo.calls, [ReportType.orders, ReportType.quotations]);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('customer sees their spend, not sales', (t) async {
    await _open(t, who: 'buyer');
    expect(find.text('Spent (delivered)'), findsOneWidget);
  });

  testWidgets('API error shows retry; empty dates show the empty state', (t) async {
    final repo = _FakeRepo()..fail = const UnknownError();
    await _open(t, repo: repo);
    expect(find.text('Try Again'), findsOneWidget);
    repo
      ..fail = null
      ..body = {'summary': {'total': 0}, 'rows': [], 'pagination': {'page': 1, 'total_pages': 0}};
    await t.tap(find.text('Try Again'));
    await t.pump();
    await t.pump();
    expect(find.text('Nothing in these dates'), findsOneWidget);
    final btn = t.widget<FilledButton>(find.byType(FilledButton).last);
    expect(btn.onPressed, isNull, reason: 'nothing to download');
  });

  testWidgets('download: one request even if tapped twice; an API failure says so', (t) async {
    final repo = await _open(t);
    await t.tap(find.text('Download CSV'));
    await t.pump();
    expect(find.text('Preparing CSV…'), findsOneWidget);
    await t.tap(find.text('Preparing CSV…'), warnIfMissed: false);
    await t.pump();
    expect(repo.csvCalls, 1);
    repo.csvGate.complete();
    await t.pump();
    await t.pump();
    expect(find.textContaining('Could not download the CSV'), findsOneWidget);
    expect(find.text('Download CSV'), findsOneWidget, reason: 'the button comes back');
  });
}
