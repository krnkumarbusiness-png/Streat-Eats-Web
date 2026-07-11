// lib/services/razorpay_web_checkout.dart
//
// Razorpay JS Checkout interop for Flutter Web.
//
// How it works:
//   1. web/index.html loads checkout.razorpay.com/v1/checkout.js
//   2. This file calls `new Razorpay({...}).open()` via dart:js_interop
//   3. Callbacks are wired back to Dart via JSFunction wrappers

// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

// -- Mock classes to prevent compile errors on web -----------------
// These mimic the types from package:razorpay_flutter

class PaymentSuccessResponse {
  final String? paymentId;
  final String? orderId;
  final String? signature;
  PaymentSuccessResponse(this.paymentId, this.orderId, this.signature);
}

class PaymentFailureResponse {
  final int? code;
  final String? message;
  PaymentFailureResponse(this.code, this.message);
}

class ExternalWalletResponse {
  final String? walletName;
  ExternalWalletResponse(this.walletName);
}

class Razorpay {
  static const int PAYMENT_CANCELLED = 0;
  static const int NETWORK_ERROR = 1;
  static const int INVALID_OPTIONS = 2;
  static const String EVENT_PAYMENT_SUCCESS = 'payment.success';
  static const String EVENT_PAYMENT_ERROR = 'payment.error';
  static const String EVENT_EXTERNAL_WALLET = 'payment.external_wallet';

  void on(String event, Function handler) {}
  void clear() {}
  void open(Map<String, dynamic> options) {
    debugPrint('Native Razorpay.open called on Web - this is a no-op.');
  }
}

// -- JS bindings --------------------------------------------------

@JS('Razorpay')
@staticInterop
class _JsRazorpay {
  external factory _JsRazorpay(JSObject options);
}

extension _JsRazorpayExt on _JsRazorpay {
  external void open();
}

// -- Public Dart API ----------------------------------------------

class RazorpayWebCheckout {
  static void open({
    required Map<String, dynamic> options,
    required void Function(String paymentId, String orderId, String signature) onSuccess,
    required void Function(int code, String message) onError,
  }) {
    final jsOptions = _buildJsOptions(options, onSuccess, onError);
    final rzp = _JsRazorpay(jsOptions);
    rzp.open();
  }

  static JSObject _buildJsOptions(
    Map<String, dynamic> options,
    void Function(String, String, String) onSuccess,
    void Function(int, String) onError,
  ) {
    final merged = <String, dynamic>{...options};

    merged['handler'] = ((JSObject response) {
      final paymentId = (response.getProperty('razorpay_payment_id'.toJS) as JSString?)?.toDart ?? '';
      final orderId = (response.getProperty('razorpay_order_id'.toJS) as JSString?)?.toDart ?? '';
      final signature = (response.getProperty('razorpay_signature'.toJS) as JSString?)?.toDart ?? '';
      onSuccess(paymentId, orderId, signature);
    }).toJS;

    merged['modal'] = <String, dynamic>{
      'ondismiss': (() {
        onError(0, 'Payment cancelled by user');
      }).toJS,
      'confirm_close': true,
      'animation': true,
    };

    return merged.jsify()! as JSObject;
  }
}
