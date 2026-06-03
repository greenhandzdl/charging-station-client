import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/charging_provider.dart';

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

  // QR scan / manual input mode
  bool _useQrMode = false;
  final _chargerIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _chargerIdController.dispose();
    super.dispose();
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

  /// Start charge via chargerId (from QR scan or manual input or station list)
  Future<void> _startCharge(String chargerId) async {
    setState(() => _isCharging = true);
    try {
      await context.read<ChargingProvider>().startCharge(chargerId);
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
    final record = provider.currentRecord;
    if (record == null) return;
    setState(() => _isCharging = true);
    try {
      await provider.stopCharge(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('充电已结束')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('结束充电失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCharging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChargingProvider>();
    final currentRecord = provider.currentRecord;

    return Scaffold(
      appBar: AppBar(
        title: const Text('充电'),
        actions: [
          // Toggle between station list mode and QR scan mode
          IconButton(
            icon: Icon(_useQrMode ? Icons.ev_station : Icons.qr_code),
            tooltip: _useQrMode ? '切换至站点列表' : '扫码/输入充电桩ID',
            onPressed: () => setState(() => _useQrMode = !_useQrMode),
          ),
        ],
      ),
      body: _useQrMode ? _buildQrMode() : _buildStationMode(provider, currentRecord),
    );
  }

  /// QR scan / manual input mode — for Mock charger interaction
  Widget _buildQrMode() {
    final provider = context.read<ChargingProvider>();
    final currentRecord = provider.currentRecord;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '使用 Mock 充电机上的二维码，\n或手动输入充电桩ID以启动充电',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Charger ID input
          TextField(
            controller: _chargerIdController,
            decoration: const InputDecoration(
              labelText: '充电桩ID / 编码',
              hintText: '扫码或手动输入充电桩ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code_scanner),
              helperText: 'Mock 充电机插枪后会在屏幕上显示二维码',
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 24),

          // Start charge button
          FilledButton.icon(
            onPressed: _isCharging
                ? null
                : () {
                    final id = _chargerIdController.text.trim();
                    if (id.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入充电桩ID')),
                      );
                      return;
                    }
                    _startCharge(id);
                  },
            icon: const Icon(Icons.play_arrow),
            label: Text(_isCharging ? '启动中...' : '启动充电'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),

          if (currentRecord != null && currentRecord.status == 'COMPLETED')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 40),
                      const SizedBox(height: 8),
                      Text('充电完成',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700)),
                      const SizedBox(height: 4),
                      Text('费用: ${currentRecord.fee} 元'),
                      Text('电量: ${currentRecord.energyKwh} kWh'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Standard station list mode
  Widget _buildStationMode(
      ChargingProvider provider, ChargeRecordModel? currentRecord) {
    return RefreshIndicator(
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
                    subtitle:
                        Text('${station.location} | ${station.chargerCount}个桩'),
                    trailing: Text(station.status),
                    selected: _selectedStation?.id == station.id,
                    onTap: () {
                      setState(() {
                        _selectedStation = station;
                        _selectedCharger = null;
                      });
                      _loadChargers(station.id);
                    },
                  ),
                )),
          if (_selectedStation != null) ...[
            const SizedBox(height: 16),
            const Text('选择充电桩',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoadingChargers)
              const Center(child: CircularProgressIndicator())
            else
              ...provider.chargers.map((charger) => Card(
                    child: ListTile(
                      title:
                          Text('${charger.chargerCode} (${charger.type})'),
                      subtitle: Text('状态: ${charger.status}'),
                      selected: _selectedCharger?.id == charger.id,
                      onTap: charger.status == 'IDLE'
                          ? () => setState(
                                  () => _selectedCharger = charger)
                          : null,
                    ),
                  )),
          ],
          const SizedBox(height: 24),

          // Charge control buttons
          if (currentRecord != null &&
              currentRecord.status == 'PROCESSING')
            ElevatedButton.icon(
              onPressed: _isCharging ? null : _stopCharge,
              icon: const Icon(Icons.stop),
              label: Text(_isCharging ? '处理中...' : '结束充电'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.red),
            )
          else
            ElevatedButton.icon(
              onPressed: (_selectedCharger == null || _isCharging)
                  ? null
                  : () => _startCharge(_selectedCharger!.id),
              icon: const Icon(Icons.play_arrow),
              label: Text(_isCharging ? '启动中...' : '启动充电'),
            ),

          // Current charge info card
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
                    const SizedBox(height: 8),
                    Text('状态: ${currentRecord.status}'),
                    Text('电量: ${currentRecord.energyKwh} kWh'),
                    Text('费用: ${currentRecord.fee} 元'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}