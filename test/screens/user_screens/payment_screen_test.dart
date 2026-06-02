import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/screens/user_screens/payment_screen.dart';
import '../../test_helpers.dart';

void main() {
  group('PaymentScreen', () {
    testWidgets('renders balance display and recharge form', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(balance: 200.0),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const PaymentScreen(),
      ));
      // Let the async _loadPayments settle (it will fail gracefully since ApiService is static)
      await tester.pumpAndSettle();

      // Title check — use AppBar title
      expect(find.text('充值'), findsAtLeast(1));
      // Balance display
      expect(find.textContaining('200.0'), findsOneWidget);
      // Recharge amount field label
      expect(find.text('充值金额'), findsOneWidget);
      // Recharge button
      expect(find.widgetWithText(ElevatedButton, '充值'), findsOneWidget);
    });

    testWidgets('shows empty payment history message', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const PaymentScreen(),
      ));
      await tester.pumpAndSettle();

      // Payment history section
      expect(find.text('充值记录'), findsOneWidget);
      // Empty state (ApiService.getPayments will fail, so empty)
      expect(find.text('暂无充值记录'), findsOneWidget);
    });

    testWidgets('validates empty amount', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const PaymentScreen(),
      ));
      await tester.pumpAndSettle();

      // Tap recharge without entering amount — find the ElevatedButton specifically
      final rechargeButton = find.widgetWithText(ElevatedButton, '充值');
      await tester.tap(rechargeButton);
      await tester.pumpAndSettle();

      // Should show validation snackbar
      expect(find.text('请输入有效金额'), findsOneWidget);
    });

    testWidgets('displays user balance from auth provider', (tester) async {
      final authProvider = MockAuthProvider(
        isLoggedIn: true,
        user: createMockUser(balance: 500.5),
      );

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const PaymentScreen(),
      ));
      await tester.pumpAndSettle();

      // Balance should be visible
      expect(find.textContaining('500.5'), findsOneWidget);
    });
  });
}