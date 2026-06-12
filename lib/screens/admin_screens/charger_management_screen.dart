import 'package:flutter/material.dart';
import '../../models/station_model.dart';
import '../../models/charger_model.dart';
import '../../services/api_service.dart';

class ChargerManagementScreen extends StatefulWidget {
  const ChargerManagementScreen({super.key});

  @override
  State<ChargerManagementScreen> createState() =>
      _ChargerManagementScreenState();
}

class _ChargerManagementScreenState extends State<ChargerManagementScreen> {
  List<StationModel> _stations = [];
  List<ChargerModel> _chargers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  StationModel? _selectedStation;

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
    setState(() => _isLoading = true);
    try {
      _chargers = await ApiService.getChargers(stationId);
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

  List<ChargerModel> get _filteredChargers {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) return _chargers;
    return _chargers
        .where((c) => c.chargerCode.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _showChargerForm(ChargerModel? existing) async {
    final codeController =
        TextEditingController(text: existing?.chargerCode ?? '');
    final onlineStatusController = TextEditingController(
      text: existing != null
          ? (existing.onlineStatus == 'ONLINE' ? '在线' : '离线')
          : '离线（上线后自动更新）',
    );
    String type = existing?.type ?? 'SLOW';
    String status = existing?.status ?? 'IDLE';
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
                        DropdownMenuItem(value: 'SLOW', child: Text('交流慢充')),
                        DropdownMenuItem(value: 'FAST', child: Text('直流快充')),
                        DropdownMenuItem(value: 'SUPER', child: Text('超级快充')),
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
                        DropdownMenuItem(value: 'IDLE', child: Text('空闲')),
                        DropdownMenuItem(
                            value: 'CHARGING', child: Text('充电中')),
                        DropdownMenuItem(value: 'FAULT', child: Text('故障')),
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
                              const SnackBar(content: Text('编号不能为空')),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final data = <String, dynamic>{
                              'chargerCode': code,
                              'type': type,
                              'status': status,
                              'stationId': _selectedStation!.id,
                            };
                            if (existing != null) {
                              await ApiService.updateCharger(
                                  existing.id, data);
                            } else {
                              await ApiService.createCharger(data);
                            }
                            await _loadChargers(_selectedStation!.id);
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

  Future<void> _deleteCharger(ChargerModel charger) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除充电桩 ${charger.chargerCode} 吗？'),
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
      await _loadChargers(_selectedStation!.id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('充电桩管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButtonFormField<StationModel>(
              decoration: const InputDecoration(
                labelText: '选择充电站',
                contentPadding: EdgeInsets.all(16),
                border: OutlineInputBorder(),
              ),
              items: _stations
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (station) {
                if (station != null) {
                  setState(() {
                    _selectedStation = station;
                    _searchQuery = '';
                  });
                  _loadChargers(station.id);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索充电桩编号',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChargers.isEmpty
                    ? const Center(child: Text('暂无充电桩数据'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredChargers.length,
                        itemBuilder: (_, i) {
                          final c = _filteredChargers[i];
                          return Card(
                            child: ListTile(
                              title: Text('${c.chargerCode} (${c.type})'),
                              subtitle: Text(
                                  '状态: ${c.status} | ${c.onlineStatus == "ONLINE" ? "在线" : "离线"}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    _showChargerForm(c);
                                  }
                                  if (v == 'delete') {
                                    _deleteCharger(c);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading:
                                          Icon(Icons.edit, size: 20),
                                      title: Text('编辑'),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete,
                                          size: 20, color: Colors.red),
                                      title: Text('删除',
                                          style: TextStyle(
                                              color: Colors.red)),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _selectedStation != null
          ? FloatingActionButton(
              onPressed: () => _showChargerForm(null),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}