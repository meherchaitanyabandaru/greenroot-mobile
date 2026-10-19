// Top items: the nursery's showcase — up to 20 plants (size, optional price,
// quality notes, photos) it is known for. Not stock: orders never change it.
// API: GET /nurseries/:id/top-items, POST /top-items, PUT/DELETE /top-items/:id.
// Owner and managers edit; everyone signed in can read.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../auth/presentation/providers/session_provider.dart';

const int maxTopItems = 20;

class TopItem {
  final int id;
  final int nurseryId;
  final int plantId;
  final String scientificName;
  final String? commonName;
  final int sizeId;
  final String sizeName;
  final double? unitPrice;
  final int displayOrder;
  final String? qualityNotes;
  final List<String> photos;
  final bool canEdit;

  const TopItem({
    required this.id,
    required this.nurseryId,
    required this.plantId,
    required this.scientificName,
    this.commonName,
    required this.sizeId,
    required this.sizeName,
    this.unitPrice,
    required this.displayOrder,
    this.qualityNotes,
    this.photos = const [],
    this.canEdit = false,
  });

  String get plantName => commonName?.isNotEmpty == true ? commonName! : scientificName;

  factory TopItem.fromJson(Map<String, dynamic> j) => TopItem(
        id: (j['id'] as num).toInt(),
        nurseryId: (j['nursery_id'] as num).toInt(),
        plantId: (j['plant_id'] as num).toInt(),
        scientificName: j['scientific_name'] as String? ?? '',
        commonName: j['common_name'] as String?,
        sizeId: (j['size_id'] as num).toInt(),
        sizeName: j['size_name'] as String? ?? '',
        unitPrice: (j['unit_price'] as num?)?.toDouble(),
        displayOrder: (j['display_order'] as num?)?.toInt() ?? 0,
        qualityNotes: j['quality_notes'] as String?,
        photos: (j['photos'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
        canEdit: (j['capabilities'] as Map<String, dynamic>?)?['can_edit'] as bool? ?? false,
      );
}

/// What the add/edit sheet sends.
class TopItemDraft {
  final int plantId;
  final int sizeId;
  final double? unitPrice;
  final String? qualityNotes;
  final List<String> photos;

  const TopItemDraft({
    required this.plantId,
    required this.sizeId,
    this.unitPrice,
    this.qualityNotes,
    this.photos = const [],
  });

  Map<String, dynamic> toJson() => {
        'plant_id': plantId,
        'size_id': sizeId,
        'unit_price': unitPrice,
        'quality_notes': (qualityNotes?.trim().isEmpty ?? true) ? null : qualityNotes!.trim(),
        'photos': photos,
      };
}

final topItemsProvider =
    StateNotifierProvider.autoDispose<TopItemsNotifier, AsyncValue<List<TopItem>>>(
  (ref) => TopItemsNotifier(ref.read(sessionProvider).nurseryId),
);

class TopItemsNotifier extends StateNotifier<AsyncValue<List<TopItem>>> {
  final int? nurseryId;

  TopItemsNotifier(this.nurseryId) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    final nid = nurseryId;
    if (nid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final data = await ApiClient.instance.get<Map<String, dynamic>>(ApiConstants.nurseryTopItems(nid));
      state = AsyncValue.data(
        (data['top_items'] as List<dynamic>? ?? [])
            .map((e) => TopItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Returns null on success, or a message to show.
  Future<String?> add(TopItemDraft draft) async {
    final nid = nurseryId;
    if (nid == null) return 'No nursery selected';
    return _write(() => ApiClient.instance.post<Map<String, dynamic>>(
          ApiConstants.topItems,
          data: {'nursery_id': nid, ...draft.toJson()},
        ),);
  }

  Future<String?> save(int id, TopItemDraft draft) =>
      _write(() => ApiClient.instance.put<Map<String, dynamic>>(ApiConstants.topItemById(id), data: draft.toJson()));

  Future<String?> remove(int id) => _write(() => ApiClient.instance.delete<dynamic>(ApiConstants.topItemById(id)));

  Future<String?> _write(Future<dynamic> Function() call) async {
    try {
      await call();
      await refresh();
      return null;
    } on AppError catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Try again.';
    }
  }
}
