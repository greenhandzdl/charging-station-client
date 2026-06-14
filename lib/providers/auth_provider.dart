import 'dart:convert';
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
    await _persistSession();
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

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    ApiService.setAccessToken(null);
    await _clearPersistedSession();
    notifyListeners();
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) {
      debugPrint('refreshAccessToken failed: refreshToken is null');
      return false;
    }
    
    try {
      debugPrint('Calling ApiService.refreshToken with refreshToken: ${_refreshToken!.substring(0, 20)}...');
      final loginResponse = await ApiService.refreshToken(_refreshToken!);
      
      final oldAccessTokenPrefix = _accessToken != null ? _accessToken!.substring(0, 20) : 'null';
      final newAccessTokenPrefix = loginResponse.accessToken.substring(0, 20);
      
      debugPrint('Token refresh successful');
      debugPrint('  Old access token: $oldAccessTokenPrefix...');
      debugPrint('  New access token: $newAccessTokenPrefix...');
      debugPrint('  Tokens are different: ${oldAccessTokenPrefix != newAccessTokenPrefix}');
      
      _accessToken = loginResponse.accessToken;
      _refreshToken = loginResponse.refreshToken;
      if (loginResponse.user.id.isNotEmpty) {
        _currentUser = loginResponse.user;
        debugPrint('User info updated: ${_currentUser?.name}');
      }
      
      debugPrint('Setting ApiService accessToken to: $newAccessTokenPrefix...');
      ApiService.setAccessToken(_accessToken);
      await _persistSession();
      notifyListeners();
      
      // 验证设置是否成功
      debugPrint('ApiService accessToken after set: ${ApiService.testAccessToken != null ? "exists" : "null"}');
      
      return true;
    } on ApiException catch (e) {
      debugPrint('refreshAccessToken failed with ApiException: statusCode=${e.statusCode}, message=${e.message}');
      // 401/403 — token invalid or expired, force logout
      if (e.statusCode == 401 || e.statusCode == 403) {
        debugPrint('Token expired or invalid, forcing logout');
        await logout();
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('refreshAccessToken failed with exception: $e');
      debugPrint('Stack trace: $stackTrace');
      // Network errors — keep current session intact for offline use
      return false;
    }
  }

  Future<void> _ensurePrefs() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  Future<void> _persistSession() async {
    await _ensurePrefs();
    if (_prefs == null) return;
    try {
      if (_accessToken != null) {
        await _prefs!.setString('access_token', _accessToken!);
      }
      if (_refreshToken != null) {
        await _prefs!.setString('refresh_token', _refreshToken!);
      }
      if (_currentUser != null) {
        await _prefs!.setString('cached_user', jsonEncode(_currentUser!.toJson()));
      }
    } catch (_) {}
  }

  Future<void> _clearPersistedSession() async {
    await _ensurePrefs();
    if (_prefs == null) return;
    try {
      await _prefs!.remove('access_token');
      await _prefs!.remove('refresh_token');
      await _prefs!.remove('cached_user');
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
    await _ensurePrefs();
    if (_prefs == null) {
      debugPrint('AutoLogin failed: SharedPreferences not available');
      return false;
    }
    try {
      final accessToken = _prefs!.getString('access_token');
      final refreshToken = _prefs!.getString('refresh_token');
      
      debugPrint('AutoLogin check - accessToken: ${accessToken != null ? "exists" : "null"}, refreshToken: ${refreshToken != null ? "exists" : "null"}');
      
      if (accessToken == null || refreshToken == null) {
        debugPrint('AutoLogin failed: tokens are null');
        return false;
      }
      
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      ApiService.setAccessToken(_accessToken);

      final userJson = _prefs!.getString('cached_user');
      if (userJson != null) {
        try {
          _currentUser =
              UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
          debugPrint('AutoLogin: user loaded from cache - ${_currentUser?.name}');
        } catch (e) {
          debugPrint('AutoLogin: failed to parse cached user - $e');
        }
      }

      try {
        final refreshed = await refreshAccessToken();
        debugPrint('AutoLogin: token refresh result - $refreshed');
        return refreshed;
      } catch (e) {
        debugPrint('AutoLogin: token refresh failed - $e');
        return false;
      }
    } catch (e) {
      debugPrint('AutoLogin exception: $e');
      return false;
    }
  }
}