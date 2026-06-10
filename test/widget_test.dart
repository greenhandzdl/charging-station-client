import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/main.dart';

void main() {
  testWidgets('ChargingStationApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ChargingStationApp());
    // Pump several frames for async auth check to resolve
    await tester.pump();
    await tester.pump();

    // The app should render the AuthGate which shows either login or home
    expect(find.byType(ChargingStationApp), findsOneWidget);
  });
}