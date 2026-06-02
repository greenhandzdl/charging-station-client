import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/screens/user_screens/login_screen.dart';
import 'package:charging_station_client/services/api_service.dart';
import '../../test_helpers.dart';

void main() {
  late MockAuthProvider authProvider;

  setUp(() {
    authProvider = MockAuthProvider();
  });

  Widget createTestWidget() {
    // Wrap with a Navigator so pushReplacement works after login
    return wrapWithProviders(
      authProvider: authProvider,
      child: const LoginScreen(),
    );
  }

  group('LoginScreen', () {
    testWidgets('renders all key elements', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Title
      expect(find.text('充电站管理系统'), findsOneWidget);
      // Input fields
      expect(find.byType(TextFormField), findsNWidgets(2));
      // Phone field label
      expect(find.text('手机号'), findsOneWidget);
      // Password field label
      expect(find.text('密码'), findsOneWidget);
      // Login button (appears as both AppBar title and button text)
      expect(find.text('登录'), findsAtLeast(1));
      // Register link
      expect(find.text('没有账号？立即注册'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap the login button — target the ElevatedButton directly
      final loginButton = find.widgetWithText(ElevatedButton, '登录');
      await tester.tap(loginButton);

      // Allow validation to process
      await tester.pumpAndSettle();

      // Should show validation messages
      expect(find.text('请输入手机号'), findsOneWidget);
      expect(find.text('请输入密码'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid phone number', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter invalid phone (too short)
      await tester.enterText(find.byType(TextFormField).first, '12345');
      // Enter password
      await tester.enterText(find.byType(TextFormField).last, 'password123');

      final loginButton = find.widgetWithText(ElevatedButton, '登录');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.text('手机号格式不正确'), findsOneWidget);
    });

    testWidgets('calls login with correct credentials', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter valid phone
      await tester.enterText(find.byType(TextFormField).first, '13800138000');
      // Enter password
      await tester.enterText(find.byType(TextFormField).last, 'password123');

      final loginButton = find.widgetWithText(ElevatedButton, '登录');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(authProvider.loginCalled, isTrue);
      expect(authProvider.lastLoginPhone, '13800138000');
      expect(authProvider.lastLoginPassword, 'password123');
    });

    testWidgets('shows snackbar on login error', (tester) async {
      authProvider.setLoginError(ApiException(
        statusCode: 401,
        message: '手机号或密码错误',
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter valid credentials
      await tester.enterText(find.byType(TextFormField).first, '13800138000');
      await tester.enterText(find.byType(TextFormField).last, 'password123');

      final loginButton = find.widgetWithText(ElevatedButton, '登录');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Snackbar with error message
      expect(find.text('手机号或密码错误'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially password is obscured — visibility_off icon shown
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      // Tap the visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // After toggle, visibility icon should appear
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);
    });
  });
}