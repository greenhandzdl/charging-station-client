import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/statistics_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<StatisticsProvider>();
    provider.fetchUserChargeStats();
    provider.fetchStationAnalysis();
    provider.fetchChargerUtilization();
    provider.fetchFaultChargers();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StatisticsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('统计报表')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            provider.fetchUserChargeStats(),
            provider.fetchStationAnalysis(),
            provider.fetchChargerUtilization(),
            provider.fetchFaultChargers(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('用户充电统计（柱状图）', Icons.bar_chart),
            const SizedBox(height: 8),
            _buildUserChargeChart(provider, theme),
            const SizedBox(height: 24),

            _buildSectionTitle('运营分析', Icons.analytics),
            const SizedBox(height: 8),
            _buildStationAnalysis(provider, theme),
            const SizedBox(height: 24),

            _buildSectionTitle('充电桩使用率（饼图）', Icons.pie_chart),
            const SizedBox(height: 8),
            _buildUtilizationPieChart(provider, theme),
            const SizedBox(height: 24),

            _buildSectionTitle('故障充电桩', Icons.error_outline),
            const SizedBox(height: 8),
            _buildFaultChargers(provider, theme),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ],
    );
  }

  // ---- (a) User charge stats bar chart ----
  Widget _buildUserChargeChart(StatisticsProvider provider, ThemeData theme) {
    if (provider.loadingChargeStats) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.chargeStatsError != null) {
      return _buildErrorCard('加载失败: ${provider.chargeStatsError}', () {
        provider.fetchUserChargeStats();
      });
    }
    if (provider.chargeStats.isEmpty) {
      return _buildEmptyCard('暂无用户充电数据');
    }

    final stats = provider.chargeStats;
    // Sort by chargeCount descending for a cleaner chart
    stats.sort((a, b) => ((b['chargeCount'] as num?)?.toInt() ?? 0)
        .compareTo((a['chargeCount'] as num?)?.toInt() ?? 0));

    // Limit to top 12 to avoid overly crowded x-axis
    final displayStats = stats.take(12).toList();

    final maxChargeCount = displayStats
            .map((s) => (s['chargeCount'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a > b ? a : b);
    final maxFee = displayStats
            .map((s) => (s['totalFee'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a > b ? a : b);
    final maxY = maxChargeCount > maxFee ? maxChargeCount : maxFee;
    // Add 20% headroom
    final chartMaxY = maxY > 0 ? maxY * 1.2 : 10.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每次充电次数与总费用（元）',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMaxY,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final data = displayStats[group.x];
                        final name = data['userName']?.toString() ?? '';
                        if (rodIndex == 0) {
                          return BarTooltipItem(
                            '$name\n充电次数: ${rod.toY.toStringAsFixed(0)}',
                            const TextStyle(
                                color: Colors.white, fontSize: 12),
                          );
                        }
                        return BarTooltipItem(
                          '费用: ¥${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(
                              color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= displayStats.length) {
                            return const SizedBox.shrink();
                          }
                          final name =
                              displayStats[idx]['userName']?.toString() ?? '';
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              name.length > 4
                                  ? '${name.substring(0, 4)}..'
                                  : name,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          String text;
                          if (value >= 1000) {
                            text = '${(value / 1000).toStringAsFixed(1)}k';
                          } else {
                            text = value.toInt().toString();
                          }
                          return Text(text,
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY > 0 ? chartMaxY / 5 : 2,
                  ),
                  barGroups: List.generate(displayStats.length, (i) {
                    final data = displayStats[i];
                    final count =
                        (data['chargeCount'] as num?)?.toDouble() ?? 0;
                    final fee =
                        (data['totalFee'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: count,
                          color: theme.primaryColor,
                          width: 10,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: fee,
                          color: Colors.orange,
                          width: 10,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(theme.primaryColor, '充电次数'),
                const SizedBox(width: 24),
                _legendDot(Colors.orange, '总费用（元）'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // ---- (b) Station analysis cards ----
  Widget _buildStationAnalysis(StatisticsProvider provider, ThemeData theme) {
    if (provider.loadingStationAnalysis) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.stationAnalysisError != null) {
      return _buildErrorCard('加载失败: ${provider.stationAnalysisError}', () {
        provider.fetchStationAnalysis();
      });
    }
    if (provider.stationAnalysis.isEmpty) {
      return _buildEmptyCard('暂无运营数据');
    }

    return Column(
      children: provider.stationAnalysis.map((s) {
        final stationName = s['stationName']?.toString() ?? '未知站点';
        final totalCharges = (s['totalCharges'] as num?)?.toInt() ?? 0;
        final totalRevenue = (s['totalRevenue'] as num?)?.toDouble() ?? 0.0;
        final totalEnergy = (s['totalEnergy'] as num?)?.toDouble() ?? 0.0;
        final totalChargers = (s['totalChargers'] as num?)?.toInt() ?? 0;
        final idleChargers = (s['idleChargers'] as num?)?.toInt() ?? 0;
        final chargingChargers =
            (s['chargingChargers'] as num?)?.toInt() ?? 0;
        final faultChargers =
            (s['faultChargers'] as num?)?.toInt() ?? 0;
        final utilizationRate =
            (s['utilizationRate'] as num?)?.toDouble() ?? 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.ev_station, color: Colors.teal),
            title: Text(stationName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '充电次数: $totalCharges | 收入: ¥${_fmtMoney(totalRevenue)}',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _metricRow('充电桩总数', '$totalChargers'),
                    const Divider(height: 1),
                    _metricRow('空闲桩数', '$idleChargers',
                        valueColor: Colors.green),
                    const Divider(height: 1),
                    _metricRow('使用中', '$chargingChargers',
                        valueColor: Colors.blue),
                    const Divider(height: 1),
                    _metricRow('故障桩数', '$faultChargers',
                        valueColor:
                            faultChargers > 0 ? Colors.red : Colors.green),
                    const Divider(height: 1),
                    _metricRow('使用率',
                        '${utilizationRate.toStringAsFixed(1)}%'),
                    const Divider(height: 1),
                    _metricRow('总充电量', '${_fmtEnergy(totalEnergy)} kWh'),
                    const Divider(height: 1),
                    _metricRow('总收入', '¥${_fmtMoney(totalRevenue)}',
                        valueColor: Colors.orange),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _metricRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }

  // ---- (c) Charger utilization pie chart ----
  Widget _buildUtilizationPieChart(
      StatisticsProvider provider, ThemeData theme) {
    if (provider.loadingUtilization) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.utilizationError != null) {
      return _buildErrorCard('加载失败: ${provider.utilizationError}', () {
        provider.fetchChargerUtilization();
      });
    }

    final total =
        provider.idleCount + provider.chargingCount + provider.faultCount;
    if (total == 0) {
      return _buildEmptyCard('暂无充电桩使用率数据');
    }

    const idleColor = Colors.green;
    const chargingColor = Colors.blue;
    const faultColor = Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: idleColor,
                      value: provider.idlePercent,
                      title:
                          '${provider.idlePercent.toStringAsFixed(1)}%\n空闲',
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      radius: 60,
                    ),
                    PieChartSectionData(
                      color: chargingColor,
                      value: provider.chargingPercent,
                      title:
                          '${provider.chargingPercent.toStringAsFixed(1)}%\n使用中',
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      radius: 60,
                    ),
                    PieChartSectionData(
                      color: faultColor,
                      value: provider.faultPercent > 0
                          ? provider.faultPercent
                          : 0,
                      title: provider.faultPercent > 0
                          ? '${provider.faultPercent.toStringAsFixed(1)}%\n故障'
                          : '0%',
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      radius: 60,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(idleColor, '空闲 ${provider.idleCount}台'),
                const SizedBox(width: 16),
                _legendDot(chargingColor, '使用中 ${provider.chargingCount}台'),
                const SizedBox(width: 16),
                _legendDot(faultColor, '故障 ${provider.faultCount}台'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- (d) Fault chargers list ----
  Widget _buildFaultChargers(StatisticsProvider provider, ThemeData theme) {
    if (provider.loadingFaultChargers) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.faultChargersError != null) {
      return _buildErrorCard(
          '加载失败: ${provider.faultChargersError}', () {
        provider.fetchFaultChargers();
      });
    }
    if (provider.faultChargers.isEmpty) {
      return _buildEmptyCard('暂无故障充电桩');
    }

    return Column(
      children: provider.faultChargers.map((f) {
        final code = f['chargerCode']?.toString() ?? '';
        final stationName = f['stationName']?.toString() ?? '';
        final chargerType = f['chargerType']?.toString() ?? '';
        final status = f['status']?.toString() ?? '';
        final lastFaultTime = f['lastFaultTime']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading:
                const Icon(Icons.error, color: Colors.red, size: 28),
            title: Row(
              children: [
                Text(code,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 11, color: Colors.red.shade700)),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(stationName,
                        style: const TextStyle(fontSize: 12)),
                    if (chargerType.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.category,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(chargerType,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                if (lastFaultTime.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_formatTime(lastFaultTime),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---- Shared helpers ----
  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(message,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtMoney(double value) {
    return value.toStringAsFixed(2);
  }

  String _fmtEnergy(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}k';
    }
    return value.toStringAsFixed(1);
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}