import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/extensions.dart';
import 'package:multiparking_tower/core/utils/validators.dart';
import 'package:multiparking_tower/core/widgets/app_text_field.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:multiparking_tower/models/vehicle_model.dart';

/// Registration fields shared by vehicle onboarding and vehicle management.
///
/// Owns its own submit button and busy state; [onSaved] fires only after the
/// repository confirms the new vehicle.
class VehicleForm extends ConsumerStatefulWidget {
  const VehicleForm({
    super.key,
    required this.onSaved,
    this.submitLabel = 'SAVE VEHICLE',
    this.autofocus = false,
    this.showDefaultToggle = false,
  });

  final ValueChanged<VehicleModel> onSaved;
  final String submitLabel;
  final bool autofocus;

  /// Offer "make this my default" — only meaningful once a garage exists.
  final bool showDefaultToggle;

  @override
  ConsumerState<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends ConsumerState<VehicleForm> {
  final _plateController = TextEditingController();

  bool _isSaving = false;
  bool _isDefault = false;
  String? _plateError;

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final plateError = Validators.vehicleRegistration(_plateController.text);
    if (plateError != null) {
      setState(() => _plateError = plateError);
      return;
    }

    setState(() {
      _plateError = null;
      _isSaving = true;
    });

    try {
      final vehicle = await ref.read(vehicleListProvider.notifier).add(
            numberPlate: _plateController.text,
            isDefault: _isDefault,
          );
      if (!mounted) return;
      widget.onSaved(vehicle);
    } catch (error) {
      if (!mounted) return;
      final message = describeError(
        error,
        fallback: 'We could not save this vehicle. Please try again.',
      );
      if (error is ValidationException) {
        setState(() => _plateError = message);
      } else {
        context.showSnack(message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _plateController,
          label: 'Vehicle number',
          hint: 'MH12AB1234',
          helperText: 'State code, RTO number, series and 4 digits.',
          errorText: _plateError,
          prefixIcon: Icons.directions_car_filled_outlined,
          autofocus: widget.autofocus,
          enabled: !_isSaving,
          maxLength: 13,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            _UpperCaseFormatter(),
          ],
          onChanged: (_) {
            if (_plateError != null) setState(() => _plateError = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        if (widget.showDefaultToggle) ...[
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            value: _isDefault,
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _isDefault = value),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Set as default vehicle',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: 20),
        PremiumButton(
          label: widget.submitLabel,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
