import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/market/offer_fairness.dart';

void main() {
  test('bands: 90%+ good, 70–89% bargain, below 70% too low', () {
    expect(offerBand(90, 90), OfferBand.good);
    expect(offerBand(81, 90), OfferBand.good); // exactly 90%
    expect(offerBand(80, 90), OfferBand.bargain);
    expect(offerBand(63, 90), OfferBand.bargain); // exactly 70%
    expect(offerBand(62.99, 90), OfferBand.tooLow);
  });

  test('minimum matches the API rounding (up to the paisa)', () {
    expect(minOfferFor(120), 84);
    expect(minOfferFor(99), 69.3);
  });

  test('comparison text', () {
    expect(offerVsAsking(80, 90), '11% below asking');
    expect(offerVsAsking(90, 90), 'At the asking price');
    expect(offerVsAsking(99, 90), '10% above asking');
  });
}
