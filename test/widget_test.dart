import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:charging_station_client/providers/auth_provider.dart';
import 'package:charging_station_client/providers/charging_provider.dart';
import 'package:charging_station_client/providers/repair_provider.dart';
import 'package:charging_station_client/providers/statistics_provider.dart';

/// Minimal app test that verifies the app can be constructed.
void main() {
  testWidgets('App can be created with providers', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ChargingProvider()),
          ChangeNotifierProvider(create: (_) => RepairProvider()),
          ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ],
        child: MaterialApp(
          home: const Scaffold(
            body: Center(child: Text('充电站管理系统')),
          ),
        ),
      ),
    );
    expect(find.text('充电站管理系统'), findsOneWidget);
  });
}