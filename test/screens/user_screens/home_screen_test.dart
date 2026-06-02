import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/screens/user_screens/home_screen.dart';
import '../../test_helpers.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders bottom navigation with three tabs', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      // Bottom navigation bar exists
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Check icons rather than labels to avoid duplicate-text issues
      expect(find.byIcon(Icons.ev_station), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('switches tab on tap', (tester) async {
      // Use an auth provider with a logged-in user so profile screen renders fully
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      // Initially on charging tab (index 0) — shows station selection
      expect(find.text('选择充电站'), findsOneWidget);

      // Tap on "记录" tab by icon
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // Now should show charge history screen
      expect(find.byIcon(Icons.filter_list), findsOneWidget);

      // Tap on "我的" tab by icon
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // Now should be on profile tab — verify profile content renders
      // The profile screen shows user info from the provider
      expect(find.text('测试用户'), findsOneWidget);
      expect(find.text('13800138000'), findsOneWidget);
    });
  });
}