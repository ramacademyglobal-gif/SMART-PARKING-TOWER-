import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:multiparking_tower/core/constants/app_constants.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/features/payment/presentation/providers/web_razorpay.dart';
import 'package:multiparking_tower/features/qr/presentation/providers/qr_provider.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/providers/public_config_provider.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// Hourly booking: pay non-refundable fee → slot allotted + QR issued.
Future<QrCodeModel?> showBookingFeeCheckout(BuildContext context) {
  return showModalBottomSheet<QrCodeModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _BookingFeeSheet(),
  );
}

enum _Stage { idle, processing, failed }

class _BookingFeeSheet extends ConsumerStatefulWidget {
  const _BookingFeeSheet();

  @override
  ConsumerState<_BookingFeeSheet> createState() => _BookingFeeSheetState();
}

class _BookingFeeSheetState extends ConsumerState<_BookingFeeSheet> {
  _Stage _stage = _Stage.idle;
  String? _error;
  Razorpay? _razorpay;
  String? _orderId;

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  int get _feePaise {
    final config = ref.read(publicApiConfigProvider).valueOrNull;
    if (config != null && config.bookingFeePaise > 0) {
      return config.bookingFeePaise;
    }
    return 5000;
  }

  Future<void> _pay() async {
    if (_stage == _Stage.processing) return;
    setState(() {
      _stage = _Stage.processing;
      _error = null;
    });

    final Map<String, dynamic> order;
    try {
      order = await ref.read(parkingRepositoryProvider).createBookingFeeOrder();
    } catch (error) {
      _fail(describeError(error,
          fallback: 'Could not start booking payment. Please try again.'));
      return;
    }

    final orderId = order['orderId']?.toString();
    final amountInPaise = (order['amount'] as num?)?.toInt() ?? _feePaise;
    final currency = order['currency']?.toString() ?? AppConstants.currencyCode;
    final gatewayKey = order['key']?.toString();

    if (orderId == null || orderId.isEmpty) {
      _fail('The payment order was rejected. Please try again.');
      return;
    }
    _orderId = orderId;

    final appConfig = ref.read(appConfigProvider);
    var gatewayKeyResolved = gatewayKey?.isNotEmpty == true
        ? gatewayKey!
        : appConfig.razorpayKeyId;
    if (gatewayKeyResolved.isEmpty ||
        gatewayKeyResolved == 'rzp_test_placeholder') {
      try {
        final bootstrap = await ref.read(publicApiConfigProvider.future);
        if (bootstrap.razorpayKeyId.isNotEmpty) {
          gatewayKeyResolved = bootstrap.razorpayKeyId;
        }
      } catch (_) {}
    }

    if (appConfig.isDemo) {
      await _verify(
        orderId: orderId,
        paymentId: 'pay_demo_booking',
        signature: 'sig_demo_booking',
      );
      return;
    }

    if (kIsWeb) {
      try {
        openWebRazorpay(
          options: <String, dynamic>{
            'key': gatewayKeyResolved,
            'amount': amountInPaise,
            'currency': currency,
            'name': AppConstants.appName,
            'description': 'Non-refundable booking fee',
            'order_id': orderId,
            'theme': <String, dynamic>{'color': '#2C4A56'},
          },
          onSuccess: (payload) {
            final oid = payload['razorpay_order_id']?.toString() ?? orderId;
            final pid = payload['razorpay_payment_id']?.toString();
            final sig = payload['razorpay_signature']?.toString();
            if (pid == null || sig == null) {
              _fail('Incomplete payment response.');
              return;
            }
            _verify(orderId: oid, paymentId: pid, signature: sig);
          },
          onFailure: (payload) {
            _fail(
              payload['description']?.toString() ??
                  'The payment could not be completed. Please try again.',
            );
          },
        );
      } catch (error) {
        _fail(describeError(error,
            fallback: 'The Razorpay checkout could not be opened.'));
      }
      return;
    }

    _openGateway(
      orderId: orderId,
      amountInPaise: amountInPaise,
      currency: currency,
      gatewayKey: gatewayKeyResolved,
    );
  }

  void _openGateway({
    required String orderId,
    required int amountInPaise,
    required String currency,
    required String gatewayKey,
  }) {
    try {
      _razorpay?.clear();
      final razorpay = Razorpay();
      _razorpay = razorpay;
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onCheckoutSuccess);
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onCheckoutError);
      razorpay.open(<String, dynamic>{
        'key': gatewayKey,
        'order_id': orderId,
        'amount': amountInPaise,
        'currency': currency,
        'name': AppConstants.appName,
        'description': 'Non-refundable booking fee',
        'timeout': 300,
        'theme': <String, dynamic>{'color': '#2C4A56'},
      });
    } catch (error) {
      _fail(describeError(error,
          fallback: 'The payment gateway could not be opened.'));
    }
  }

  void _onCheckoutSuccess(PaymentSuccessResponse response) {
    final orderId = response.orderId ?? _orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (orderId == null || paymentId == null || signature == null) {
      _fail('Incomplete payment response. If you were charged, '
          'the booking will be reconciled automatically.');
      return;
    }
    _verify(orderId: orderId, paymentId: paymentId, signature: signature);
  }

  void _onCheckoutError(PaymentFailureResponse response) {
    _razorpay?.clear();
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _fail('Payment cancelled. No booking fee was charged.');
      return;
    }
    _fail(response.message?.trim().isNotEmpty == true
        ? response.message!
        : 'The payment could not be completed. Please try again.');
  }

  Future<void> _verify({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final qr = await ref.read(parkingRepositoryProvider).verifyBookingFeePayment(
            orderId: orderId,
            paymentId: paymentId,
            signature: signature,
          );
      _razorpay?.clear();
      await ref.read(qrControllerProvider.notifier).load();
      if (!mounted) return;
      Navigator.of(context).pop(qr);
    } catch (error) {
      _fail(describeError(error,
          fallback:
              'Payment could not be verified. If you were charged, contact support — '
              'booking fees are non-refundable once confirmed.'));
    }
  }

  void _fail(String message) {
    _razorpay?.clear();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feeRupees = _feePaise / 100.0;
    final processing = _stage == _Stage.processing;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Book a parking bay',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Non-refundable booking fee of ${Formatters.currency(feeRupees, decimals: false)}. '
              'Adjusted against final exit charge. No refund on cancel or unused pass.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.tealDeep.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.tealDeep.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Booking fee',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.currency(feeRupees, decimals: false),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 22),
            PremiumButton(
              label: processing ? 'Processing…' : 'Pay booking fee',
              icon: Icons.lock_outline_rounded,
              onPressed: processing ? null : _pay,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: processing ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
