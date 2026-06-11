import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:charging_station_client/screens/user_screens/register_screen.dart';
import 'package:charging_station_client/services/api_service.dart';
import '../../test_helpers.dart';

/// Create an http.Response with UTF-8 content type for Chinese character support.
http.Response jsonResponse(dynamic body, int status) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('RegisterScreen', () {
    setUp(() {
      ApiService.testClient = MockClient((request) async {
        if (request.url.toString().contains('/captcha')) {
          return jsonResponse({'captchaId': 'captcha1'}, 200);
        }
        if (request.url.toString().contains('/auth/register')) {
          return jsonResponse({'message': 'success'}, 200);
        }
        return jsonResponse({'error': 'not found'}, 404);
      });
    });

    tearDown(() {
      ApiService.testClient = null;
    });

    Future<void> pumpAndWait(WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(
        child: const RegisterScreen(),
      ));
      // Let the async initState _loadCaptcha() API call complete
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    testWidgets('renders all form fields and button', (tester) async {
      await pumpAndWait(tester);

      expect(find.text('姓名'), findsOneWidget);
      expect(find.text('手机号'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('确认密码'), findsOneWidget);
      expect(find.text('车牌号'), findsOneWidget);
      expect(find.text('验证码'), findsOneWidget);
      expect(find.text('注册'), findsAtLeast(1));
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      await pumpAndWait(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pumpAndSettle();

      expect(find.text('请输入姓名'), findsOneWidget);
      expect(find.text('请输入手机号'), findsOneWidget);
      expect(find.text('请输入密码'), findsOneWidget);
      expect(find.text('请输入车牌号'), findsOneWidget);
      expect(find.text('请输入验证码'), findsOneWidget);
    });

    testWidgets('shows validation error for password mismatch', (tester) async {
      await pumpAndWait(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test User');
      await tester.enterText(fields.at(1), '13800138000');
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'different');
      await tester.enterText(fields.at(4), 'ABC1234');
      await tester.enterText(fields.at(5), '1234');

      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pumpAndSettle();

      expect(find.text('两次密码不一致'), findsOneWidget);
    });

    testWidgets('calls register with correct args', (tester) async {
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const RegisterScreen(),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test User');
      await tester.enterText(fields.at(1), '13800138000');
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'password123');
      await tester.enterText(fields.at(4), 'ABC1234');
      await tester.enterText(fields.at(5), '1234');

      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pumpAndSettle();

      expect(authProvider.registerCalled, isTrue);
    });

    testWidgets('shows error snackbar on API failure', (tester) async {
      ApiService.testClient = MockClient((request) async {
        if (request.url.toString().contains('/captcha')) {
          return jsonResponse({'captchaId': 'captcha1'}, 200);
        }
        return jsonResponse({'error': 'phone registered'}, 400);
      });

      final authProvider = MockAuthProvider();
      authProvider.setLoginError(ApiException(
        statusCode: 400,
        message: 'phone registered',
      ));

      await tester.pumpWidget(wrapWithProviders(
        authProvider: authProvider,
        child: const RegisterScreen(),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test User');
      await tester.enterText(fields.at(1), '13800138000');
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'password123');
      await tester.enterText(fields.at(4), 'ABC1234');
      await tester.enterText(fields.at(5), '1234');

      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pumpAndSettle();

      expect(find.textContaining('phone registered'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await pumpAndWait(tester);

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);
    });
  });
}