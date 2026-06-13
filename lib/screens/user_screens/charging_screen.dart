import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/charging_provider.dart';
import 'qr_scan_screen.dart';
import 'repair_screen.dart';

class ChargingScreen extends StatefulWidget {
  const ChargingScreen({super.key});

  @override
  State<ChargingScreen> createState() => _ChargingScreenState();
}

class _ChargingScreenState extends State<ChargingScreen> {
  StationModel? _selectedStation;
  ChargerModel? _selectedCharger;
  bool _isLoadingStations = false;
  bool _isLoadingChargers = false;
  bool _isCharging = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
    // 登录后从后端恢复活跃充电记录（支持多车恢复）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChargingProvider>().resumeFromBackend().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      await context.read<ChargingProvider>().fetchStations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载站点失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _loadChargers(String stationId) async {
    setState(() => _isLoadingChargers = true);
    try {
      await context.read<ChargingProvider>().fetchChargers(stationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载充电桩失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingChargers = false);
    }
  }

  Future<void> _startCharge() async {
    if (_selectedCharger == null) return;
    setState(() => _isCharging = true);
    try {
      await context
          .read<ChargingProvider>()
          .startCharge(_selectedCharger!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('充电已启动')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动充电失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCharging = false);
    }
  }

  Future<void> _stopCharge() async {
    final provider = context.read<ChargingProvider>();
    setState(() => _isCharging = true);
    // 停止所有活跃的充电模拟（支持多车辆）
    final sims = provider.activeSimulations.toList();
    if (sims.isEmpty) {
      // 回退到 currentRecord（兼容旧的单桩方式）
      if (provider.currentRecord != null) {
        try {
          await provider.stopCharge(provider.currentRecord!.id);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('结束充电失败: $e')),
            );
          }
          if (mounted) setState(() => _isCharging = false);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('充电已结束')),
          );
        }
        if (mounted) setState(() => _isCharging = false);
        return;
      }
      setState(() => _isCharging = false);
      return;
    }
    bool hasError = false;
    for (final sim in sims) {
      try {
        await provider.stopCharge(sim.recordId);
      } catch (e) {
        hasError = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${sim.chargerCode} 结束充电失败: $e')),
          );
        }
      }
    }
    if (!hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('充电已结束')),
      );
    }
    if (mounted) setState(() => _isCharging = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChargingProvider>();
    final currentRecord = provider.currentRecord;

    return Scaffold(
      appBar: AppBar(
        title: const Text('充电'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: '扫码充电',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScanScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStations,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('选择充电站',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoadingStations)
              const Center(child: CircularProgressIndicator())
            else
              ...provider.stations.map((station) => Card(
                    child: ListTile(
                      title: Text(station.name),
                      subtitle: Text('${station.location} | ${station.chargerCount}个桩'),
                      trailing: Text(station.status),
                      selected: _selectedStation?.id == station.id,
                      onTap: () {
                        setState(() {
                          _selectedStation = station;
                          _selectedCharger = null;
                        });
                        // 立即清空桩列表，避免重复显示
                        context.read<ChargingProvider>().clearChargers();
                        _loadChargers(station.id);
                      },
                    ),
                  )),
            if (_selectedStation != null) ...[
              const SizedBox(height: 16),
              const Text('选择充电桩',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_isLoadingChargers)
                const Center(child: CircularProgressIndicator())
              else
                ...provider.chargers.map((charger) => Card(
                      child: ListTile(
                        title: Text('${charger.chargerCode} (${charger.type})'),
                        subtitle: Row(
                          children: [
                            Text('状态: ${charger.status}'),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: charger.onlineStatus == 'ONLINE'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              charger.onlineStatus == 'ONLINE' ? '在线' : '离线',
                              style: TextStyle(
                                fontSize: 12,
                                color: charger.onlineStatus == 'ONLINE'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        selected: _selectedCharger?.id == charger.id,
                        enabled: charger.status == 'IDLE' &&
                            charger.onlineStatus == 'ONLINE',
                        onTap: charger.status == 'IDLE' &&
                                charger.onlineStatus == 'ONLINE'
                            ? () => setState(
                                    () => _selectedCharger = charger)
                            : null,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'repair') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RepairScreen(
                                    initialChargerId: charger.id,
                                    initialChargerCode: charger.chargerCode,
                                  ),
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'repair',
                              child: ListTile(
                                leading: Icon(Icons.build, size: 20),
                                title: Text('报修'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
            const SizedBox(height: 24),
            if (provider.isCharging)
              ElevatedButton.icon(
                onPressed: _isCharging ? null : _stopCharge,
                icon: const Icon(Icons.stop),
                label: Text(_isCharging ? '处理中...' : '结束充电'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              )
            else
              ElevatedButton.icon(
                onPressed: (_selectedCharger == null || _isCharging)
                    ? null
                    : _startCharge,
                icon: const Icon(Icons.play_arrow),
                label: Text(_isCharging ? '启动中...' : '启动充电'),
              ),
            // 本地实时模拟显示（支持多车辆）
            if (provider.activeSimulations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('实时充电状态',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ...provider.activeSimulations.map((sim) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('充电桩: ${sim.chargerCode}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          _infoRow('类型', sim.type),
                          _infoRow('功率', sim.powerText),
                          _infoRow('时长', sim.durationText),
                          _infoRow('用电量', sim.energyText),
                          _infoRow('费用', sim.feeText),
                        ],
                      ),
                    ),
                  )),
            ],
            if (currentRecord != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('当前充电信息',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      _infoRow('状态', currentRecord.status),
                      _infoRow('电量', '${currentRecord.energyKwh} kWh'),
                      _infoRow('费用', '${currentRecord.fee} 元'),
                      if (currentRecord.startTime.isNotEmpty)
                        _infoRow('开始时间', currentRecord.startTime),
                      if (currentRecord.endTime.isNotEmpty)
                        _infoRow('结束时间', currentRecord.endTime),
                      if (currentRecord.chargerCode != null)
                        _infoRow('充电桩', currentRecord.chargerCode!),
                      if (currentRecord.stationName != null)
                        _infoRow('站点', currentRecord.stationName!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}