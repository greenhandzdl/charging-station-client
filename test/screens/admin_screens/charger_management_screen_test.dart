import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:charging_station_client/screens/admin_screens/charger_management_screen.dart';
import 'package:charging_station_client/services/api_service.dart';
import '../../test_helpers.dart';

/// Helper: create an http.Response with UTF-8 content type so Chinese chars work.
http.Response jsonResponse(dynamic body, int status) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('ChargerManagementScreen', () {
    setUp(() {
      ApiService.testClient = MockClient((request) async {
        if (request.url.toString().contains('/stations')) {
          return jsonResponse([], 200);
        }
        if (request.url.toString().contains('/chargers')) {
          return jsonResponse([], 200);
        }
        return jsonResponse({'error': 'not found'}, 404);
      });
    });

    tearDown(() {
      ApiService.testClient = null;
    });

    testWidgets('renders AppBar with title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        child: const ChargerManagementScreen(),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.text('充电桩管理'), findsOneWidget);
    });

    testWidgets('shows station dropdown', (tester) async {
      ApiService.testClient = MockClient((request) async {
        if (request.url.toString().contains('/stations')) {
          return jsonResponse([
            {'id': 's1', 'name': '朝阳充电站', 'location': '朝阳区', 'chargerCount': 6, 'status': 'normal'},
            {'id': 's2', 'name': '海淀充电站', 'location': '海淀区', 'chargerCount': 4, 'status': 'normal'},
          ], 200);
        }
        return jsonResponse([], 200);
      });

      await tester.pumpWidget(wrapWithProviders(
        child: const ChargerManagementScreen(),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.text('选择充电站'), findsOneWidget);
    });

    testWidgets('shows charger list after selecting station', (tester) async {
      ApiService.testClient = MockClient((request) async {
        if (request.url.toString().contains('/stations')) {
          return jsonResponse([
            {'id': 's1', 'name': '朝阳充电站', 'location': '朝阳区', 'chargerCount': 6, 'status': 'normal'},
          ], 200);
        }
        if (request.url.toString().contains('/chargers')) {
          return jsonResponse([
            {'id': 'c1', 'chargerCode': 'CC-001', 'type': 'fast', 'status': 'idle', 'stationName': '朝阳充电站'},
            {'id': 'c2', 'chargerCode': 'CC-002', 'type': 'slow', 'status': 'idle', 'stationName': '朝阳充电站'},
          ], 200);
        }
        return jsonResponse([], 200);
      });

      await tester.pumpWidget(wrapWithProviders(
        child: const ChargerManagementScreen(),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      // Tap the dropdown to open it, then select station
      await tester.tap(find.text('选择充电站'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('朝阳充电站').last);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.textContaining('CC-001'), findsOneWidget);
      expect(find.textContaining('CC-002'), findsOneWidget);
    });

    testWidgets('shows error snackbar on API failure', (tester) async {
      ApiService.testClient = MockClient((request) async {
        return jsonResponse({'error': 'server error'}, 500);
      });

      await tester.pumpWidget(wrapWithProviders(
        child: const ChargerManagementScreen(),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.textContaining('加载失败'), findsOneWidget);
    });
  });
}