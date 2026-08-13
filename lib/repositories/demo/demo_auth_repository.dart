import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/models/auth_session_model.dart';
import 'package:multiparking_tower/models/user_model.dart';
import 'package:multiparking_tower/repositories/auth_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({DemoDataStore? store}) : _store = store ?? DemoDataStore.instance;

  final DemoDataStore _store;

  @override
  Future<void> sendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    if (normalized.length < 10) {
      throw const ServerException(message: 'Enter a valid 10-digit Indian mobile number');
    }
    _store.pendingOtpPhone = normalized.length > 10
        ? normalized.substring(normalized.length - 10)
        : normalized;
  }

  @override
  Future<AuthSession> verifyOtp(String phone, String otp) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    final last10 = normalized.length > 10
        ? normalized.substring(normalized.length - 10)
        : normalized;

    if (otp != DemoDataStore.demoOtp) {
      throw const ServerException(message: 'Invalid OTP. Use 123456 in demo mode.');
    }

    final isNewUser = _store.currentUser == null ||
        _store.currentUser!.phone != last10;

    if (isNewUser) {
      final now = DateTime.now();
      _store.currentUser = UserModel(
        id: _store.newId('user'),
        phone: last10,
        displayName: 'User ${last10.substring(6)}',
        memberSince: now,
        role: 'user',
      );
      // New accounts start clean — seeded demo data belongs to the sample user.
      _store.prepareFreshUserWorkspace();
    } else if (_store.currentUser!.phone != last10) {
      _store.currentUser = _store.currentUser!.copyWith(phone: last10);
    }

    _store.pendingOtpPhone = null;
    final brandNew = isNewUser && last10 != DemoDataStore.demoPhone;
    _store.session = AuthSession(
      accessToken: 'demo_access_${_store.currentUser!.id}',
      refreshToken: 'demo_refresh_${_store.currentUser!.id}',
      user: _store.currentUser!,
      isNewUser: brandNew,
    );
    return _store.session!;
  }

  @override
  Future<AuthSession> staffLogin(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final user = username.trim().toLowerCase();
    if ((user != 'staff' || password != 'Parking@123') &&
        (user != 'admin' || password != 'Admin@123')) {
      throw const ServerException(message: 'Invalid username or password');
    }
    final now = DateTime.now();
    final isAdmin = user == 'admin';
    _store.currentUser = UserModel(
      id: isAdmin ? 'user_demo_admin' : 'user_demo_staff',
      phone: '',
      username: user,
      displayName: isAdmin ? 'Tower Admin' : 'Gate Staff',
      memberSince: now,
      role: isAdmin ? 'admin' : 'staff',
    );
    _store.session = AuthSession(
      accessToken: 'demo_access_${_store.currentUser!.id}',
      refreshToken: 'demo_refresh_${_store.currentUser!.id}',
      user: _store.currentUser!,
      isNewUser: false,
    );
    return _store.session!;
  }

  @override
  Future<AuthSession> refreshToken(String refreshToken) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final user = _store.currentUser;
    if (user == null || !refreshToken.startsWith('demo_refresh_')) {
      throw const ServerException(message: 'Session expired. Please sign in again.');
    }
    _store.session = AuthSession(
      accessToken: 'demo_access_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: refreshToken,
      user: user,
      isNewUser: false,
    );
    return _store.session!;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _store.resetSession();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (_store.session == null) return null;
    return _store.currentUser;
  }
}
