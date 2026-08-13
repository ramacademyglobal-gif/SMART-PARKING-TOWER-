import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/extensions.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/shell_back_button.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final name = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : 'Member';
    final initials = name.initials.isEmpty ? 'M' : name.initials;

    return Scaffold(
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          PremiumCard(
            gradient: AppColors.tealGradient,
            border: Border.all(color: Colors.transparent),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.peach,
                  child: Text(
                    initials,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user == null
                            ? '—'
                            : Formatters.maskedPhone(user.phone),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.peachSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user == null
                            ? ''
                            : 'Member since ${Formatters.date(user.memberSince)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMutedDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _LinkTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => context.push(AppRoutes.settings),
          ),
          _LinkTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription',
            onTap: () => context.push(AppRoutes.subscription),
          ),
          _LinkTile(
            icon: Icons.support_agent_rounded,
            label: 'Support',
            onTap: () => context.push(AppRoutes.support),
          ),
          const SizedBox(height: 28),
          PremiumButton.secondary(
            label: 'LOG OUT',
            icon: Icons.logout_rounded,
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.tealDeep),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
