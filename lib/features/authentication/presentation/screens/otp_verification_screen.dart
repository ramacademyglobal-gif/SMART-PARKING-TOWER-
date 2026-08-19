import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/validators.dart';
import 'package:multiparking_tower/core/widgets/gradient_background.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, this.phone});

  final String? phone;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  Timer? _timer;
  int _secondsRemaining = 30;
  String? _localError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNode.requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setStateIfMounted(() => _secondsRemaining = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void setStateIfMounted(VoidCallback callback) {
    if (mounted) setState(callback);
  }

  Future<void> _verify() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    final validation = Validators.otp(_otpController.text);
    if (validation != null) {
      setState(() => _localError = validation);
      return;
    }
    setState(() => _localError = null);
    _isSubmitting = true;
    try {
      await ref
          .read(authProvider.notifier)
          .verifyOtp(_otpController.text.trim());
    } finally {
      // A successful verification redirects and disposes this screen.
      if (mounted) _isSubmitting = false;
    }
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0) return;
    final phone = widget.phone ?? ref.read(authProvider).phone;
    if (phone == null) {
      context.go(AppRoutes.login);
      return;
    }
    final sent = await ref.read(authProvider.notifier).sendOtp(phone);
    if (sent && mounted) {
      _otpController.clear();
      setState(() => _localError = null);
      _startTimer();
      _otpFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final phone = widget.phone ?? auth.phone ?? '';
    final isLoading = auth.status == AuthStatus.loading || _isSubmitting;
    final error = _localError ?? auth.errorMessage;

    return GradientBackground(
      useScaffold: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.white,
                      backgroundColor:
                          AppColors.white.withValues(alpha: .1),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.06),
                  Text(
                    'Verify your number',
                    style:
                        Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.8,
                            ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter the 6-digit OTP sent to +91 ${_formatPhone(phone)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMutedDark,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _otpFocusNode.requestFocus,
                          child: Stack(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) {
                                  final digit =
                                      index < _otpController.text.length
                                          ? _otpController.text[index]
                                          : '';
                                  final isActive =
                                      index == _otpController.text.length;
                                  return AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 160),
                                    width: 43,
                                    height: 56,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.creamSurface,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: Border.all(
                                        color: error != null
                                            ? AppColors.error
                                            : isActive
                                                ? AppColors.peachDeep
                                                : AppColors.divider,
                                        width: isActive ? 1.8 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      digit,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  );
                                }),
                              ),
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0,
                                  child: TextField(
                                    controller: _otpController,
                                    focusNode: _otpFocusNode,
                                    autofocus: true,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    onChanged: (value) {
                                      setState(() => _localError = null);
                                      if (value.length == 6) _verify();
                                    },
                                    onSubmitted: (_) => _verify(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        PremiumButton(
                          label: 'VERIFY & CONTINUE',
                          icon: Icons.verified_user_outlined,
                          isLoading: isLoading,
                          onPressed: _verify,
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed:
                              _secondsRemaining == 0 ? _resend : null,
                          child: Text(
                            _secondsRemaining == 0
                                ? 'Resend OTP'
                                : 'Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppColors.tealDeep,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.center,
                    child: Builder(
                      builder: (context) {
                        final isDemo = ref.watch(appConfigProvider).isDemo;
                        return Text(
                          isDemo
                              ? 'Dev mode: use OTP 123456'
                              : 'OTP sent via Firebase SMS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.peach,
                                fontWeight: FontWeight.w600,
                              ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.viewInsetsOf(context).bottom > 0
                        ? 24
                        : 48,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatPhone(String phone) {
    final digits = Validators.normalizePhone(phone);
    if (digits.length != 10) return digits;
    return '${digits.substring(0, 5)} ${digits.substring(5)}';
  }
}
