import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:multiparking_tower/core/constants/app_constants.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/utils/parking_tariff.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/features/payment/presentation/providers/web_razorpay.dart';
import 'package:multiparking_tower/features/parking/presentation/providers/parking_provider.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/providers/public_config_provider.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// Exit receipt: vehicle, duration, and the hourly charge (or plan-covered).
/// For pay-as-you-go sessions the user can settle the bill via Razorpay here.
Future<void> showParkingExitReceipt(
  BuildContext context, {
  required ParkingHistoryModel session,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: !session.needsPayment,
    enableDrag: !session.needsPayment,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _ExitReceiptSheet(session: session),
  );
}

enum _PayStage { idle, processing, paid, failed }

class _ExitReceiptSheet extends ConsumerStatefulWidget {
  const _ExitReceiptSheet({required this.session});

  final ParkingHistoryModel session;

  @override
  ConsumerState<_ExitReceiptSheet> createState() => _ExitReceiptSheetState();
}

class _ExitReceiptSheetState extends ConsumerState<_ExitReceiptSheet> {
  late ParkingHistoryModel _session;
  _PayStage _stage = _PayStage.idle;
  String? _error;
  Razorpay? _razorpay;
  String? _orderId;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  bool get _isHourly => _session.isHourly && (_session.amountInPaise ?? 0) > 0;

  bool get _needsPayment => _session.needsPayment;

  int get _amount => _session.amountInPaise ?? 0;

  // ---------------------------------------------------------------------------
  // Payment
  // ---------------------------------------------------------------------------

  Future<void> _pay() async {
    if (_stage == _PayStage.processing) return;
    setState(() {
      _stage = _PayStage.processing;
      _error = null;
    });

    final Map<String, dynamic> order;
    try {
      order = await ref
          .read(parkingRepositoryProvider)
          .createParkingOrder(_session.id);
    } catch (error) {
      _fail(describeError(error,
          fallback: 'We could not start this payment. Please try again.'));
      return;
    }

    final orderId = order['orderId']?.toString();
    final amountInPaise = (order['amount'] as num?)?.toInt() ?? _amount;
    final currency = order['currency']?.toString() ?? AppConstants.currencyCode;
    final gatewayKey = order['key']?.toString();

    if (orderId == null || orderId.isEmpty) {
      _fail('The payment order was rejected. Please try again.');
      return;
    }
    _orderId = orderId;

    final config = ref.read(appConfigProvider);
    var gatewayKeyResolved = gatewayKey?.isNotEmpty == true
        ? gatewayKey!
        : config.razorpayKeyId;
    if (gatewayKeyResolved.isEmpty ||
        gatewayKeyResolved == 'rzp_test_placeholder') {
      try {
        final bootstrap = await ref.read(publicApiConfigProvider.future);
        if (bootstrap.razorpayKeyId.isNotEmpty) {
          gatewayKeyResolved = bootstrap.razorpayKeyId;
        }
      } catch (_) {}
    }

    if (config.isDemo) {
      // Offline demo mode never contacts Razorpay or the real API.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final suffix = DateTime.now().millisecondsSinceEpoch;
      await _verify(
        orderId: orderId,
        paymentId: 'pay_demo_$suffix',
        signature: 'sig_demo_$suffix',
      );
      return;
    }

    if (kIsWeb) {
      _openWebGateway(
        orderId: orderId,
        amountInPaise: amountInPaise,
        currency: currency,
        gatewayKey: gatewayKeyResolved,
      );
      return;
    }

    final canUseNativeGateway =
        defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS;
    if (!canUseNativeGateway) {
      _fail('Razorpay checkout is available on Chrome, Android, and iOS.');
      return;
    }

    _openGateway(
      orderId: orderId,
      amountInPaise: amountInPaise,
      currency: currency,
      gatewayKey: gatewayKeyResolved,
    );
  }

