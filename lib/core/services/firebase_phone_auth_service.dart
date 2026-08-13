import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/utils/validators.dart';

/// Firebase Phone Authentication for Indian (+91) numbers.
///
/// Holds the [verificationId] between [sendOtp] and [verifyOtp] so the
/// existing login → OTP screens keep working without UI changes.
class FirebasePhoneAuthService {
  FirebasePhoneAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _settingsApplied = false;

  String? _verificationId;
  int? _resendToken;
  String? _pendingPhone;

  String? get verificationId => _verificationId;
  String? get pendingPhone => _pendingPhone;

  Future<void> _ensureSettings() async {
    if (_settingsApplied) return;
    _settingsApplied = true;
    // Prefer Play Integrity / SafetyNet over the browser reCAPTCHA fallback.
    // forceRecaptchaFlow: false is the default; set explicitly for clarity.
    await _auth.setSettings(
      forceRecaptchaFlow: false,
      appVerificationDisabledForTesting: false,
    );
    if (kDebugMode) {
      // Helps surface attestation issues in logcat without changing production.
      await _auth.setLanguageCode('en');
    }
  }

  /// Sends an SMS OTP to `+91XXXXXXXXXX`.
  Future<void> sendOtp(String phone) async {
    final digits = Validators.normalizePhone(phone);
    if (digits.length != 10) {
      throw const ValidationException(
        message: 'Enter a valid 10-digit Indian mobile number.',
      );
    }

    await _ensureSettings();

    final e164 = '+91$digits';
    _pendingPhone = digits;

    final completer = Completer<void>();

    await _auth.verifyPhoneNumber(
      phoneNumber: e164,
      // Auto-retrieval window; SMS may still arrive later.
      timeout: const Duration(seconds: 120),
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android may auto-retrieve the SMS; complete silently if possible.
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete();
        } catch (error) {
          if (!completer.isCompleted) {
            completer.completeError(_mapFirebaseError(error));
          }
        }
      },
      verificationFailed: (FirebaseAuthException error) {
        if (!completer.isCompleted) {
          completer.completeError(_mapFirebaseError(error));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
        // Do not complete here if codeSent already finished — that would race.
        if (!completer.isCompleted) completer.complete();
      },
    );

    // Guard against hung Play Integrity / reCAPTCHA flows.
    await completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        throw const AuthException(
          message:
              'Phone verification timed out. Check your connection and try again.',
        );
      },
    );
  }

  /// Verifies the 6-digit SMS code and returns the signed-in Firebase user.
  Future<User> verifyOtp(String otp) async {
    final code = otp.trim();
    if (code.length != 6) {
      throw const ValidationException(message: 'Enter the 6-digit OTP.');
    }

    // Auto-verification may already have signed the user in.
    final existing = _auth.currentUser;
    if (existing != null &&
        existing.phoneNumber != null &&
        _pendingPhone != null &&
        existing.phoneNumber!.endsWith(_pendingPhone!)) {
      return existing;
    }

    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw const AuthException(
        message: 'OTP session expired. Please request a new code.',
      );
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      final result = await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 45));
      final user = result.user;
      if (user == null) {
        throw const AuthException(message: 'Firebase sign-in failed.');
      }
      return user;
    } on TimeoutException {
      throw const AuthException(
        message: 'OTP verification timed out. Please try again.',
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  Future<String> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(message: 'Not signed in with Firebase.');
    }
    final token = await user.getIdToken(forceRefresh).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const AuthException(
        message: 'Could not obtain Firebase ID token (timed out).',
      ),
    );
    if (token == null || token.isEmpty) {
      throw const AuthException(message: 'Could not obtain Firebase ID token.');
    }
    return token;
  }

  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    _pendingPhone = null;
    await _auth.signOut();
  }

  AppException _mapFirebaseError(Object error) {
    if (error is AppException) return error;
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return const ValidationException(
            message: 'Invalid phone number. Use a valid 10-digit Indian number.',
          );
        case 'too-many-requests':
          return const AuthException(
            message: 'Too many attempts. Please try again later.',
            code: 'too-many-requests',
          );
        case 'invalid-verification-code':
          return const AuthException(message: 'Incorrect OTP. Please try again.');
        case 'session-expired':
        case 'invalid-verification-id':
          return const AuthException(
            message: 'OTP expired. Please request a new code.',
          );
        case 'missing-client-identifier':
        case 'app-not-authorized':
          return const AuthException(
            message:
                'Firebase Phone Auth is not fully configured. Add SHA-1/SHA-256 in Firebase Console.',
          );
        case 'quota-exceeded':
          return const AuthException(
            message: 'SMS quota exceeded for this project. Try again later.',
            code: 'quota-exceeded',
          );
        default:
          return AuthException(
            message: error.message ?? 'Firebase authentication failed.',
            code: error.code,
          );
      }
    }
    return AuthException(message: error.toString());
  }
}

final firebasePhoneAuthService = FirebasePhoneAuthService();
