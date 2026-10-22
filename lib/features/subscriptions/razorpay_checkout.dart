import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// A Razorpay order created by the API (POST /subscriptions/payment-order).
class PaymentOrder {
  final String orderId;
  final int amountPaise;
  final String currency;
  final String keyId;

  const PaymentOrder({
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> j) => PaymentOrder(
        orderId: j['order_id'] as String,
        amountPaise: (j['amount'] as num).toInt(),
        currency: j['currency'] as String? ?? 'INR',
        keyId: j['key_id'] as String,
      );
}

/// What checkout returns on success; the API verifies it before renewing.
class CheckoutResult {
  final String orderId;
  final String paymentId;
  final String signature;
  const CheckoutResult(this.orderId, this.paymentId, this.signature);
}

/// The user closed checkout without paying.
class CheckoutCancelled implements Exception {
  const CheckoutCancelled();
}

class CheckoutFailed implements Exception {
  final String message;
  const CheckoutFailed(this.message);
  @override
  String toString() => message;
}

/// Opens Razorpay Standard Checkout for [order]. Completes with the payment
/// result, or throws [CheckoutCancelled] / [CheckoutFailed].
Future<CheckoutResult> payWithRazorpay(
  PaymentOrder order, {
  required String description,
}) {
  final razorpay = Razorpay();
  final done = Completer<CheckoutResult>();
  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
    if (done.isCompleted) return;
    // Missing fields can't be verified; the API would reject them anyway.
    if (r.paymentId == null || r.signature == null) {
      done.completeError(
          const CheckoutFailed('Payment response was incomplete.'),);
      return;
    }
    done.complete(
        CheckoutResult(r.orderId ?? order.orderId, r.paymentId!, r.signature!),);
  });
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    if (done.isCompleted) return;
    done.completeError(
      r.code == Razorpay.PAYMENT_CANCELLED
          ? const CheckoutCancelled()
          : CheckoutFailed(
              r.message?.isNotEmpty == true
                  ? r.message!
                  : 'Payment failed. Please try again.',
            ),
    );
  });
  razorpay.open({
    'key': order.keyId,
    'order_id': order.orderId,
    'amount': order.amountPaise,
    'currency': order.currency,
    'name': 'GreenRoot',
    'description': description,
    'theme': {'color': '#166534'},
  });
  return done.future.whenComplete(razorpay.clear);
}
