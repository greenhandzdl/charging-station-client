import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class ChargerStatusScreen extends StatefulWidget {
  const ChargerStatusScreen({super.key});

  @override
  State<ChargerStatusScreen> createState() => _ChargerStatusScreenState();
}

class _ChargerStatusScreenState extends State<ChargerStatusScreen> {
  final _searchController = TextEditingController();
  List<StationModel> _stations = [];
  List<ChargerModel> _chargers = [];
  bool _isSearching = false;
  bool _isLoadingChargers = false;
  String? _selectedStationId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchStations() async {
    final name = _searchController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入充电站名称')),
      );
      return;
    }
    setState(() {
      _isSearching = true;
      _stations = [];
      _chargers = [];
      _selectedStationId = null;
    });
    try {
      final results = await ApiService.searchStations(name);
      if (mounted) {
        setState(() => _stations = results);
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到匹配的充电站')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查询失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadChargers(String stationId) async {
    setState(() {
      _isLoadingChargers = true;
      _selectedStationId = stationId;
      _chargers = [];
    });
    try {
      final chargers = await ApiService.getChargers(stationId);
      if (mounted) setState(() => _chargers = chargers);
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

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'IDLE':
        return Colors.green;
      case 'CHARGING':
        return Colors.blue;
      case 'FAULT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'IDLE':
        return '空闲';
      case 'CHARGING':
        return '充电中';
      case 'FAULT':
        return '故障';
      default:
        return '未知';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('充电桩状态查询')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: '充电站名称',
                      hintText: '输入充电站名称搜索',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _searchStations(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchStations,
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('搜索'),
                ),
              ],
            ),
          ),
          // Station list
          if (_stations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('搜索结果',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._stations.map((station) => Card(
                        color: _selectedStationId == station.id
                            ? Colors.blue.shade50
                            : null,
                        child: ListTile(
                          title: Text(station.name),
                          subtitle: Text(station.location),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _loadChargers(station.id),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          // Charger status list
          if (_selectedStationId != null)
            Expanded(
              child: _isLoadingChargers
                  ? const Center(child: CircularProgressIndicator())
                  : _chargers.isEmpty
                      ? const Center(child: Text('该站点暂无充电桩'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _chargers.length,
                          itemBuilder: (_, i) {
                            final charger = _chargers[i];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  Icons.ev_station,
                                  color: _statusColor(charger.status),
                                  size: 32,
                                ),
                                title: Text('充电桩编号: ${charger.chargerCode}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('类型: ${_typeLabel(charger.type)}'),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _statusColor(charger.status),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _statusLabel(charger.status),
                                          style: TextStyle(
                                            color:
                                                _statusColor(charger.status),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
            ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'AC':
      case 'SLOW':
        return '交流慢充';
      case 'DC':
      case 'FAST':
        return '直流快充';
      case 'SUPER':
        return '超级快充';
      default:
        return type;
    }
  }
}