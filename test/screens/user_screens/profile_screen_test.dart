import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/screens/user_screens/profile_screen.dart';
import '../../test_helpers.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('renders user info when logged in', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const ProfileScreen(),
      ));
      await tester.pumpAndSettle();

      // User info should be displayed
      expect(find.text('测试用户'), findsOneWidget);
      expect(find.text('13800138000'), findsOneWidget);
    });

    testWidgets('does NOT have repair entry (报修) for regular USER', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(role: 'USER'),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const ProfileScreen(),
      ));
      await tester.pumpAndSettle();

      // Repair entry should NOT be present for regular USER
      expect(find.text('报修'), findsNothing);
    });

    testWidgets('repair entry (报修) is removed from profile for MAINTAINER', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(role: 'MAINTAINER'),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const ProfileScreen(),
      ));
      await tester.pumpAndSettle();

      // Repair entry removed from profile per user req — MAINTAINER uses 维修工作台 instead
      expect(find.text('报修'), findsNothing);
    });

    testWidgets('shows admin dashboard entry for ADMIN', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(role: 'ADMIN'),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const ProfileScreen(),
      ));
      await tester.pumpAndSettle();

      // Admin dashboard entry should be visible
      expect(find.text('管理后台'), findsOneWidget);
    });

    testWidgets('does NOT show admin dashboard for regular USER', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(role: 'USER'),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const ProfileScreen(),
      ));
      await tester.pumpAndSettle();

      // Admin dashboard entry should NOT be visible for regular users
      expect(find.text('管理后台'), findsNothing);
    });

    testWidgets('logout button clears auth and navigates to login', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const ProfileScreen(),
      ));
      await tester.pumpAndSettle();

      // Find and tap the logout button
      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      // Auth state should be cleared
      expect(authProvider.isLoggedIn, isFalse);
    });
  });
}