import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/providers/auth_provider.dart';

void main() {
  group('AuthProvider', () {
    test('initial state is not logged in', () {
      final provider = AuthProvider();
      expect(provider.isLoggedIn, isFalse);
      expect(provider.accessToken, isNull);
      expect(provider.refreshToken, isNull);
      expect(provider.currentUser, isNull);
    });

    test('logout clears state', () {
      final provider = AuthProvider();
      provider.logout();
      expect(provider.isLoggedIn, isFalse);
      expect(provider.currentUser, isNull);
    });

    test('tryAutoLogin returns false when storage is not available', () async {
      final provider = AuthProvider();
      final result = await provider.tryAutoLogin();
      // _prefs is null initially because _initPrefs() is async,
      // so tryAutoLogin returns false without attempting to read
      expect(result, isFalse);
    });
  });
}