typedef WebRazorpayCallback = void Function(Map<String, dynamic> payload);

void openWebRazorpay({
  required Map<String, dynamic> options,
  required WebRazorpayCallback onSuccess,
  required WebRazorpayCallback onFailure,
}) {
  throw UnsupportedError('Razorpay web checkout is only available in a browser.');
}
