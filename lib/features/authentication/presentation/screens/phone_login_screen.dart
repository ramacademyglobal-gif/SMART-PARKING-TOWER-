import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/validators.dart';
import 'package:multiparking_tower/core/widgets/app_text_field.dart';
import 'package:multiparking_tower/core/widgets/gradient_background.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = Validators.normalizePhone(_phoneController.text);
    final sent = await ref.read(authProvider.notifier).sendOtp(phone);
    if (sent && mounted) context.go(AppRoutes.otp, extra: phone);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final isDemo = ref.watch(appConfigProvider).isDemo;

    return GradientBackground(
      useScaffold: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => context.go(AppRoutes.splash),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.white,
                        backgroundColor:
                            AppColors.white.withValues(alpha: .1),
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.08),
                    Text(
                      'Welcome back',
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isDemo
                          ? 'Enter your mobile number. Demo OTP is 123456.'
                          : 'Enter your mobile number. We will send a Firebase OTP to sign in.',
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
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme:
                              Theme.of(context).colorScheme.copyWith(
                                    surface: AppColors.creamSurface,
                                    onSurface: AppColors.textDark,
                                    onSurfaceVariant: AppColors.textMuted,
                                    primary: AppColors.tealDeep,
                                  ),
                          inputDecorationTheme: AppTheme
                              .light.inputDecorationTheme
                              .copyWith(fillColor: AppColors.white),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MOBILE NUMBER',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.cream,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Text(
                                    '+91',
                                    style: TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppTextField(
                                    controller: _phoneController,
                                    hint: '98765 43210',
                                    autofocus: false,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: Validators.indianPhone,
                                    onSubmitted: (_) => _sendOtp(),
                                  ),
                                ),
                              ],
                            ),
                            if (auth.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                auth.errorMessage!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            PremiumButton(
                              label: 'SEND OTP',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: isLoading,
                              onPressed: _sendOtp,
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    context.go(AppRoutes.staffLogin),
                                child: const Text('Staff login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'By continuing, you agree to our Terms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMutedDark,
                            ),
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
            ),
          );
        },
      ),
    );
  }
}
