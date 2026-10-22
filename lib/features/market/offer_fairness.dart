/// How an offer compares with a for-sale ad's asking price. Buyers can't go
/// below [minOfferShare] (the API refuses it too): lowball offers anger
/// sellers. The seller's own counter offers are not limited.
library;

/// Mirrors greenroot-api market `MinOfferShare`.
const minOfferShare = 0.7;

/// At or above this share of the asking price an offer reads as fair.
const goodOfferShare = 0.9;

enum OfferBand { good, bargain, tooLow }

/// The lowest offer a buyer may make, rounded up to the paisa like the API.
double minOfferFor(double asking) => (asking * minOfferShare * 100).ceil() / 100;

OfferBand offerBand(double offer, double asking) {
  if (offer >= asking * goodOfferShare) return OfferBand.good;
  if (offer >= minOfferFor(asking)) return OfferBand.bargain;
  return OfferBand.tooLow;
}

/// "11% below asking", "At the asking price", "5% above asking".
String offerVsAsking(double offer, double asking) {
  final pct = ((offer - asking) / asking * 100).round();
  if (pct == 0) return 'At the asking price';
  return pct < 0 ? '${-pct}% below asking' : '$pct% above asking';
}
