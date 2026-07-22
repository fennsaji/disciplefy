import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/subscription/data/models/subscription_model.dart';

void main() {
  // Row shape the backend now writes (provider_* naming, nullable extras).
  final row = <String, dynamic>{
    'id': '11111111-1111-1111-1111-111111111111',
    'subscription_id': '22222222-2222-2222-2222-222222222222',
    'user_id': '33333333-3333-3333-3333-333333333333',
    'invoice_number': 'INV-pay_TGb8PRRIDOWJtu',
    'provider': 'razorpay',
    'provider_payment_id': 'pay_TGb8PRRIDOWJtu',
    'provider_invoice_id': null,
    'amount_paise': 14900,
    'currency': 'INR',
    'billing_period_start': '2026-07-22T15:28:50+00:00',
    'billing_period_end': '2026-08-21T18:30:00+00:00',
    'status': 'paid',
    'payment_method': 'upi',
    'paid_at': '2026-07-22T15:29:58+00:00',
    'created_at': '2026-07-22T15:29:58+00:00',
  };

  test('parses an invoice row using provider_payment_id', () {
    final invoice = SubscriptionInvoiceModel.fromJson(row);
    expect(invoice.razorpayPaymentId, 'pay_TGb8PRRIDOWJtu');
    expect(invoice.amountPaise, 14900);
    expect(invoice.status, 'paid');
  });

  test('does not throw when the payment id is absent', () {
    final withoutPayment = Map<String, dynamic>.from(row)
      ..remove('provider_payment_id');
    expect(() => SubscriptionInvoiceModel.fromJson(withoutPayment),
        returnsNormally);
  });
}
