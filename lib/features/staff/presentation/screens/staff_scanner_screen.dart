import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/features/staff/presentation/screens/staff_home_screen.dart';
import 'package:multiparking_tower/models/gate_scan_result.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// Staff-facing gate scanner with richer entry/exit detail cards.
class StaffScannerScreen extends ConsumerStatefulWidget {
  const StaffScannerScreen({super.key});

  @override
  ConsumerState<StaffScannerScreen> createState() => _StaffScannerScreenState();
}

class _StaffScannerScreenState extends ConsumerState<StaffScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  PermissionStatus _permission = PermissionStatus.denied;
  bool _handling = false;
  bool _torchOn = false;
  final _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _permission = status);
    if (status.isGranted || status.isLimited) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !_permission.isGranted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;
    await _processToken(raw.trim());
  }

  Future<void> _processToken(String token) async {
    if (_handling) return;
    _handling = true;
    await _controller?.stop();
    if (!mounted) return;

    try {
      final result = await ref
          .read(staffRepositoryProvider)
          .scanPass(token, action: 'auto');
      ref.invalidate(staffOverviewProvider);
      ref.invalidate(staffParkedSessionsProvider);
      if (!mounted) return;
      await showStaffScanResult(context, result: result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) await _controller?.start();
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        backgroundColor: AppColors.charcoal,
        foregroundColor: AppColors.white,
        title: const Text('Staff QR scanner'),
        actions: [
          if (_controller != null)
            IconButton(
              tooltip: _torchOn ? 'Torch off' : 'Torch on',
              onPressed: () async {
                await _controller?.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final showManual = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (!_permission.isGranted && !_permission.isLimited) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner_rounded,
                size: 64, color: AppColors.peach),
            const SizedBox(height: 18),
            Text(
              'Camera needed to scan parking passes',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 18),
            PremiumButton(
              label: 'GRANT CAMERA',
              onPressed: _bootstrap,
            ),
            if (showManual) ...[
              const SizedBox(height: 16),
              _ManualTokenField(
                controller: _manualController,
                onSubmit: _processToken,
                enabled: !_handling,
              ),
            ],
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.peach),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: controller, onDetect: _onDetect),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1st scan → ENTRY details\n2nd scan → EXIT + amount due',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textOnDark,
                      height: 1.4,
                    ),
              ),
              if (showManual) ...[
                const SizedBox(height: 14),
                _ManualTokenField(
                  controller: _manualController,
                  onSubmit: _processToken,
                  enabled: !_handling,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ManualTokenField extends StatelessWidget {
  const _ManualTokenField({
    required this.controller,
    required this.onSubmit,
    required this.enabled,
  });

  final TextEditingController controller;
  final Future<void> Function(String token) onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                decoration: const InputDecoration(
                  hintText: 'Paste QR token (desktop)',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: !enabled || controller.text.trim().isEmpty
                  ? null
                  : () => onSubmit(controller.text.trim()),
              icon: const Icon(Icons.send_rounded, color: AppColors.tealDeep),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showStaffScanResult(
  BuildContext context, {
  required GateScanResult result,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _StaffScanSheet(result: result),
  );
}

class _StaffScanSheet extends StatelessWidget {
  const _StaffScanSheet({required this.result});

  final GateScanResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEntry = result.isEntry;
    final isExit = result.isExit;
    // Prefer ENTRY/EXIT label whenever the gate resolved an action — even if
    // the scan was rejected (e.g. already parked). Only fall back to REJECTED
    // when there is no entry/exit classification.
    final hasGateAction = isEntry || isExit;
    final statusLabel = !result.valid && !hasGateAction
        ? 'REJECTED'
        : (isEntry ? 'ENTRY' : (isExit ? 'EXIT' : 'SCAN'));
    final statusColor = !result.valid && !hasGateAction
        ? AppColors.error
        : (!result.valid
            ? AppColors.warning
            : (isEntry ? AppColors.success : AppColors.peachDeep));
    final statusIcon = !result.valid && !hasGateAction
        ? Icons.block_rounded
        : (isEntry ? Icons.login_rounded : Icons.logout_rounded);

    final slotText = result.slotLabel ??
        ([
          if (result.tower != null) 'Tower ${result.tower}',
          if (result.floor != null) 'Floor ${result.floor}',
          if (result.zone != null) 'Zone ${result.zone}',
          if (result.slotNumber != null) 'Slot ${result.slotNumber}',
        ].join(' · '));
    final amountPaise = result.amountInPaise ?? 0;
    final amountText = amountPaise > 0
        ? Formatters.currency(
            result.amountRupees ?? (amountPaise / 100),
            decimals: false,
          )
        : '₹0 · Covered by plan';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor, width: 1.6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(statusIcon, color: AppColors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GATE STATUS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusLabel,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        if (!result.valid) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Not authorized',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isEntry && slotText.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.tealDeep.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.tealDeep.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALLOTTED SLOT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.tealDeep,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      slotText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.tealDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isExit) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.peachSoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.peachDeep),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amountPaise > 0 ? 'AMOUNT DUE' : 'CHARGE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.tealDeep,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      amountText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.tealDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (result.durationLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Duration · ${result.durationLabel}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.tealDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              result.message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            if (result.userName != null)
              _row(Icons.person_outline_rounded, 'Member', result.userName!),
            if (result.userPhone != null && result.userPhone!.isNotEmpty)
              _row(Icons.phone_outlined, 'Phone', result.userPhone!),
            if (result.vehicleNumber != null)
              _row(Icons.directions_car_rounded, 'Vehicle',
                  result.vehicleNumber!),
            if (result.slotLabel != null && !isEntry)
              _row(Icons.local_parking_rounded, 'Slot', result.slotLabel!),
            if (result.subscriptionType != null || result.billingType != null)
              _row(
                Icons.workspace_premium_outlined,
                'Plan',
                (result.subscriptionType ?? result.billingType) == 'hourly'
                    ? 'Pay as you go'
                    : (result.subscriptionType ?? result.billingType)!,
              ),
            if (result.entryAt != null)
              _row(Icons.login_rounded, 'Entered',
                  Formatters.dateTime(result.entryAt!)),
            if (result.exitAt != null)
              _row(Icons.logout_rounded, 'Exited',
                  Formatters.dateTime(result.exitAt!)),
            const SizedBox(height: 22),
            PremiumButton(
              label: 'DONE',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.tealDeep),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
                color: emphasize ? AppColors.tealDeep : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