  void _openWebGateway({
    required String orderId,
    required int amountInPaise,
    required String currency,
    required String gatewayKey,
  }) {
    try {
      openWebRazorpay(
        options: <String, dynamic>{
          'key': gatewayKey,
          'order_id': orderId,
          'amount': amountInPaise,
          'currency': currency,
          'name': AppConstants.appName,
          'description': 'Parking · ${_session.vehicleNumber}',
          'timeout': 300,
          'theme': <String, dynamic>{'color': '#2C4A56'},
          'retry': <String, dynamic>{'enabled': true, 'max_count': 1},
        },
        onSuccess: (response) {
          final returnedOrderId =
              response['razorpay_order_id']?.toString() ?? orderId;
          final paymentId = response['razorpay_payment_id']?.toString();
          final signature = response['razorpay_signature']?.toString();
          if (paymentId == null || signature == null) {
            _fail('Razorpay returned an incomplete payment response.');
            return;
          }
          _verify(
            orderId: returnedOrderId,
            paymentId: paymentId,
            signature: signature,
          );
        },
        onFailure: (response) {
          if (response['cancelled'] == true) {
            _fail('You cancelled the payment before it completed.');
            return;
          }
          _fail(
            response['description']?.toString() ??
                response['message']?.toString() ??
                'The payment could not be completed. Please try again.',
          );
        },
      );
    } catch (error) {
      _fail(describeError(
        error,
        fallback: 'The Razorpay checkout could not be opened.',
      ));
    }
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
        'description': 'Parking · ${_session.vehicleNumber}',
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
      _fail('The gateway returned an incomplete response. If you were charged, '
          'the payment will be reconciled automatically.');
      return;
    }
    _verify(orderId: orderId, paymentId: paymentId, signature: signature);
  }

  void _onCheckoutError(PaymentFailureResponse response) {
    _razorpay?.clear();
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _fail('You cancelled the payment before it completed.');
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
      final updated =
          await ref.read(parkingRepositoryProvider).verifyParkingPayment(
                historyId: _session.id,
                orderId: orderId,
                paymentId: paymentId,
                signature: signature,
              );
      _razorpay?.clear();
      if (!mounted) return;
      setState(() {
        _session = updated;
        _stage = _PayStage.paid;
        _error = null;
      });
      ref.invalidate(parkingHistoryProvider);
      ref.invalidate(currentSlotProvider);
    } catch (error) {
      _fail(describeError(error,
          fallback: 'We could not verify this payment. If you were charged, '
              'the amount will be refunded or reconciled automatically.'));
    }
  }

  void _fail(String message) {
    _razorpay?.clear();
    if (!mounted) return;
    setState(() {
      _stage = _PayStage.failed;
      _error = message;
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = _session.duration ?? Duration.zero;
    final paid = _session.isPaid;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            paid ? Icons.verified_rounded : Icons.check_circle_rounded,
            size: 56,
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          Text(
            paid ? 'Payment successful' : 'Vehicle retrieved',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            paid
                ? 'Your parking fee has been paid. Drive safe!'
                : (_isHourly
                    ? 'Pay-as-you-go at ₹${ParkingTariff.hourlyRateRupees.toStringAsFixed(0)}/hour'
                    : 'Covered by your subscription'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _ReceiptRow(label: 'Vehicle', value: _session.vehicleNumber),
          _ReceiptRow(label: 'Slot', value: _session.slotLabel),
          _ReceiptRow(
            label: 'Entry',
            value: Formatters.dateTime(_session.entryAt),
          ),
          if (_session.exitAt != null)
            _ReceiptRow(
              label: 'Exit',
              value: Formatters.dateTime(_session.exitAt!),
            ),
          _ReceiptRow(
            label: 'Duration',
            value: Formatters.duration(duration),
          ),
          const Divider(height: 28),
          if (_isHourly &&
              _session.bookingFeePaid &&
              _session.bookingFeePaise > 0) ...[
            _ReceiptRow(
              label: 'Parking charge',
              value: Formatters.currency(
                (_session.grossAmountInPaise ?? _amount) / 100,
                decimals: false,
              ),
            ),
            _ReceiptRow(
              label: 'Booking fee credit',
              value:
                  '− ${Formatters.currency(_session.bookingFeeRupees, decimals: false)}',
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text(
                _isHourly
                    ? (paid
                        ? 'Amount paid'
                        : (_session.coveredByBookingFee
                            ? 'Amount due'
                            : 'Amount due'))
                    : 'Charge',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _isHourly
                    ? (_session.coveredByBookingFee && !paid
                        ? '₹0 · Covered by booking fee'
                        : Formatters.currency(_amount / 100, decimals: false))
                    : '₹0',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.peachDeep,
                ),
              ),
            ],
          ),
          if (_session.coveredByBookingFee && !paid) ...[
            const SizedBox(height: 8),
            Text(
              'No further payment due. Booking fee is non-refundable.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildAction(),
        ],
      ),
    );
  }

  Widget _buildAction() {
    // Plan-covered or already-paid sessions just close.
    if (!_needsPayment || _session.isPaid) {
      return PremiumButton(
        label: 'DONE',
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    final processing = _stage == _PayStage.processing;
    return PremiumButton(
      label: processing
          ? 'PROCESSING…'
          : 'PAY ${Formatters.currency(_amount / 100, decimals: false)}',
      icon: processing ? null : Icons.lock_rounded,
      isLoading: processing,
      onPressed: processing ? null : _pay,
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
