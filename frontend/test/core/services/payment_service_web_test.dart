@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/services/payment_service_web.dart';

/// Stands in for the Razorpay checkout script: records the options it was
/// constructed with and lets the test fire the callbacks Razorpay would.
class _StubRazorpay {
  Object? options;
  JSObject? optionsRaw;
  final Map<String, JSFunction> events = {};
  int openCount = 0;

  void install() {
    final instance = JSObject();
    instance.setProperty(
      'on'.toJS,
      ((String event, JSFunction callback) {
        events[event] = callback;
      }).toJS,
    );
    instance.setProperty(
      'open'.toJS,
      (() {
        openCount++;
      }).toJS,
    );

    // A JS constructor that returns an object yields that object from `new`.
    final constructor = ((JSObject opts) {
      optionsRaw = opts;
      options = opts.dartify();
      return instance;
    }).toJS;

    globalContext.setProperty('Razorpay'.toJS, constructor);
  }

  void remove() => globalContext.delete('Razorpay'.toJS);

  /// Invoke the success handler Razorpay would call on payment completion.
  void succeed(Map<String, String> response) {
    final handler = optionsRaw!.getProperty<JSFunction>('handler'.toJS);
    handler.callAsFunction(null, response.jsify());
  }

  /// Invoke modal.ondismiss the way Razorpay does — with one argument.
  void dismiss() {
    final modal = optionsRaw!.getProperty<JSObject>('modal'.toJS);
    final ondismiss = modal.getProperty<JSFunction>('ondismiss'.toJS);
    ondismiss.callAsFunction(null, 'ignored-argument'.toJS);
  }

  void failPayment(Map<String, dynamic> payload) =>
      events['payment.failed']!.callAsFunction(null, payload.jsify());
}

void main() {
  late _StubRazorpay stub;

  setUp(() {
    stub = _StubRazorpay()..install();
  });

  tearDown(() => stub.remove());

  Future<void> open({
    void Function(Map<String, dynamic>)? onSuccess,
    void Function()? onDismiss,
    void Function(Map<String, dynamic>)? onFailed,
  }) =>
      PaymentServiceWeb.openCheckout(
        options: {
          'key': 'rzp_test_key',
          'amount': 4900,
          'currency': 'INR',
          'order_id': 'order_ABC123',
        },
        onSuccess: onSuccess ?? (_) {},
        onDismiss: onDismiss ?? () {},
        onFailed: onFailed ?? (_) {},
      );

  test('hasProperty detects the Razorpay global', () {
    expect(PaymentServiceWeb.hasProperty('Razorpay'), isTrue);
    expect(PaymentServiceWeb.isRazorpayAvailable(), isTrue);
    stub.remove();
    expect(PaymentServiceWeb.hasProperty('Razorpay'), isFalse);
    stub.install();
  });

  test('throws when Razorpay is not on the page', () async {
    stub.remove();
    await expectLater(open(), throwsA(isA<Exception>()));
    stub.install();
  });

  test('passes checkout options across the JS boundary and opens', () async {
    await open();

    final options = stub.options as Map;
    expect(options['key'], 'rzp_test_key');
    expect(options['amount'], 4900);
    expect(options['currency'], 'INR');
    expect(options['order_id'], 'order_ABC123');
    expect(stub.openCount, 1);
  });

  test('success handler delivers the payment response as a Dart map', () async {
    Map<String, dynamic>? received;
    await open(onSuccess: (r) => received = r);

    stub.succeed({
      'razorpay_payment_id': 'pay_123',
      'razorpay_order_id': 'order_ABC123',
      'razorpay_signature': 'sig_xyz',
    });

    expect(received, isNotNull);
    expect(received!['razorpay_payment_id'], 'pay_123');
    expect(received!['razorpay_order_id'], 'order_ABC123');
    expect(received!['razorpay_signature'], 'sig_xyz');
  });

  test('ondismiss survives Razorpay passing an argument', () async {
    var dismissed = false;
    await open(onDismiss: () => dismissed = true);

    // Regression guard: Razorpay calls ondismiss with one argument. A Dart
    // callback that accepts none throws "too many positional arguments".
    stub.dismiss();

    expect(dismissed, isTrue);
  });

  test('payment.failed delivers the error object, not a dismissal', () async {
    Map<String, dynamic>? error;
    var dismissed = false;
    await open(
      onDismiss: () => dismissed = true,
      onFailed: (e) => error = e,
    );

    stub.failPayment({
      'error': {
        'code': 'BAD_REQUEST_ERROR',
        'description': 'Card declined by issuing bank',
      },
    });

    expect(dismissed, isFalse, reason: 'hard decline must not report cancel');
    expect(error!['code'], 'BAD_REQUEST_ERROR');
    expect(error!['description'], 'Card declined by issuing bank');
  });

  test('payment.failed without an error object yields an empty map', () async {
    Map<String, dynamic>? error;
    await open(onFailed: (e) => error = e);

    stub.failPayment({'something_else': true});

    expect(error, isEmpty);
  });
}
