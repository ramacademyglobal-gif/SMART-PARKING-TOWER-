import 'dart:convert';
import 'dart:js_interop';

typedef WebRazorpayCallback = void Function(Map<String, dynamic> payload);

@JS('openMultiParkingRazorpay')
external void _openMultiParkingRazorpay(
  JSString optionsJson,
  JSFunction onSuccess,
  JSFunction onFailure,
);

void openWebRazorpay({
  required Map<String, dynamic> options,
  required WebRazorpayCallback onSuccess,
  required WebRazorpayCallback onFailure,
}) {
  void success(JSString value) {
    onSuccess(_decode(value.toDart));
  }

  void failure(JSString value) {
    onFailure(_decode(value.toDart));
  }

  _openMultiParkingRazorpay(
    jsonEncode(options).toJS,
    success.toJS,
    failure.toJS,
  );
}

Map<String, dynamic> _decode(String value) {
  final decoded = jsonDecode(value);
  return decoded is Map
      ? Map<String, dynamic>.from(decoded)
      : <String, dynamic>{'message': value};
}
