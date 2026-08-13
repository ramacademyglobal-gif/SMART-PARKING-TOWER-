import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multiparking_tower/core/constants/app_constants.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/validators.dart';
import 'package:multiparking_tower/core/widgets/app_text_field.dart';
import 'package:multiparking_tower/core/widgets/gradient_background.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/providers/settings_provider.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'staff');
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref.read(authProvider.notifier).staffLogin(
          _usernameController.text.trim(),
          _passwordController.text,
        );
    if (ok && mounted) context.go(AppRoutes.staffHome);
  }

  bool _isDark(ThemeMode themeMode) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Future<void> _toggleTheme() async {
    final themeMode = ref.read(themeModeProvider);
    final dark = _isDark(themeMode);
    await ref.read(themeModeProvider.notifier).setThemeMode(
          dark ? ThemeMode.light : ThemeMode.dark,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final isDark = _isDark(themeMode);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final cardColor = isDark ? AppColors.charcoalElevated : AppColors.white;
    final labelColor = isDark ? AppColors.textMutedDark : AppColors.textMuted;
    final hintMuted = isDark ? AppColors.textMutedDark : AppColors.textMuted;

    return GradientBackground(
      useScaffold: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        const Spacer(),
                        IconButton.filledTonal(
                          tooltip: isDark ? 'Light mode' : 'Dark mode',
                          onPressed: _toggleTheme,
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.white,
                            backgroundColor:
                                AppColors.white.withValues(alpha: .1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Brand header — logo + app name
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_parking_rounded,
                              color: AppColors.tealDark,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConstants.appName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Gate staff access',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.peachSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: constraints.maxHeight * 0.05),
                    Text(
                      'Staff console',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in with your gate credentials to scan passes and book walk-in vehicles.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textMutedDark,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? .35 : .2),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: theme.copyWith(
                          colorScheme: scheme.copyWith(
                            surface: isDark
                                ? AppColors.slate
                                : AppColors.creamSurface,
                            onSurface:
                                isDark ? AppColors.textOnDark : AppColors.textDark,
                            onSurfaceVariant: hintMuted,
                            primary: AppColors.tealDeep,
                          ),
                          inputDecorationTheme:
                              (isDark ? AppTheme.dark : AppTheme.light)
                                  .inputDecorationTheme
                                  .copyWith(fillColor: cardColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'USERNAME',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: labelColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AppTextField(
                              controller: _usernameController,
                              hint: 'staff',
                              textInputAction: TextInputAction.next,
                              validator: (value) => Validators.required(
                                value,
                                field: 'Username',
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'PASSWORD',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: labelColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AppTextField(
                              controller: _passwordController,
                              hint: '••••••••',
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              validator: (value) => Validators.required(
                                value,
                                field: 'Password',
                              ),
                              onSubmitted: (_) => _submit(),
                              suffixIcon: _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixTap: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            if (auth.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                auth.errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            PremiumButton(
                              label: 'SIGN IN',
                              icon: Icons.login_rounded,
                              isLoading: isLoading,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Default: staff / Parking@123',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: hintMuted,
                              ),
                            ),
                          ],
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
