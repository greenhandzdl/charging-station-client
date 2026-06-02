import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/providers/charging_provider.dart';

void main() {
  group('ChargingProvider', () {
    test('initial state has empty stations and chargers', () {
      final provider = ChargingProvider();
      expect(provider.stations, isEmpty);
      expect(provider.chargers, isEmpty);
      expect(provider.currentRecord, isNull);
    });
  });
}