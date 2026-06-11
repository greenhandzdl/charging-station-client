import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:charging_station_client/screens/user_screens/repair_screen.dart';
import 'package:charging_station_client/services/api_service.dart';
import '../../test_helpers.dart';

void main() {
  group('RepairScreen', () {
    tearDown(() {
      ApiService.testClient = null;
    });

    testWidgets('renders repair submission form', (tester) async {
      final repairProvider = MockRepairProvider();

      await tester.pumpWidget(wrapWithProviders(
        repairProvider: repairProvider,
        child: const RepairScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('报修'), findsOneWidget);
      expect(find.text('提交报修'), findsAtLeast(1));
      expect(find.text('我的报修记录'), findsOneWidget);
      expect(find.text('充电桩编号'), findsOneWidget);
      expect(find.text('故障描述'), findsOneWidget);
    });

    testWidgets('shows empty state when no repair records', (tester) async {
      final repairProvider = MockRepairProvider();

      await tester.pumpWidget(wrapWithProviders(
        repairProvider: repairProvider,
        child: const RepairScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('暂无报修记录'), findsOneWidget);
    });

    testWidgets('shows user repair records', (tester) async {
      final repairProvider = MockRepairProvider();
      repairProvider.setRepairs([
        createMockRepair(
          id: 'r1',
          chargerCode: 'CC-001',
          description: '无法充电',
          status: 'open',
          reportedAt: '2026-06-01T10:00:00',
        ),
      ]);

      await tester.pumpWidget(wrapWithProviders(
        repairProvider: repairProvider,
        child: const RepairScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CC-001'), findsOneWidget);
      expect(find.textContaining('无法充电'), findsOneWidget);
    });

    testWidgets('submit button calls provider.submitRepair', (tester) async {
      final repairProvider = MockRepairProvider();

      await tester.pumpWidget(wrapWithProviders(
        repairProvider: repairProvider,
        child: const RepairScreen(),
      ));
      await tester.pumpAndSettle();

      // Fill the form
      await tester.enterText(find.byType(TextField).first, 'CC-001');
      await tester.enterText(find.byType(TextField).last, '充电桩故障');

      // Tap submit
      await tester.tap(find.widgetWithText(ElevatedButton, '提交报修'));
      await tester.pumpAndSettle();

      expect(repairProvider.submitRepairCalled, isTrue);
      expect(repairProvider.lastChargerCode, 'CC-001');
      expect(repairProvider.lastDescription, '充电桩故障');
      expect(find.text('报修已提交'), findsOneWidget);
    });

    testWidgets('shows validation error when fields are empty', (tester) async {
      final repairProvider = MockRepairProvider();

      await tester.pumpWidget(wrapWithProviders(
        repairProvider: repairProvider,
        child: const RepairScreen(),
      ));
      await tester.pumpAndSettle();

      // Tap submit without filling fields
      await tester.tap(find.widgetWithText(ElevatedButton, '提交报修'));
      await tester.pumpAndSettle();

      expect(find.text('请填写完整信息'), findsOneWidget);
    });

    testWidgets('shows error snackbar on submit failure', (tester) async {
      final repairProvider = MockRepairProvider();
      repairProvider.setSubmitError(Exception('服务器错误'));

      await tester.pumpWidget(wrapWithProviders(
        repairProvider: repairProvider,
        child: const RepairScreen(),
      ));
      await tester.pumpAndSettle();

      // Fill the form
      await tester.enterText(find.byType(TextField).first, 'CC-001');
      await tester.enterText(find.byType(TextField).last, '充电桩故障');

      // Tap submit
      await tester.tap(find.widgetWithText(ElevatedButton, '提交报修'));
      await tester.pumpAndSettle();

      expect(find.textContaining('服务器错误'), findsOneWidget);
    });
  });
}