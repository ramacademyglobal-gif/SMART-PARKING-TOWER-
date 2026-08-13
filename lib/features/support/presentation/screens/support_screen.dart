import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:multiparking_tower/core/constants/app_constants.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/extensions.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/section_header.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _faqs = <({String q, String a})>[
    (
      q: 'How do I enter the tower?',
      a: 'Open the QR tab and present your access pass at the gate scanner. '
          'Monthly plans should refresh the code if it has expired.',
    ),
    (
      q: 'Can I change my assigned slot?',
      a: 'Active plans get preferential premium bays (Zone A) for each visit — '
          'not a permanently reserved slot for the plan duration. Contact support '
          'if you need help with allocation.',
    ),
    (
      q: 'What happens when my plan expires?',
      a: 'Your QR stops working at expiry. Renew from Subscription to restore '
          'access. History and vehicles remain on your account.',
    ),
    (
      q: 'How many vehicles can I register?',
      a: 'Add multiple vehicles, then set a default for the QR pass. Only the '
          'vehicle linked on the pass should enter with that code.',
    ),
    (
      q: 'Is this a live gate integration?',
      a: 'This build includes demo helpers for entry/exit simulation. Live gate '
          'control requires a connected MultiParking backend.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          PremiumCard(
            gradient: AppColors.peachGradient,
            border: Border.all(color: AppColors.peachSoft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse common questions or reach the parking support desk.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.tealDeep,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionHeader(
            title: 'FAQs',
            subtitle: 'Quick answers for tower members',
          ),
          ..._faqs.map(
            (faq) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumCard(
                elevated: false,
                padding: EdgeInsets.zero,
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.peachSoft,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: AppColors.tealDeep,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      faq.q,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: [
                      Text(
                        faq.a,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader(
            title: 'Contact',
            subtitle: 'We typically reply within one business day',
          ),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.tealDeep,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        color: AppColors.peach,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email support',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppConstants.supportEmail,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                PremiumButton(
                  label: 'CONTACT SUPPORT',
                  icon: Icons.send_rounded,
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: AppConstants.supportEmail),
                    );
                    if (!context.mounted) return;
                    context.showSnack(
                      'Support email copied. In demo mode, open your mail app '
                      'and write to ${AppConstants.supportEmail}.',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
