import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/screens/admin_screens/statistics_screen.dart';
import '../../test_helpers.dart';

void main() {
  group('StatisticsScreen', () {
    testWidgets('renders all 4 section titles', (tester) async {
      final statsProvider = MockStatisticsProvider();

      await tester.pumpWidget(wrapWithProviders(
        statisticsProvider: statsProvider,
        child: const StatisticsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('用户充电统计'), findsOneWidget);
      expect(find.text('运营分析'), findsOneWidget);
      expect(find.text('充电桩使用率'), findsOneWidget);
      expect(find.text('故障充电桩'), findsOneWidget);
    });

    testWidgets('shows empty state for each section', (tester) async {
      final statsProvider = MockStatisticsProvider();

      await tester.pumpWidget(wrapWithProviders(
        statisticsProvider: statsProvider,
        child: const StatisticsScreen(),
      ));
      await tester.pumpAndSettle();

      // Each section shows "暂无数据" when empty
      expect(find.text('暂无数据'), findsNWidgets(2)); // chargeStats and stationAnalysis
      expect(find.text('暂无故障桩'), findsOneWidget);
    });

    testWidgets('shows charge stats list when data is loaded', (tester) async {
      final statsProvider = MockStatisticsProvider();
      statsProvider.setChargeStats([
        {'userName': '张三', 'count': 5},
        {'userName': '李四', 'count': 3},
      ]);

      await tester.pumpWidget(wrapWithProviders(
        statisticsProvider: statsProvider,
        child: const StatisticsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('张三'), findsOneWidget);
      expect(find.text('李四'), findsOneWidget);
    });

    testWidgets('shows station analysis when data is loaded', (tester) async {
      final statsProvider = MockStatisticsProvider();
      statsProvider.setStationAnalysis([
        {'stationName': '朝阳站', 'totalKwh': 100},
      ]);

      await tester.pumpWidget(wrapWithProviders(
        statisticsProvider: statsProvider,
        child: const StatisticsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('朝阳站'), findsOneWidget);
      expect(find.textContaining('100'), findsOneWidget);
    });

    testWidgets('shows utilization data', (tester) async {
      final statsProvider = MockStatisticsProvider();
      statsProvider.setUtilization({
        'idle': 50,
        'charging': 30,
        'fault': 20,
      });

      await tester.pumpWidget(wrapWithProviders(
        statisticsProvider: statsProvider,
        child: const StatisticsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('50'), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
      expect(find.textContaining('20'), findsOneWidget);
    });

    testWidgets('shows fault charger list', (tester) async {
      final statsProvider = MockStatisticsProvider();
      statsProvider.setFaultChargers([
        {'chargerCode': 'CC-001', 'stationName': '朝阳站'},
      ]);

      await tester.pumpWidget(wrapWithProviders(
        statisticsProvider: statsProvider,
        child: const StatisticsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CC-001'), findsOneWidget);
      expect(find.text('朝阳站'), findsOneWidget);
    });
  });
}