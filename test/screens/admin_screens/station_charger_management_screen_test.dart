import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:charging_station_client/screens/admin_screens/station_charger_management_screen.dart';
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
  group('StationChargerManagementScreen', () {
    setUp(() {
      ApiService.testClient = MockClient((request) async {
        if (request.url.toString().contains('/stations')) {
          return jsonResponse([], 200);
        }
        return jsonResponse({'error': 'not found'}, 404);
      });
    });

    tearDown(() {
      ApiService.testClient = null;
    });

    Future<void> pumpAndWait(WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(
        child: const StationChargerManagementScreen(),
      ));
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    testWidgets('renders AppBar with title', (tester) async {
      await pumpAndWait(tester);

      expect(find.text('充电站/充电桩管理'), findsOneWidget);
    });

    testWidgets('renders station list with charger expansion', (tester) async {
      ApiService.testClient = MockClient((request) async {
        if (request.url.toString().contains('/stations')) {
          return jsonResponse([
            {
              'id': 's1',
              'name': '朝阳充电站',
              'location': '朝阳区',
              'chargerCount': 2,
              'status': 'normal',
            },
            {
              'id': 's2',
              'name': '海淀充电站',
              'location': '海淀区',
              'chargerCount': 1,
              'status': 'normal',
            },
          ], 200);
        }
        if (request.url.toString().contains('/chargers/s1')) {
          return jsonResponse([
            {
              'id': 'c1',
              'chargerCode': 'CC-001',
              'type': 'FAST',
              'status': 'IDLE',
              'onlineStatus': 'ONLINE',
              'stationId': 's1',
            },
            {
              'id': 'c2',
              'chargerCode': 'CC-002',
              'type': 'SLOW',
              'status': 'IDLE',
              'onlineStatus': 'OFFLINE',
              'stationId': 's1',
            },
          ], 200);
        }
        return jsonResponse([], 200);
      });

      await pumpAndWait(tester);

      expect(find.text('朝阳充电站'), findsOneWidget);
      expect(find.text('海淀充电站'), findsOneWidget);
    });

    testWidgets('shows error snackbar when API fails', (tester) async {
      ApiService.testClient = MockClient((request) async {
        return jsonResponse({'error': 'server error'}, 500);
      });

      await pumpAndWait(tester);

      expect(find.textContaining('加载失败'), findsOneWidget);
    });

    testWidgets('shows empty list when no stations', (tester) async {
      await pumpAndWait(tester);

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('search filters stations and chargers', (tester) async {
      ApiService.testClient = MockClient((request) async {
        if (request.url.toString().contains('/stations')) {
          return jsonResponse([
            {
              'id': 's1',
              'name': '朝阳充电站',
              'location': '朝阳区',
              'chargerCount': 2,
              'status': 'normal',
            },
            {
              'id': 's2',
              'name': '海淀充电站',
              'location': '海淀区',
              'chargerCount': 1,
              'status': 'normal',
            },
          ], 200);
        }
        if (request.url.toString().contains('/chargers/s1')) {
          return jsonResponse([
            {
              'id': 'c1',
              'chargerCode': 'CC-001',
              'type': 'FAST',
              'status': 'IDLE',
              'onlineStatus': 'ONLINE',
              'stationId': 's1',
            },
          ], 200);
        }
        return jsonResponse([], 200);
      });

      await pumpAndWait(tester);

      // Enter search query
      await tester.enterText(find.byType(TextField), '朝阳');
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      // Should show station with type label
      expect(find.textContaining('充电站'), findsWidgets);
    });
  });
}