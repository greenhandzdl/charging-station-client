import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ChargingStationApp());
    await tester.pump();
    await tester.pump();

    // The app should render the ChargingStationApp
    expect(find.byType(ChargingStationApp), findsOneWidget);
  });
}