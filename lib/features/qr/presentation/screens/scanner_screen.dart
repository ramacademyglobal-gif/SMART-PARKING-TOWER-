import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/features/parking/presentation/providers/parking_provider.dart';
import 'package:multiparking_tower/features/parking/presentation/widgets/parking_exit_receipt.dart';
import 'package:multiparking_tower/features/history/presentation/providers/history_provider.dart';
import 'package:multiparking_tower/features/qr/presentation/providers/qr_provider.dart';
import 'package:multiparking_tower/models/gate_scan_result.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// Tower gate scanner: 1st scan = entry, 2nd scan = exit (+ amount to pay).
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  PermissionStatus _permission = PermissionStatus.denied;
  bool _handling = false;
  bool _torchOn = false;

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

  Future<void> _processMyPass() async {
    final qr = ref.read(qrControllerProvider).qr;
    if (qr == null || qr.token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate your Entry QR first.')),
      );
      return;
    }
    await _processToken(qr.token);
  }

  Future<void> _processToken(String token) async {
    if (_handling) return;
    _handling = true;
    await _controller?.stop();
    if (!mounted) return;

    try {
      final result = await ref
          .read(parkingRepositoryProvider)
          .scanPass(token, action: 'auto');
      ref.invalidate(currentSlotProvider);
      ref.invalidate(parkingHistoryListProvider);
      if (!mounted) return;
      await showGateScanResult(context, result: result, ref: ref);
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
        title: const Text('Gate scanner'),
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
    // Web / desktop often lack a second camera to scan the on-screen QR.
    final showUseMyPass = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (_permission.isPermanentlyDenied) {
      return _PermissionPane(
        title: 'Camera permission needed',
        message:
            'Enable camera access in system settings to scan parking QR codes.',
        actionLabel: 'Open settings',
        onAction: openAppSettings,
        secondaryLabel: showUseMyPass ? 'Process my QR pass' : null,
        onSecondary: showUseMyPass ? _processMyPass : null,
      );
    }

    if (!_permission.isGranted && !_permission.isLimited) {
      return _PermissionPane(
        title: 'Allow camera access',
        message:
            'Scan a MultiParking pass: first scan records entry, second scan '
            'records exit and shows the amount due.',
        actionLabel: 'Grant permission',
        onAction: _bootstrap,
        secondaryLabel: showUseMyPass ? 'Process my QR pass' : null,
        onSecondary: showUseMyPass ? _processMyPass : null,
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
        MobileScanner(
          controller: controller,
          onDetect: _onDetect,
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _ScanFramePainter(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1st scan → Entry · vehicle & slot\n'
                '2nd scan → Exit · duration & amount',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textOnDark,
                      height: 1.4,
                    ),
              ),
              if (showUseMyPass) ...[
                const SizedBox(height: 16),
                PremiumButton(
                  label: 'PROCESS MY QR PASS',
                  icon: Icons.qr_code_2_rounded,
                  onPressed: _handling ? null : _processMyPass,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showGateScanResult(
  BuildContext context, {
  required GateScanResult result,
  required WidgetRef ref,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _GateScanSheet(result: result),
  ).then((_) async {
    if (!result.valid || !result.needsPayment) return;
    final session = result.toHistorySession();
    if (session == null || !context.mounted) return;
    await showParkingExitReceipt(context, session: session);
    ref.invalidate(parkingHistoryListProvider);
  });
}

class _GateScanSheet extends StatelessWidget {
  const _GateScanSheet({required this.result});

  final GateScanResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEntry = result.isEntry;
    final statusLabel = !result.valid
        ? 'Rejected'
        : (isEntry ? 'ENTRY' : (result.isExit ? 'EXIT' : 'Scan'));
    final statusColor = !result.valid
        ? AppColors.error
        : (isEntry ? AppColors.success : AppColors.tealDeep);

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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  result.valid
                      ? (isEntry
                          ? Icons.login_rounded
                          : Icons.logout_rounded)
                      : Icons.block_rounded,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              result.message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            if (result.vehicleNumber != null)
              _DetailRow(
                icon: Icons.directions_car_rounded,
                label: 'Vehicle',
                value: result.vehicleNumber!,
              ),
            if (result.userName != null)
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Member',
                value: result.userName!,
              ),
            if (result.userPhone != null && result.userPhone!.isNotEmpty)
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: result.userPhone!,
              ),
            if (result.slotLabel != null)
              _DetailRow(
                icon: Icons.local_parking_rounded,
                label: 'Slot',
                value: result.slotLabel!,
              ),
            if (result.billingType != null)
              _DetailRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Billing',
                value: result.billingType == 'hourly'
                    ? 'Pay as you go'
                    : result.billingType!,
              ),
            if (result.entryAt != null)
              _DetailRow(
                icon: Icons.login_rounded,
                label: 'Entered',
                value: Formatters.dateTime(result.entryAt!),
              ),
            if (result.exitAt != null)
              _DetailRow(
                icon: Icons.logout_rounded,
                label: 'Exited',
                value: Formatters.dateTime(result.exitAt!),
              ),
            if (result.durationLabel != null)
              _DetailRow(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: result.durationLabel!,
              ),
            if (result.isExit && (result.amountInPaise ?? 0) > 0)
              _DetailRow(
                icon: Icons.payments_outlined,
                label: 'Amount due',
                value: Formatters.currency(
                  result.amountRupees ?? ((result.amountInPaise ?? 0) / 100),
                  decimals: false,
                ),
                emphasize: true,
              )
            else if (result.isExit && result.valid)
              _DetailRow(
                icon: Icons.verified_outlined,
                label: 'Charge',
                value: 'Covered by plan',
              ),
            const SizedBox(height: 22),
            PremiumButton(
              label: result.needsPayment ? 'CONTINUE TO PAY' : 'DONE',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.tealDeep),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize ? AppColors.tealDeep : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPane extends StatelessWidget {
  const _PermissionPane({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.peachSoft.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 40,
              color: AppColors.peach,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textMutedDark,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 28),
          PremiumButton(
            label: actionLabel.toUpperCase(),
            onPressed: () => onAction(),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 12),
            PremiumButton.secondary(
              label: secondaryLabel!.toUpperCase(),
              onPressed: () => onSecondary!(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final holeSize = size.shortestSide * 0.62;
    final left = (size.width - holeSize) / 2;
    final top = (size.height - holeSize) / 2.4;
    final hole = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, holeSize, holeSize),
      const Radius.circular(28),
    );

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    final border = Paint()
      ..color = AppColors.peach
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(hole, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
