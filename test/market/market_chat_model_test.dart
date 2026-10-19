import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';

void main() {
  test('a chat with an accepted offer parses its deal, offers and read-only state', () {
    final e = MarketEnquiry.fromJson({
      'id': 4,
      'code': 'ENQ-000004',
      'ad_id': 9,
      'ad_title': 'Sweet grafts',
      'ad_status': 'ARCHIVED',
      'ad_price_per_unit': 120,
      'ad_price_unit': 'PER_PLANT',
      'ad_nursery_name': 'Green Nursery',
      'enquiring_nursery_name': 'Rival Nursery',
      'message': 'Need 50',
      'status': 'DEAL_AGREED',
      'agreed_price_per_unit': 110,
      'agreed_quantity': 50,
      'created_at': '2026-10-19T10:00:00Z',
      'capabilities': {
        'can_reply': false,
        'can_offer': false,
        'read_only_reason': 'this ad is no longer active',
      },
      'messages': [
        {
          'id': 7,
          'sent_by_nursery_id': 1,
          'nursery_name': 'Green Nursery',
          'sender_name': 'Priya Owner',
          'type': 'OFFER',
          'body': 'Offered ₹110 per plant × 50',
          'offer_price_per_unit': 110,
          'offer_quantity': 50,
          'offer_status': 'ACCEPTED',
          'is_mine': false,
          'can_respond': false,
          'created_at': '2026-10-19T10:05:00Z',
        },
        {
          'id': 8,
          'sent_by_nursery_id': 2,
          'nursery_name': 'Rival Nursery',
          'type': 'SYSTEM',
          'body': 'Deal agreed: ₹110 per plant × 50',
          'created_at': '2026-10-19T10:06:00Z',
        },
      ],
    });

    expect(e.isDealAgreed, isTrue);
    expect(e.agreedPricePerUnit, 110);
    expect(e.agreedQuantity, 50);
    expect(e.adStatus, 'ARCHIVED');
    expect(e.capabilities!.canReply, isFalse);
    expect(e.capabilities!.readOnlyReason, 'this ad is no longer active');

    final offer = e.messages.first;
    expect(offer.isOffer, isTrue);
    expect(offer.offerPrice, 110);
    expect(offer.offerQuantity, 50);
    expect(offer.offerStatus, 'ACCEPTED');
    expect(offer.senderName, 'Priya Owner');
    expect(e.messages.last.isSystem, isTrue);
  });

  test('an older chat without the new fields still parses', () {
    final e = MarketEnquiry.fromJson({
      'id': 1,
      'code': 'ENQ-000001',
      'ad_id': 1,
      'ad_title': 'Mango',
      'ad_nursery_name': 'A',
      'enquiring_nursery_name': 'B',
      'message': 'hi',
      'status': 'IN_PROGRESS',
      'created_at': '2026-10-19T10:00:00Z',
      'messages': [
        {
          'id': 1,
          'sent_by_nursery_id': 2,
          'nursery_name': 'B',
          'body': 'hi',
          'created_at': '2026-10-19T10:00:00Z',
        },
      ],
    });
    expect(e.messages.single.type, 'TEXT');
    expect(e.messages.single.isMine, isFalse);
    expect(e.isDealAgreed, isFalse);
  });
}
