import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class Rating {
  final int id;
  final String ratingType;
  final int ratedByUserId;
  final int? orderId;
  final int? dispatchId;
  final int? overallRating;
  final bool? wouldRecommend;
  final int? driverBehaviourRating;
  final int? onTimeDeliveryRating;
  final int? plantConditionRating;
  final int? plantQualityRating;
  final int? communicationRating;
  final int? overallExperienceRating;
  final bool? wouldBuyAgain;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Rating({
    required this.id,
    required this.ratingType,
    required this.ratedByUserId,
    this.orderId,
    this.dispatchId,
    this.overallRating,
    this.wouldRecommend,
    this.driverBehaviourRating,
    this.onTimeDeliveryRating,
    this.plantConditionRating,
    this.plantQualityRating,
    this.communicationRating,
    this.overallExperienceRating,
    this.wouldBuyAgain,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Rating.fromJson(Map<String, dynamic> j) => Rating(
        id: (j['id'] as num).toInt(),
        ratingType: j['rating_type'] as String,
        ratedByUserId: (j['rated_by_user_id'] as num).toInt(),
        orderId: (j['order_id'] as num?)?.toInt(),
        dispatchId: (j['dispatch_id'] as num?)?.toInt(),
        overallRating: (j['overall_rating'] as num?)?.toInt(),
        wouldRecommend: j['would_recommend'] as bool?,
        driverBehaviourRating: (j['driver_behaviour_rating'] as num?)?.toInt(),
        onTimeDeliveryRating: (j['on_time_delivery_rating'] as num?)?.toInt(),
        plantConditionRating: (j['plant_condition_rating'] as num?)?.toInt(),
        plantQualityRating: (j['plant_quality_rating'] as num?)?.toInt(),
        communicationRating: (j['communication_rating'] as num?)?.toInt(),
        overallExperienceRating:
            (j['overall_experience_rating'] as num?)?.toInt(),
        wouldBuyAgain: j['would_buy_again'] as bool?,
        comment: j['comment'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class RatingRepository {
  final ApiClient _client;
  RatingRepository(this._client);

  Future<Rating> submitAppRating({
    required int overallRating,
    bool? wouldRecommend,
    String comment = '',
  }) async {
    return _client.post(
      ApiConstants.ratingsApp,
      data: {
        'overall_rating': overallRating,
        if (wouldRecommend != null) 'would_recommend': wouldRecommend,
        'comment': comment,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Rating.fromJson(d['rating'] as Map<String, dynamic>);
      },
    );
  }

  Future<Rating> submitOrderRating({
    required int orderId,
    int? plantQualityRating,
    int? communicationRating,
    int? overallExperienceRating,
    bool? wouldBuyAgain,
    String comment = '',
  }) async {
    return _client.post(
      ApiConstants.ratingsOrder(orderId),
      data: {
        if (plantQualityRating != null)
          'plant_quality_rating': plantQualityRating,
        if (communicationRating != null)
          'communication_rating': communicationRating,
        if (overallExperienceRating != null)
          'overall_experience_rating': overallExperienceRating,
        if (wouldBuyAgain != null) 'would_buy_again': wouldBuyAgain,
        'comment': comment,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Rating.fromJson(d['rating'] as Map<String, dynamic>);
      },
    );
  }

  Future<Rating> submitTripRating({
    required int dispatchId,
    int? driverBehaviourRating,
    int? onTimeDeliveryRating,
    int? plantConditionRating,
    String comment = '',
  }) async {
    return _client.post(
      ApiConstants.ratingsTrip(dispatchId),
      data: {
        if (driverBehaviourRating != null)
          'driver_behaviour_rating': driverBehaviourRating,
        if (onTimeDeliveryRating != null)
          'on_time_delivery_rating': onTimeDeliveryRating,
        if (plantConditionRating != null)
          'plant_condition_rating': plantConditionRating,
        'comment': comment,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return Rating.fromJson(d['rating'] as Map<String, dynamic>);
      },
    );
  }

  Future<Rating?> getMyOrderRating(int orderId) async {
    try {
      return await _client.get(
        ApiConstants.ratingsOrder(orderId),
        fromJson: (data) {
          final d = data as Map<String, dynamic>;
          final r = d['rating'];
          if (r == null) return null;
          return Rating.fromJson(r as Map<String, dynamic>);
        },
      );
    } on AppError {
      return null;
    }
  }

  Future<Rating?> getMyTripRating(int dispatchId) async {
    try {
      return await _client.get(
        ApiConstants.ratingsTrip(dispatchId),
        fromJson: (data) {
          final d = data as Map<String, dynamic>;
          final r = d['rating'];
          if (r == null) return null;
          return Rating.fromJson(r as Map<String, dynamic>);
        },
      );
    } on AppError {
      return null;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final ratingRepositoryProvider = Provider<RatingRepository>(
  (_) => RatingRepository(ApiClient.instance),
);
