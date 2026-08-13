import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/features/parking/presentation/providers/parking_provider.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

enum QrLoadStatus { idle, loading, refreshing, ready, error }

class QrState extends Equatable {
  const QrState({
    this.status = QrLoadStatus.idle,
    this.qr,
    this.errorMessage,
    this.refreshPulse = 0,
    this.lastRefreshedAt,
  });

  final QrLoadStatus status;
  final QrCodeModel? qr;
  final String? errorMessage;

  /// Bumps whenever a refresh completes so fullscreen UI can pulse.
  final int refreshPulse;
  final DateTime? lastRefreshedAt;

  bool get isLoading =>
      status == QrLoadStatus.loading || status == QrLoadStatus.refreshing;

  QrState copyWith({
    QrLoadStatus? status,
    QrCodeModel? qr,
    String? errorMessage,
    int? refreshPulse,
    DateTime? lastRefreshedAt,
    bool clearError = false,
    bool clearQr = false,
  }) {
    return QrState(
      status: status ?? this.status,
      qr: clearQr ? null : (qr ?? this.qr),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      refreshPulse: refreshPulse ?? this.refreshPulse,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }

  @override
  List<Object?> get props =>
      [status, qr, errorMessage, refreshPulse, lastRefreshedAt];
}

class QrController extends Notifier<QrState> {
  Timer? _expiryTicker;

  @override
  QrState build() {
    ref.onDispose(() {
      _expiryTicker?.cancel();
    });
    // After staff exit, hourly QR is revoked — reload when payment/session updates.
    ref.listen(pendingParkingPaymentProvider, (previous, next) {
      final hadPending = previous?.valueOrNull != null;
      final hasPending = next.valueOrNull != null;
      if (!hadPending && hasPending) {
        Future.microtask(load);
      }
    });
    ref.listen(activeParkedSessionProvider, (previous, next) {
      final wasParked = previous?.valueOrNull != null;
      final isParked = next.valueOrNull != null;
      if (wasParked && !isParked) {
        Future.microtask(load);
      }
    });
    Future.microtask(load);
    return const QrState(status: QrLoadStatus.loading);
  }

  Future<void> load() async {
    state = state.copyWith(
      status: QrLoadStatus.loading,
      clearError: true,
    );
    try {
      final qr = await ref.read(qrRepositoryProvider).getCurrentQr();
      state = state.copyWith(
        status: QrLoadStatus.ready,
        qr: qr,
        clearQr: qr == null,
        lastRefreshedAt: DateTime.now(),
        clearError: true,
      );
      _scheduleExpiryTick(qr);
    } catch (error) {
      state = state.copyWith(
        status: QrLoadStatus.error,
        errorMessage: describeError(
          error,
          fallback: 'Could not load your access QR.',
        ),
      );
    }
  }

  /// Books / regenerates a pass (hourly after exit, or rotate for subscribers).
  Future<void> refreshQr() async {
    if (state.status == QrLoadStatus.refreshing) return;
    state = state.copyWith(
      status: QrLoadStatus.refreshing,
      clearError: true,
    );
    try {
      final qr = await ref.read(qrRepositoryProvider).refreshQr();
      state = state.copyWith(
        status: QrLoadStatus.ready,
        qr: qr,
        refreshPulse: state.refreshPulse + 1,
        lastRefreshedAt: DateTime.now(),
        clearError: true,
      );
      _scheduleExpiryTick(qr);
      ref.invalidate(currentSlotProvider);
    } catch (error) {
      state = state.copyWith(
        status: QrLoadStatus.error,
        errorMessage: describeError(
          error,
          fallback: 'Could not refresh your QR code.',
        ),
      );
    }
  }

  /// Lightweight ticker so expiry labels recompute without a full reload.
  void _scheduleExpiryTick(QrCodeModel? qr) {
    _expiryTicker?.cancel();
    if (qr == null || qr.isPermanent) return;
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      // Bump pulse so expiry labels rebuild; timer is cancelled on dispose.
      state = state.copyWith(refreshPulse: state.refreshPulse + 1);
    });
  }
}

final qrControllerProvider =
    NotifierProvider<QrController, QrState>(QrController.new);

final currentQrProvider = Provider<QrCodeModel?>((ref) {
  return ref.watch(qrControllerProvider).qr;
});
