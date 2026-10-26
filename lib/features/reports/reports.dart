// Reports: GET /reports/{type}?from&to — a summary and paged rows for the
// caller's own slice (the API decides: owner = nursery, manager = their
// work, driver = their trips, customer = their purchases), or a CSV file.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/network_exceptions.dart';

enum ReportType { orders, quotations, deliveries }

enum DatePreset { thisMonth, lastMonth, thisYear, custom }

/// The days a preset covers, ending today at the latest.
DateTimeRange presetRange(DatePreset p, DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  switch (p) {
    case DatePreset.lastMonth:
      return DateTimeRange(
        start: DateTime(t.year, t.month - 1, 1),
        end: DateTime(t.year, t.month, 0), // day 0 = last day of last month
      );
    case DatePreset.thisYear:
      return DateTimeRange(start: DateTime(t.year, 1, 1), end: t);
    case DatePreset.thisMonth:
    case DatePreset.custom:
      return DateTimeRange(start: DateTime(t.year, t.month, 1), end: t);
  }
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ReportRow {
  final String reference;
  final String date;
  final String party;
  final String? mobile;
  final String status;
  final double? amount;
  final double? paid;
  final String? orderRef;

  const ReportRow({
    required this.reference,
    required this.date,
    required this.party,
    required this.status,
    this.mobile,
    this.amount,
    this.paid,
    this.orderRef,
  });

  factory ReportRow.fromJson(Map<String, dynamic> j) => ReportRow(
        reference: j['reference'] as String? ?? '',
        date: j['date'] as String? ?? '',
        party: j['party'] as String? ?? '',
        mobile: j['mobile'] as String?,
        status: j['status'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble(),
        paid: (j['paid'] as num?)?.toDouble(),
        orderRef: j['order_ref'] as String?,
      );
}

class ReportPage {
  /// The API leaves zero counts out: read them as 0.
  final Map<String, num> summary;
  final List<ReportRow> rows;
  final int page;
  final int totalPages;

  const ReportPage({
    required this.summary,
    required this.rows,
    required this.page,
    required this.totalPages,
  });

  num count(String key) => summary[key] ?? 0;

  factory ReportPage.fromJson(Map<String, dynamic> j) {
    final p = (j['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ReportPage(
      summary: ((j['summary'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, v as num)),
      rows: (j['rows'] as List? ?? const [])
          .map((e) => ReportRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      page: (p['page'] as num?)?.toInt() ?? 1,
      totalPages: (p['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

class ReportsRepository {
  final ApiClient _api;
  ReportsRepository(this._api);

  Map<String, dynamic> _query(DateTimeRange r) =>
      {'from': ymd(r.start), 'to': ymd(r.end)};

  Future<ReportPage> fetch(ReportType type, DateTimeRange range,
          {int page = 1,}) =>
      _api.get(
        ApiConstants.report(type.name),
        queryParameters: {..._query(range), 'page': page, 'per_page': 20},
        fromJson: (d) => ReportPage.fromJson(d as Map<String, dynamic>),
      );

  /// The CSV bytes and the file name the API suggests.
  Future<(List<int>, String)> csv(ReportType type, DateTimeRange range) async {
    try {
      final res = await _api.dio.get<List<int>>(
        ApiConstants.report(type.name),
        queryParameters: {..._query(range), 'format': 'csv'},
        options: Options(responseType: ResponseType.bytes),
      );
      final name = RegExp(r'filename="([^"]+)"')
              .firstMatch(res.headers.value('content-disposition') ?? '')
              ?.group(1) ??
          'greenroot-${type.name}-${ymd(range.start)}-to-${ymd(range.end)}.csv';
      return (res.data ?? const <int>[], name);
    } on DioException catch (e) {
      throw NetworkExceptions.fromDioException(e);
    }
  }
}

final reportsRepositoryProvider =
    Provider<ReportsRepository>((ref) => ReportsRepository(ApiClient.instance));
