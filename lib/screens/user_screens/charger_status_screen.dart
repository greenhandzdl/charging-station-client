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
  bool _isLoading = false;
  bool _isSearchMode = false;
  String? _selectedStationId;

  @override
  void initState() {
    super.initState();
    _loadAllStations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllStations() async {
    setState(() => _isLoading = true);
    try {
      final allStations = await ApiService.getStations();
      if (mounted) {
        setState(() {
          _stations =
              allStations.where((s) => s.status != 'MAINTENANCE').toList();
          _isSearchMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载充电站失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      // Clear search and show all stations
      setState(() {
        _isSearchMode = false;
        _chargers = [];
        _selectedStationId = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _chargers = [];
      _selectedStationId = null;
    });

    try {
      // Search stations by name
      final stationResults = await ApiService.searchStations(query);
      // Filter out MAINTENANCE stations
      final filteredStations =
          stationResults.where((s) => s.status != 'MAINTENANCE').toList();

      // Search chargers across all stations — we do this by getting chargers
      // for each station and filtering by chargerCode
      final allStations = await ApiService.getStations();
      final allChargerResults = <ChargerModel>[];
      for (final station in allStations) {
        if (station.status == 'MAINTENANCE') continue;
        try {
          final chargers = await ApiService.getChargers(station.id);
          final matched = chargers
              .where((c) =>
                  c.chargerCode.toLowerCase().contains(query.toLowerCase()))
              .map((c) => ChargerModel(
                    id: c.id,
                    stationId: c.stationId,
                    chargerCode: c.chargerCode,
                    type: c.type,
                    status: c.status,
                    onlineStatus: c.onlineStatus,
                    stationName: station.name,
                    createdAt: c.createdAt,
                    updatedAt: c.updatedAt,
                  ))
              .toList();
          allChargerResults.addAll(matched);
        } catch (_) {
          // Skip stations that fail to load chargers
        }
      }

      if (mounted) {
        setState(() {
          _stations = filteredStations;
          _chargers = allChargerResults;
          _isSearchMode = true;
        });

        if (filteredStations.isEmpty && allChargerResults.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到匹配的结果')),
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
      _isLoading = true;
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
      if (mounted) setState(() => _isLoading = false);
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

  Color _onlineStatusColor(String onlineStatus) {
    switch (onlineStatus.toUpperCase()) {
      case 'ONLINE':
        return Colors.green;
      case 'OFFLINE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _onlineStatusLabel(String onlineStatus) {
    switch (onlineStatus.toUpperCase()) {
      case 'ONLINE':
        return '在线';
      case 'OFFLINE':
        return '离线';
      default:
        return '未知';
    }
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

  /// Build a charger status card
  Widget _buildChargerCard(ChargerModel charger, {bool showStationName = false}) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.ev_station,
          color: _statusColor(charger.status),
          size: 32,
        ),
        title: Row(
          children: [
            Text('充电桩: ${charger.chargerCode}'),
            if (showStationName && charger.stationName != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  charger.stationName!,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
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
                    color: _statusColor(charger.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.circle,
                  size: 10,
                  color: _onlineStatusColor(charger.onlineStatus),
                ),
                const SizedBox(width: 4),
                Text(
                  _onlineStatusLabel(charger.onlineStatus),
                  style: TextStyle(
                    fontSize: 12,
                    color: _onlineStatusColor(charger.onlineStatus),
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
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
                      labelText: '搜索',
                      hintText: '充电站名称或充电桩编号',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(_searchController.text),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSearching
                      ? null
                      : () => _search(_searchController.text),
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
          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _searchController.text.isEmpty && !_isSearchMode
                        ? _loadAllStations
                        : () => _search(_searchController.text),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Show charger results in search mode (mixed results)
                        if (_isSearchMode && _chargers.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('[充电桩]',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                          ),
                          ..._chargers
                              .map((c) => _buildChargerCard(c, showStationName: true)),
                          const SizedBox(height: 16),
                        ],
                        // Show station results
                        if (_stations.isNotEmpty) ...[
                          if (_isSearchMode || _chargers.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('[充电站]',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                            ),
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
                        // Show chargers for selected station (not search mode)
                        if (_selectedStationId != null &&
                            !_isSearchMode &&
                            _chargers.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('充电桩列表',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ),
                          ..._chargers
                              .map((c) => _buildChargerCard(c)),
                        ],
                        if (_stations.isEmpty && _chargers.isEmpty && !_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('暂无数据')),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}