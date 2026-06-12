import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  AuthProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Non-fatal: app works without persistence
    }
  }

  String? _accessToken;
  String? _refreshToken;
  UserModel? _currentUser;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null && _accessToken != null;

  UserRole get userRole {
    if (_currentUser == null) return UserRole.user;
    return UserRole.fromString(_currentUser!.role);
  }

  Future<void> login(String phone, String password,
      {String? captchaId, String? captchaCode}) async {
    final loginResponse = await ApiService.login(
      phone,
      password,
      captchaId: captchaId,
      captchaCode: captchaCode,
    );
    _accessToken = loginResponse.accessToken;
    _refreshToken = loginResponse.refreshToken;
    _currentUser = loginResponse.user;
    ApiService.setAccessToken(_accessToken);
    await _persistTokens();
    notifyListeners();
  }

  Future<void> register(
    String name,
    String phone,
    String password,
    String plateNumber, {
    required String captchaId,
    required String captchaCode,
  }) async {
    await ApiService.register(
      name,
      phone,
      password,
      plateNumber,
      captchaId: captchaId,
      captchaCode: captchaCode,
    );
  }

  void logout() {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    ApiService.setAccessToken(null);
    _clearPersistedTokens();
    notifyListeners();
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final loginResponse =
          await ApiService.refreshToken(_refreshToken!);
      _accessToken = loginResponse.accessToken;
      _refreshToken = loginResponse.refreshToken;
      // Backend refresh response may omit user — preserve existing user data
      if (loginResponse.user.id.isNotEmpty) {
        _currentUser = loginResponse.user;
      }
      ApiService.setAccessToken(_accessToken);
      await _persistTokens();
      notifyListeners();
      return true;
    } catch (e) {
      logout();
      return false;
    }
  }

  Future<void> _persistTokens() async {
    if (_prefs == null) return;
    try {
      final prefs = _prefs;
      if (_accessToken != null) {
        await prefs!.setString('access_token', _accessToken!);
      }
      if (_refreshToken != null) {
        await prefs!.setString('refresh_token', _refreshToken!);
      }
    } catch (_) {}
  }

  Future<void> _clearPersistedTokens() async {
    if (_prefs == null) return;
    try {
      await _prefs!.remove('access_token');
      await _prefs!.remove('refresh_token');
    } catch (_) {}
  }

  Future<void> refreshBalance() async {
    try {
      final balance = await ApiService.getBalance();
      if (_currentUser != null) {
        _currentUser = UserModel(
          id: _currentUser!.id,
          name: _currentUser!.name,
          phone: _currentUser!.phone,
          plateNumber: _currentUser!.plateNumber,
          role: _currentUser!.role,
          balance: balance,
        );
        notifyListeners();
      }
    } catch (_) {
      // Non-fatal: balance refresh failure should not block UI
    }
  }

  /// Update the current user's profile info in memory.
  void updateProfileLocally(String name, String phone, String plateNumber) {
    if (_currentUser != null) {
      _currentUser = UserModel(
        id: _currentUser!.id,
        name: name,
        phone: phone,
        plateNumber: plateNumber,
        role: _currentUser!.role,
        balance: _currentUser!.balance,
      );
      notifyListeners();
    }
  }

  Future<bool> tryAutoLogin() async {
    // Ensure prefs are initialized
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (_) {
        return false;
      }
    }
    try {
      final accessToken = _prefs!.getString('access_token');
      final refreshToken = _prefs!.getString('refresh_token');
      if (accessToken == null || refreshToken == null) {
        return false;
      }
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      ApiService.setAccessToken(_accessToken);
      try {
        final success = await refreshAccessToken();
        return success;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}