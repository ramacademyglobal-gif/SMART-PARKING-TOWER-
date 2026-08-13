import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/utils/validators.dart';
import 'package:multiparking_tower/core/widgets/app_text_field.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/features/staff/presentation/screens/staff_home_screen.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

class StaffWalkInScreen extends ConsumerStatefulWidget {
  const StaffWalkInScreen({super.key});

  @override
  ConsumerState<StaffWalkInScreen> createState() => _StaffWalkInScreenState();
}

class _StaffWalkInScreenState extends ConsumerState<StaffWalkInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _plateController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final session = await ref.read(staffRepositoryProvider).registerWalkIn(
            numberPlate: Validators.normalizeVehicleRegistration(
              _plateController.text,
            ),
            driverName: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
            contactPhone: _phoneController.text.trim().isEmpty
                ? null
                : Validators.normalizePhone(_phoneController.text),
          );
      ref.invalidate(staffOverviewProvider);
      ref.invalidate(staffParkedSessionsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bay booked'),
          content: Text(
            '${session.vehicleNumber}\n'
            '${session.slotLabel}\n'
            'Entered ${Formatters.dateTime(session.entryAt)}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go(AppRoutes.staffHome);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Add walk-in vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'For drivers without the app',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the car number to book the next free bay. Checkout later '
              'from the parked list or by searching the plate.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _plateController,
                    label: 'Vehicle number',
                    hint: 'KA01AB1234',
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s-]')),
                      LengthLimitingTextInputFormatter(14),
                    ],
                    validator: Validators.vehicleRegistration,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _nameController,
                    label: 'Driver name (optional)',
                    hint: 'Rahul',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Mobile (optional)',
                    hint: '9876543210',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return Validators.indianPhone(value);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 22),
                  PremiumButton(
                    label: 'BOOK PARKING SLOT',
                    icon: Icons.local_parking_rounded,
                    isLoading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
