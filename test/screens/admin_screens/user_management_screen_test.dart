import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/screens/admin_screens/user_management_screen.dart';
import '../../test_helpers.dart';

void main() {
  group('UserManagementScreen', () {
    testWidgets('renders AppBar with title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        child: const UserManagementScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('用户管理'), findsOneWidget);
    });

    testWidgets('shows loading indicator then empty state', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        child: const UserManagementScreen(),
      ));
      // Initially loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // After delay completes, loading finishes
      await tester.pumpAndSettle();

      // Shows empty state text (the screen simulates a delayed load)
      expect(find.text('用户列表加载中...'), findsOneWidget);
    });
  });
}