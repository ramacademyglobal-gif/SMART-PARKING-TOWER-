import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/constants/app_constants.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/extensions.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          PremiumCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  secondary: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: AppColors.tealDeep,
                  ),
                  title: const Text('Dark mode'),
                  subtitle: Text(
                    themeMode == ThemeMode.system
                        ? 'Following system'
                        : (isDark ? 'On' : 'Off'),
                  ),
                  value: themeMode == ThemeMode.dark ||
                      (themeMode == ThemeMode.system && isDark),
                  onChanged: (enabled) {
                    ref.read(themeModeProvider.notifier).setThemeMode(
                          enabled ? ThemeMode.dark : ThemeMode.light,
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  secondary: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.tealDeep,
                  ),
                  title: const Text('Push notifications'),
                  subtitle: Text(
                    notificationsEnabled
                        ? 'Parking and plan alerts on'
                        : 'Alerts paused',
                  ),
                  value: notificationsEnabled,
                  onChanged: (enabled) => ref
                      .read(notificationsEnabledProvider.notifier)
                      .setEnabled(enabled),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.language_rounded,
                    color: AppColors.tealDeep,
                  ),
                  title: const Text('Language'),
                  subtitle: Text(_languageLabel(language)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showLanguageSheet(context, ref, language),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PremiumCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.tealDeep,
                  ),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showInfoDialog(
                    context,
                    title: 'Privacy Policy',
                    body:
                        'MultiParking Tower collects only the account, vehicle '
                        'and parking data needed to operate your subscription. '
                        'In demo mode, all data stays on this device.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: AppColors.tealDeep,
                  ),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showInfoDialog(
                    context,
                    title: 'Terms of Service',
                    body:
                        'By using MultiParking Tower you agree to park only in '
                        'your assigned slot, keep your access QR secure, and '
                        'follow tower safety rules. Demo builds do not control '
                        'live gates.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.tealDeep,
                  ),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: '1.0.0',
                    applicationIcon: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_parking_rounded,
                        color: AppColors.tealDark,
                      ),
                    ),
                    children: const [
                      SizedBox(height: 12),
                      Text(
                        'Premium multi-level parking for monthly and annual '
                        'subscribers. Secure QR entry, assigned slots, and '
                        'parking history in one place.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _languageLabel(String code) {
    return switch (code) {
      'hi' => 'हिन्दी (coming soon)',
      'en' => 'English',
      _ => code,
    };
  }

  Future<void> _showLanguageSheet(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                trailing: current == 'en'
                    ? const Icon(Icons.check_rounded, color: AppColors.tealDeep)
                    : null,
                onTap: () {
                  ref.read(languageProvider.notifier).setLanguage('en');
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                title: const Text('हिन्दी'),
                subtitle: const Text('Placeholder — localization coming soon'),
                trailing: current == 'hi'
                    ? const Icon(Icons.check_rounded, color: AppColors.tealDeep)
                    : null,
                onTap: () {
                  ref.read(languageProvider.notifier).setLanguage('hi');
                  Navigator.pop(sheetContext);
                  context.showSnack('Hindi localization is coming soon.');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
