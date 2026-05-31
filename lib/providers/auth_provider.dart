import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage? _secureStorage;

  AuthProvider() : _secureStorage = _initStorage();

  static FlutterSecureStorage? _initStorage() {
    try {
      return const FlutterSecureStorage();
    } catch (_) {
      return null;
    }
  }

  String? _accessToken;
  String? _refreshToken;
  UserModel? _currentUser;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null && _accessToken != null;

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
      _currentUser = loginResponse.user;
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
    if (_secureStorage == null) return;
    try {
      final storage = _secureStorage;
      if (_accessToken != null) {
        await storage.write(key: 'access_token', value: _accessToken);
      }
      if (_refreshToken != null) {
        await storage.write(key: 'refresh_token', value: _refreshToken);
      }
    } catch (_) {}
  }

  Future<void> _clearPersistedTokens() async {
    if (_secureStorage == null) return;
    try {
      final storage = _secureStorage;
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
    } catch (_) {}
  }

  Future<bool> tryAutoLogin() async {
    if (_secureStorage == null) return false;
    try {
      final storage = _secureStorage;
      final accessToken =
          await storage.read(key: 'access_token');
      final refreshToken =
          await storage.read(key: 'refresh_token');
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