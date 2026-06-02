import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/screens/user_screens/charging_screen.dart';
import '../../test_helpers.dart';

void main() {
  late MockChargingProvider chargingProvider;

  setUp(() {
    chargingProvider = MockChargingProvider();
  });

  Widget createTestWidget() {
    return wrapWithProviders(
      chargingProvider: chargingProvider,
      child: const ChargingScreen(),
    );
  }

  group('ChargingScreen', () {
    testWidgets('renders station selection prompt and start button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Title
      expect(find.text('充电'), findsOneWidget);
      // Station selection prompt
      expect(find.text('选择充电站'), findsOneWidget);
      // Start charge button
      expect(find.text('启动充电'), findsOneWidget);
      // Start button should be disabled initially (no selection)
      final startButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '启动充电'),
      );
      expect(startButton.onPressed, isNull);
    });

    testWidgets('displays stations list from provider', (tester) async {
      chargingProvider.setStations([
        createMockStation(
          id: 's1',
          name: '朝阳充电站',
          location: '朝阳区',
          chargerCount: 6,
        ),
        createMockStation(
          id: 's2',
          name: '海淀充电站',
          location: '海淀区',
          chargerCount: 4,
        ),
      ]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('朝阳充电站'), findsOneWidget);
      expect(find.text('海淀充电站'), findsOneWidget);
    });

    testWidgets('displays chargers when station is selected', (tester) async {
      chargingProvider.setStations([
        createMockStation(id: 's1', name: '朝阳充电站'),
      ]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap station to select it and load chargers
      await tester.tap(find.text('朝阳充电站'));
      await tester.pumpAndSettle();

      // Now chargers section should be visible
      expect(find.text('选择充电桩'), findsOneWidget);

      // Add some chargers
      chargingProvider.setChargers([
        createMockCharger(
          id: 'c1',
          stationId: 's1',
          chargerCode: 'CC-001',
          type: 'fast',
          status: 'idle',
        ),
        createMockCharger(
          id: 'c2',
          stationId: 's1',
          chargerCode: 'CC-002',
          type: 'slow',
          status: 'idle',
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('CC-001'), findsOneWidget);
      expect(find.textContaining('CC-002'), findsOneWidget);
    });

    testWidgets('enables start button when charger is selected', (tester) async {
      chargingProvider.setStations([
        createMockStation(id: 's1', name: '朝阳充电站'),
      ]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Select station
      await tester.tap(find.text('朝阳充电站'));
      await tester.pumpAndSettle();

      // Add idle chargers
      chargingProvider.setChargers([
        createMockCharger(
          id: 'c1',
          stationId: 's1',
          chargerCode: 'CC-001',
          status: 'idle',
        ),
      ]);
      await tester.pumpAndSettle();

      // Select the idle charger
      await tester.tap(find.textContaining('CC-001'));
      await tester.pumpAndSettle();

      // Start button should now be enabled
      final startButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '启动充电'),
      );
      expect(startButton.onPressed, isNotNull);
    });

    testWidgets('calls startCharge and shows success snackbar', (tester) async {
      chargingProvider.setStations([
        createMockStation(id: 's1', name: '朝阳充电站'),
      ]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Select station
      await tester.tap(find.text('朝阳充电站'));
      await tester.pumpAndSettle();

      // Add idle charger and select it
      chargingProvider.setChargers([
        createMockCharger(id: 'c1', chargerCode: 'CC-001', status: 'idle'),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CC-001'));
      await tester.pumpAndSettle();

      // Tap start charge
      await tester.tap(find.text('启动充电'));
      await tester.pumpAndSettle();

      expect(chargingProvider.startChargeCalled, isTrue);
      expect(chargingProvider.lastChargerId, 'c1');
      expect(find.text('充电已启动'), findsOneWidget);
    });

    testWidgets('shows stop charge button when charging in progress', (tester) async {
      // Set simulating an active charge
      chargingProvider.setCurrentRecord(createMockChargeRecord(
        id: 'record1',
        status: 'processing',
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show stop charge button instead of start
      expect(find.text('结束充电'), findsOneWidget);
      expect(find.text('当前充电信息'), findsOneWidget);
      expect(find.textContaining('25.5 kWh'), findsOneWidget);
      expect(find.textContaining('35.0 元'), findsOneWidget);
    });

    testWidgets('calls stopCharge and shows success snackbar', (tester) async {
      chargingProvider.setCurrentRecord(createMockChargeRecord(
        id: 'record1',
        status: 'processing',
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('结束充电'));
      await tester.pumpAndSettle();

      expect(chargingProvider.stopChargeCalled, isTrue);
      expect(chargingProvider.lastRecordId, 'record1');
      expect(find.text('充电已结束'), findsOneWidget);
    });

    testWidgets('shows error snackbar when startCharge fails', (tester) async {
      chargingProvider.setStations([
        createMockStation(id: 's1', name: '朝阳充电站'),
      ]);
      chargingProvider.setChargeError(Exception('余额不足'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Select station and charger
      await tester.tap(find.text('朝阳充电站'));
      await tester.pumpAndSettle();
      chargingProvider.setChargers([
        createMockCharger(id: 'c1', chargerCode: 'CC-001', status: 'idle'),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CC-001'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('启动充电'));
      await tester.pumpAndSettle();

      expect(find.textContaining('余额不足'), findsOneWidget);
    });
  });
}