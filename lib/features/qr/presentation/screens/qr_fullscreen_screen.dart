import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/empty_state.dart';
import 'package:multiparking_tower/core/widgets/loading_shimmer.dart';
import 'package:multiparking_tower/features/qr/presentation/providers/qr_provider.dart';

/// Dark, high-contrast QR suitable for gate scanners.
class QrFullscreenScreen extends ConsumerStatefulWidget {
  const QrFullscreenScreen({super.key});

  @override
  ConsumerState<QrFullscreenScreen> createState() => _QrFullscreenScreenState();
}

class _QrFullscreenScreenState extends ConsumerState<QrFullscreenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Keep the on-screen clock fresh.
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _now = DateTime.now());
      return true;
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrState = ref.watch(qrControllerProvider);
    final qr = qrState.qr;

    // Restart subtle pulse whenever the token refreshes.
    ref.listen(qrControllerProvider, (previous, next) {
      if (previous?.refreshPulse != next.refreshPulse) {
        _pulse
          ..reset()
          ..forward();
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _pulse.repeat(reverse: true);
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textOnDark,
                ),
              ),
            ),
            if (qrState.status == QrLoadStatus.loading && qr == null)
              const Center(child: ShimmerCard(height: 280))
            else if (qr == null)
              EmptyState(
                icon: Icons.qr_code_2_rounded,
                title: 'No QR to display',
                subtitle: 'Generate an access pass first.',
                compact: true,
                onAction: () => Navigator.of(context).maybePop(),
                actionLabel: 'Go back',
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Present at tower gate',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.peachSoft,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Formatters.dateTime(_now),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMutedDark,
                            ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final scale = 1 + (_pulse.value * 0.018);
                          final glow = 0.18 + (_pulse.value * 0.22);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.peach
                                        .withValues(alpha: glow),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: QrImageView(
                          data: qr.token,
                          version: QrVersions.auto,
                          size: MediaQuery.sizeOf(context).shortestSide * 0.62,
                          backgroundColor: AppColors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        qr.vehicleNumber,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        qr.slotLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textMutedDark,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
