import 'package:flutter/material.dart';
import '../../models/station_model.dart';
import '../../models/charger_model.dart';
import '../../services/api_service.dart';

class StationChargerManagementScreen extends StatefulWidget {
  const StationChargerManagementScreen({super.key});

  @override
  State<StationChargerManagementScreen> createState() =>
      _StationChargerManagementScreenState();
}

class _StationChargerManagementScreenState
    extends State<StationChargerManagementScreen> {
  List<StationModel> _stations = [];
  Map<String, List<ChargerModel>> _chargersMap = {};
  Map<String, List<Map<String, dynamic>>> _chargerUsersMap = {}; // stationId -> [charger_users]
  bool _isLoading = false;
  final Set<String> _loadingStations = {}; // prevent concurrent reload
  String _searchQuery = '';
  String? _expandedStationId;
  String? _editChargerDeviceType;
  double? _editChargerRatedPowerKw;
  String? _editChargerManufacturer;
  String? _editChargerModel;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    try {
      _stations = await ApiService.getStations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChargers(String stationId) async {
    if (_loadingStations.contains(stationId)) return;
    _loadingStations.add(stationId);
    try {
      final chargers = await ApiService.getChargers(stationId);
      _chargersMap[stationId] = chargers;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载充电桩失败: $e')),
        );
      }
    } finally {
      _loadingStations.remove(stationId);
    }
  }

  Future<void> _loadChargerUsers(String stationId) async {
    try {
      final users = await ApiService.getChargerUsers(stationId);
      _chargerUsersMap[stationId] = users;
    } catch (_) {
      // charger_users 加载失败不阻塞 UI
    }
  }

  void _toggleExpand(String stationId) {
    if (_expandedStationId == stationId) {
      setState(() => _expandedStationId = null);
    } else {
      setState(() {
        _expandedStationId = stationId;
        _chargersMap[stationId] = []; // 立即清空避免重复
        _chargerUsersMap[stationId] = [];
      });
      _loadChargers(stationId);
      _loadChargerUsers(stationId);
    }
  }

  // ---- Display items ----
  List<dynamic> _getDisplayItems() {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) {
      // Browse mode: only return stations.
      // Chargers are rendered as children inside _buildStationExpansionTile.
      return _stations;
    } else {
      // Search mode: mixed flat list with type labels
      final items = <dynamic>[];
      for (final station in _stations) {
        final stationMatch = station.name.toLowerCase().contains(query) ||
            station.location.toLowerCase().contains(query);
        if (stationMatch) items.add(station);
      }
      for (final station in _stations) {
        final chargers = _chargersMap[station.id] ?? [];
        for (final charger in chargers) {
          if (charger.chargerCode.toLowerCase().contains(query)) {
            items.add(_SearchChargerResult(
              charger: charger,
              stationName: station.name,
            ));
          }
        }
      }
      return items;
    }
  }

  // ---- Station CRUD ----
  Future<void> _showStationForm(StationModel? existing) async {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final locationController =
        TextEditingController(text: existing?.location ?? '');
    String status = existing?.status ?? 'NORMAL';
    bool isSaving = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(existing != null ? '编辑充电站' : '新增充电站'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '充电站名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: '地址',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: '状态',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'NORMAL', child: Text('正常')),
                        DropdownMenuItem(
                            value: 'MAINTENANCE',
                            child: Text('维护中')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => status = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final location =
                              locationController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('名称不能为空')),
                            );
                            return;
                          }
                          if (location.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('地址不能为空')),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final data = <String, dynamic>{
                              'name': name,
                              'location': location,
                              'status': status,
                            };
                            if (existing != null) {
                              await ApiService.updateStation(
                                  existing.id, data);
                            } else {
                              await ApiService.createStation(data);
                            }
                            await _loadStations();
                            _chargersMap.clear();
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(existing != null
                                      ? '充电站已更新'
                                      : '充电站已创建'),
                                ),
                              );
                            }
                            Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('保存失败: $e')),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStation(StationModel station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除充电站 ${station.name} 吗？\n该操作将同时删除该站下的所有充电桩。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteStation(station.id);
      _chargersMap.remove(station.id);
      if (_expandedStationId == station.id) {
        _expandedStationId = null;
      }
      await _loadStations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('充电站已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  // ---- Charger CRUD ----
  Future<void> _showChargerForm(
      StationModel station, ChargerModel? existing) async {
    final codeController =
        TextEditingController(text: existing?.chargerCode ?? '');
    final onlineStatusController = TextEditingController(
      text: existing != null
          ? (existing.onlineStatus == 'ONLINE' ? '在线' : '离线')
          : '离线（上线后自动更新）',
    );
    String type = existing?.type ?? 'SLOW';
    String status = existing?.status ?? 'IDLE';
    String deviceType = existing?.deviceType ?? 'SIMULATED';
    double? ratedPowerKw = existing?.ratedPowerKw;
    String? manufacturer = existing?.manufacturer;
    String? model = existing?.model;
    bool isSaving = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing != null ? '编辑充电桩' : '新增充电桩'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: '充电桩编号',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: '类型',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'SLOW', child: Text('交流慢充')),
                        DropdownMenuItem(
                            value: 'FAST', child: Text('直流快充')),
                        DropdownMenuItem(
                            value: 'SUPER', child: Text('超级快充')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => type = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: '状态',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'IDLE', child: Text('空闲')),
                        DropdownMenuItem(
                            value: 'CHARGING', child: Text('充电中')),
                        DropdownMenuItem(
                            value: 'FAULT', child: Text('故障')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => status = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: onlineStatusController,
                      decoration: const InputDecoration(
                        labelText: '在线状态',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sensors),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: deviceType,
                      decoration: const InputDecoration(
                        labelText: '设备类型',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'SIMULATED', child: Text('模拟充电桩')),
                        DropdownMenuItem(
                            value: 'REAL', child: Text('真实环境充电桩')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => deviceType = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '额定功率 (kW)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: ratedPowerKw?.toString() ?? '',
                      onChanged: (v) =>
                          ratedPowerKw = double.tryParse(v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '制造商',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: manufacturer ?? '',
                      onChanged: (v) => manufacturer = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '型号',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: model ?? '',
                      onChanged: (v) => model = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('编号不能为空')),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final data = <String, dynamic>{
                              'chargerCode': code,
                              'type': type,
                              'status': status,
                              'stationId': station.id,
                              'deviceType': deviceType,
                              if (ratedPowerKw != null)
                                'ratedPowerKw': ratedPowerKw,
                              if (manufacturer != null && manufacturer!.isNotEmpty)
                                'manufacturer': manufacturer,
                              if (model != null && model!.isNotEmpty)
                                'model': model,
                            };
                            if (existing != null) {
                              await ApiService.updateCharger(
                                  existing.id, data);
                            } else {
                              await ApiService.createCharger(data);
                            }
                            await _loadChargers(station.id);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(existing != null
                                      ? '充电桩已更新'
                                      : '充电桩已创建'),
                                ),
                              );
                            }
                            Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('保存失败: $e')),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCharger(
      StationModel station, ChargerModel charger) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除充电桩 ${charger.chargerCode} 吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteCharger(charger.id);
      await _loadChargers(station.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('充电桩已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _resetChargerToken(
      {ChargerModel? charger, StationModel? station}) async {
    try {
      final stationId = charger?.stationId ?? station?.id;
      if (stationId == null) return;

      // Ensure charger users are loaded for this station
      if (!_chargerUsersMap.containsKey(stationId) ||
          (_chargerUsersMap[stationId]?.isEmpty ?? true)) {
        await _loadChargerUsers(stationId);
      }

      final users = _chargerUsersMap[stationId] ?? [];
      Map<String, dynamic>? cu;

      if (charger != null) {
        // Find specific charger user
        cu = users.cast<Map<String, dynamic>?>().firstWhere(
              (u) => u!['chargerId'] == charger.id,
              orElse: () => null,
            );
      } else if (station != null) {
        // Find station-level user (permissionLevel == 'STATION')
        cu = users.cast<Map<String, dynamic>?>().firstWhere(
              (u) =>
                  u!['stationId'] == station.id &&
                  u['permissionLevel'] == 'STATION',
              orElse: () => null,
            );
      }

      if (cu == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(charger != null
                    ? '未找到该充电桩的设备身份'
                    : '未找到该充电站的设备身份')),
          );
        }
        return;
      }

      final result = await ApiService.resetChargerToken(cu['id']);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(charger != null ? '充电桩 Token 已重置' : '充电站 Token 已重置'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('名称: ${cu!['name']}'),
                const SizedBox(height: 8),
                const Text('新 Token (请复制保存):'),
                const SizedBox(height: 4),
                SelectableText(
                  '${result['newToken']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置Token失败: $e')),
        );
      }
    }
  }

  // ---- Helpers ----
  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'NORMAL':
        return Colors.green;
      case 'MAINTENANCE':
        return Colors.orange;
      case 'FAULT':
        return Colors.red;
      case 'IDLE':
        return Colors.green;
      case 'CHARGING':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'NORMAL':
        return '正常';
      case 'MAINTENANCE':
        return '维护中';
      case 'FAULT':
        return '故障';
      case 'IDLE':
        return '空闲';
      case 'CHARGING':
        return '充电中';
      case 'ONLINE':
        return '在线';
      case 'OFFLINE':
        return '离线';
      default:
        return status;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'SLOW':
        return '慢充';
      case 'FAST':
        return '快充';
      case 'SUPER':
        return '超充';
      default:
        return type;
    }
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    final displayItems = _getDisplayItems();
    final isSearchMode = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('充电站/充电桩管理')),
      body: RefreshIndicator(
        onRefresh: _loadStations,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索充电站名称、地址或充电桩编号',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    if (value.trim().isNotEmpty) {
                      // Preload all chargers for search mode
                      _preloadAllChargers();
                    }
                  });
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayItems.isEmpty
                      ? ListView(
                          children: const [
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('暂无数据'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: displayItems.length,
                          itemBuilder: (_, i) {
                            final item = displayItems[i];
                            if (item is StationModel) {
                              if (isSearchMode) {
                                return _buildSearchStationCard(item);
                              }
                              return _buildStationExpansionTile(item);
                            } else if (item is ChargerModel) {
                              return _buildChargerRow(
                                  item, item.stationName ?? '');
                            } else if (item is _SearchChargerResult) {
                              return _buildChargerRow(
                                  item.charger, item.stationName);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Future<void> _preloadAllChargers() async {
    for (final station in _stations) {
      if (!_chargersMap.containsKey(station.id)) {
        _loadChargers(station.id);
      }
    }
  }

  Widget? _buildFab() {
    if (_searchQuery.trim().isNotEmpty) return null;

    // Browse mode: if a station is expanded, add charger to that station
    if (_expandedStationId != null) {
      final station = _stations.cast<StationModel?>().firstWhere(
          (s) => s!.id == _expandedStationId,
          orElse: () => null);
      if (station != null) {
        return FloatingActionButton(
          heroTag: 'add_charger',
          onPressed: () async {
            await _showChargerForm(station, null);
          },
          child: const Icon(Icons.add),
        );
      }
    }

    return FloatingActionButton(
      heroTag: 'add_station',
      onPressed: () => _showStationForm(null),
      child: const Icon(Icons.add),
    );
  }

  // ---- Station expandable card (browse mode) ----
  Widget _buildStationExpansionTile(StationModel station) {
    final chargers = _chargersMap[station.id] ?? [];
    final isExpanded = _expandedStationId == station.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            title: Row(
              children: [
                Expanded(child: Text(station.name)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(station.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _statusLabel(station.status),
                    style: TextStyle(
                      fontSize: 11,
                      color: _statusColor(station.status),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
                '${station.location} | ${station.chargerCount}个桩'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _showStationForm(station);
                if (v == 'delete') _deleteStation(station);
                if (v == 'reset_token') _resetChargerToken(station: station);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, size: 20),
                    title: Text('编辑'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_token',
                  child: ListTile(
                    leading: Icon(Icons.refresh, size: 20, color: Colors.orange),
                    title:
                        Text('重置Token', style: TextStyle(color: Colors.orange)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, size: 20, color: Colors.red),
                    title: Text('删除', style: TextStyle(color: Colors.red)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            onTap: () => _toggleExpand(station.id),
          ),
          if (isExpanded) ...[
            if (!_chargersMap.containsKey(station.id))
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (chargers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无充电桩'),
              )
            else
              ...chargers.map((charger) => _buildChargerRow(
                    charger,
                    station.name,
                    indent: true,
                  )),
          ],
        ],
      ),
    );
  }

  // ---- Station card in search mode ----
  Widget _buildSearchStationCard(StationModel station) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: const Icon(Icons.ev_station, color: Colors.blue),
        title: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '充电站',
                style: TextStyle(fontSize: 10, color: Colors.blue),
              ),
            ),
            Expanded(child: Text(station.name)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(station.status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _statusLabel(station.status),
                style: TextStyle(
                  fontSize: 11,
                  color: _statusColor(station.status),
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
            '${station.location} | ${station.chargerCount}个桩'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showStationForm(station);
            if (v == 'delete') _deleteStation(station);
            if (v == 'reset_token') _resetChargerToken(station: station);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, size: 20),
                title: Text('编辑'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'reset_token',
              child: ListTile(
                leading: Icon(Icons.refresh, size: 20, color: Colors.orange),
                title: Text('重置Token', style: TextStyle(color: Colors.orange)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, size: 20, color: Colors.red),
                title: Text('删除', style: TextStyle(color: Colors.red)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Charger row ----
  Widget _buildChargerRow(ChargerModel charger, String stationName,
      {bool indent = false}) {
    // Find the parent station
    final parentStation = _stations.cast<StationModel?>().firstWhere(
        (s) => s!.id == charger.stationId,
        orElse: () => null);

    return Card(
      margin: EdgeInsets.only(
        left: indent ? 32 : 0,
        bottom: 4,
        right: 0,
      ),
      child: ListTile(
        dense: indent,
        leading: Icon(
          charger.type == 'FAST'
              ? Icons.flash_on
              : charger.type == 'SUPER'
                  ? Icons.bolt
                  : Icons.battery_charging_full,
          size: 20,
          color: charger.status == 'IDLE' ? Colors.green : Colors.grey,
        ),
        title: Row(
          children: [
            if (!indent)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '充电桩',
                  style: TextStyle(fontSize: 10, color: Colors.teal),
                ),
              ),
            Text('${charger.chargerCode} (${_typeLabel(charger.type)})'),
          ],
        ),
        subtitle: Row(
          children: [
            Text('${_statusLabel(charger.status)}'),
            const Text(' | '),
            Icon(
              charger.onlineStatus == 'ONLINE'
                  ? Icons.wifi
                  : Icons.wifi_off,
              size: 14,
              color: charger.onlineStatus == 'ONLINE'
                  ? Colors.green
                  : Colors.grey,
            ),
            const SizedBox(width: 2),
            Text(
              charger.onlineStatus == 'ONLINE' ? '在线' : '离线',
              style: TextStyle(
                fontSize: 12,
                color: charger.onlineStatus == 'ONLINE'
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
            if (parentStation != null) ...[
              const Text(' | '),
              Text(parentStation.name,
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final station = parentStation;
            if (station == null) return;
            if (v == 'edit') _showChargerForm(station, charger);
            if (v == 'delete') _deleteCharger(station, charger);
            if (v == 'reset_token') _resetChargerToken(charger: charger);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, size: 20),
                title: Text('编辑'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'reset_token',
              child: ListTile(
                leading: Icon(Icons.refresh, size: 20, color: Colors.orange),
                title: Text('重置Token', style: TextStyle(color: Colors.orange)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading:
                    Icon(Icons.delete, size: 20, color: Colors.red),
                title:
                    Text('删除', style: TextStyle(color: Colors.red)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal wrapper for search results to carry station name alongside charger.
class _SearchChargerResult {
  final ChargerModel charger;
  final String stationName;
  _SearchChargerResult({required this.charger, required this.stationName});
}