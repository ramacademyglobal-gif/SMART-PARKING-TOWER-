import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:multiparking_tower/core/constants/app_constants.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:multiparking_tower/features/payment/presentation/providers/web_razorpay.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/providers/public_config_provider.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// Stages of the checkout flow, in the order they occur.
enum PaymentFlowStatus {
  idle,
  creatingOrder,
  awaitingCheckout,
  verifying,
  success,
  failed,
  cancelled;

  bool get isBusy =>
      this == creatingOrder || this == awaitingCheckout || this == verifying;

  bool get isFinished =>
      this == success || this == failed || this == cancelled;
}

class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentFlowStatus.idle,
    this.planType,
    this.orderId,
    this.paymentId,
    this.amountInPaise,
    this.currency = AppConstants.currencyCode,
    this.subscription,
    this.errorMessage,
    this.notice,
  });

  final PaymentFlowStatus status;
  final SubscriptionPlanType? planType;
  final String? orderId;
  final String? paymentId;
  final int? amountInPaise;
  final String currency;

  /// Only ever set from the server's verification response — a client-side
  /// success callback alone never activates a subscription.
  final SubscriptionModel? subscription;
  final String? errorMessage;

  /// Non-fatal progress information, e.g. an external wallet handover.
  final String? notice;

  double? get amountInRupees =>
      amountInPaise == null ? null : amountInPaise! / 100.0;

  bool get canRetry => planType != null && !status.isBusy;

  PaymentState copyWith({
    PaymentFlowStatus? status,
    SubscriptionPlanType? planType,
    String? orderId,
    String? paymentId,
    int? amountInPaise,
    String? currency,
    SubscriptionModel? subscription,
    String? errorMessage,
    String? notice,
    bool clearErrorMessage = false,
    bool clearNotice = false,
  }) {
    return PaymentState(
      status: status ?? this.status,
      planType: planType ?? this.planType,
      orderId: orderId ?? this.orderId,
      paymentId: paymentId ?? this.paymentId,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      currency: currency ?? this.currency,
      subscription: subscription ?? this.subscription,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  @override
  List<Object?> get props => [
        status,
        planType,
        orderId,
        paymentId,
        amountInPaise,
        currency,
        subscription,
        errorMessage,
        notice,
      ];
}

/// Drives the subscription checkout: order creation, gateway checkout and
/// server-side verification.
///
/// In demo mode the native Razorpay SDK is never touched — checkout is
/// simulated locally and handed to [PaymentRepository.verifyPayment] with demo
/// identifiers, so the flow can be exercised on any platform.
class PaymentController extends Notifier<PaymentState> {
  Razorpay? _razorpay;

  static const Duration _demoCheckoutDelay = Duration(milliseconds: 1600);

  @override
  PaymentState build() {
    ref.onDispose(_releaseGateway);
    return const PaymentState();
  }

  Future<void> startPayment(SubscriptionPlanType planType) async {
    if (state.status.isBusy) return;

    state = PaymentState(
      status: PaymentFlowStatus.creatingOrder,
      planType: planType,
    );

    final Map<String, dynamic> order;
    try {
      order = await ref.read(paymentRepositoryProvider).createOrder(planType);
    } catch (error) {
      _fail(describeError(
        error,
        fallback: 'We could not start this payment. Please try again.',
      ));
      return;
    }

    final orderId = order['orderId']?.toString();
    final amountInPaise = (order['amount'] as num?)?.toInt();
    final currency =
        order['currency']?.toString() ?? AppConstants.currencyCode;
    final gatewayKey = order['key']?.toString();

    if (orderId == null || orderId.isEmpty || amountInPaise == null) {
      _fail('The payment order was rejected. Please try again.');
      return;
    }

    state = state.copyWith(
      status: PaymentFlowStatus.awaitingCheckout,
      orderId: orderId,
      amountInPaise: amountInPaise,
      currency: currency,
    );

    if (ref.read(appConfigProvider).isDemo) {
      await _runDemoCheckout(orderId);
      return;
    }

    await _openGatewayCheckout(
      orderId: orderId,
      amountInPaise: amountInPaise,
      currency: currency,
      gatewayKey: gatewayKey?.isNotEmpty == true
          ? gatewayKey!
          : await _resolvedRazorpayKey(),
      planType: planType,
    );
  }

  Future<String> _resolvedRazorpayKey() async {
    final fromDefine = ref.read(appConfigProvider).razorpayKeyId;
    if (fromDefine.isNotEmpty && fromDefine != 'rzp_test_placeholder') {
      return fromDefine;
    }
    try {
      final bootstrap = await ref.read(publicApiConfigProvider.future);
      if (bootstrap.razorpayKeyId.isNotEmpty) return bootstrap.razorpayKeyId;
    } catch (_) {}
    return fromDefine;
  }

  /// Restarts checkout for the plan that was last attempted.
  Future<void> retry() async {
    final planType = state.planType;
    if (planType == null || state.status.isBusy) return;
    await startPayment(planType);
  }

  void reset() {
    _releaseGateway();
    state = const PaymentState();
  }

  // ---------------------------------------------------------------------------
  // Demo checkout
  // ---------------------------------------------------------------------------

  Future<void> _runDemoCheckout(String orderId) async {
    await Future<void>.delayed(_demoCheckoutDelay);
    if (state.status != PaymentFlowStatus.awaitingCheckout) return;
    final suffix = DateTime.now().millisecondsSinceEpoch;
    await _verify(
      orderId: orderId,
      paymentId: 'pay_demo_$suffix',
      signature: 'sig_demo_$suffix',
    );
  }

  // ---------------------------------------------------------------------------
  // Razorpay checkout
  // ---------------------------------------------------------------------------

  Future<void> _openGatewayCheckout({
    required String orderId,
    required int amountInPaise,
    required String currency,
    required String gatewayKey,
    required SubscriptionPlanType planType,
  }) async {
    final prefill = await _prefill();

    if (kIsWeb) {
      _openWebGatewayCheckout(
        orderId: orderId,
        amountInPaise: amountInPaise,
        currency: currency,
        gatewayKey: gatewayKey,
        planType: planType,
        prefill: prefill,
      );
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      _fail('Payments are only available on the Android and iOS apps.');
      return;
    }

    try {
      _releaseGateway();
      final razorpay = Razorpay();
      _razorpay = razorpay;
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onCheckoutSuccess);
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onCheckoutError);
      razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

      razorpay.open(<String, dynamic>{
        'key': gatewayKey,
        'order_id': orderId,
        'amount': amountInPaise,
        'currency': currency,
        'name': AppConstants.appName,
        'description': _planDescription(planType),
        'timeout': 300,
        'prefill': prefill,
        'theme': <String, dynamic>{'color': '#2C4A56'},
        'retry': <String, dynamic>{'enabled': true, 'max_count': 1},
      });
    } catch (error) {
      _fail(describeError(
        error,
        fallback: 'The payment gateway could not be opened.',
      ));
    }
  }

  void _openWebGatewayCheckout({
    required String orderId,
    required int amountInPaise,
    required String currency,
    required String gatewayKey,
    required SubscriptionPlanType planType,
    required Map<String, dynamic> prefill,
  }) {
    try {
      openWebRazorpay(
        options: <String, dynamic>{
          'key': gatewayKey,
          'order_id': orderId,
          'amount': amountInPaise,
          'currency': currency,
          'name': AppConstants.appName,
          'description': _planDescription(planType),
          'timeout': 300,
          'prefill': prefill,
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
            state = state.copyWith(
              status: PaymentFlowStatus.cancelled,
              errorMessage: 'You cancelled the payment before it completed.',
              clearNotice: true,
            );
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

  void _onCheckoutSuccess(PaymentSuccessResponse response) {
    final orderId = response.orderId ?? state.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
      _fail(
        'The gateway returned an incomplete response. If you were charged, '
        'the payment will be reconciled automatically.',
      );
      return;
    }

    _verify(orderId: orderId, paymentId: paymentId, signature: signature);
  }

  void _onCheckoutError(PaymentFailureResponse response) {
    _releaseGateway();
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      state = state.copyWith(
        status: PaymentFlowStatus.cancelled,
        errorMessage: 'You cancelled the payment before it completed.',
        clearNotice: true,
      );
      return;
    }
    _fail(response.message?.trim().isNotEmpty == true
        ? response.message!
        : 'The payment could not be completed. Please try again.');
  }

  /// The user handed off to an external wallet; the outcome still arrives
  /// through the success/error callbacks, so the flow stays in progress.
  void _onExternalWallet(ExternalWalletResponse response) {
    final wallet = response.walletName;
    state = state.copyWith(
      status: PaymentFlowStatus.awaitingCheckout,
      notice: wallet == null
          ? 'Finish the payment in your wallet app.'
          : 'Finish the payment in $wallet.',
    );
  }

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  /// The only path that can mark a payment successful: the backend validates
  /// the Razorpay signature and returns the activated subscription.
  Future<void> _verify({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    state = state.copyWith(
      status: PaymentFlowStatus.verifying,
      orderId: orderId,
      paymentId: paymentId,
      clearErrorMessage: true,
      clearNotice: true,
    );

    try {
      final subscription =
          await ref.read(paymentRepositoryProvider).verifyPayment(
                orderId: orderId,
                paymentId: paymentId,
                signature: signature,
              );
      _releaseGateway();
      state = state.copyWith(
        status: PaymentFlowStatus.success,
        subscription: subscription,
        clearErrorMessage: true,
        clearNotice: true,
      );
      ref.invalidate(currentSubscriptionProvider);
      ref.invalidate(paymentHistoryProvider);
    } catch (error) {
      _fail(describeError(
        error,
        fallback: 'We could not verify this payment. If you were charged, the '
            'amount will be refunded or reconciled automatically.',
      ));
    }
  }

  Future<Map<String, dynamic>> _prefill() async {
    try {
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      if (user == null) return const <String, dynamic>{};
      return <String, dynamic>{
        'name': user.displayName,
        'contact': '${AppConstants.defaultCountryCode}${user.phone}',
      };
    } catch (_) {
      // Prefill is a convenience only; checkout still works without it.
      return const <String, dynamic>{};
    }
  }

  String _planDescription(SubscriptionPlanType planType) {
    final plan = ref.read(planByTypeProvider(planType));
    if (plan != null) return plan.name;
    return switch (planType) {
      SubscriptionPlanType.monthly => 'Monthly parking subscription',
      SubscriptionPlanType.annual => 'Annual parking subscription',
      SubscriptionPlanType.hourly => 'Hourly parking',
    };
  }

  void _fail(String message) {
    _releaseGateway();
    state = state.copyWith(
      status: PaymentFlowStatus.failed,
      errorMessage: message,
      clearNotice: true,
    );
  }

  void _releaseGateway() {
    _razorpay?.clear();
    _razorpay = null;
  }
}

final paymentControllerProvider =
    NotifierProvider<PaymentController, PaymentState>(PaymentController.new);
