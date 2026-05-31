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
  StationModel? _selectedStation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    try {
      final stations = await ApiService.getStations();
      _stations = stations;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载充电站列表失败: $e')),
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
          SnackBar(content: Text('加载充电桩列表失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCharger(ChargerModel? existing, String stationId,
      String chargerCode, String type, String status) async {
    final data = {
      'stationId': stationId,
      'chargerCode': chargerCode,
      'type': type,
      'status': status,
    };
    try {
      if (existing == null) {
        await ApiService.createCharger(data);
      } else {
        await ApiService.updateCharger(existing.id, data);
      }
      await _loadChargers(stationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? '充电桩已添加' : '充电桩已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteCharger(ChargerModel charger) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content:
            Text('确定要删除充电桩 "${charger.chargerCode}" 吗？此操作不可恢复。'),
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
      if (_selectedStation != null) {
        await _loadChargers(_selectedStation!.id);
      }
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

  void _showChargerForm(ChargerModel? existing) {
    final codeController =
        TextEditingController(text: existing?.chargerCode ?? '');
    String selectedType = existing?.type ?? 'slow';
    String selectedStatus = existing?.status ?? 'active';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(existing == null ? '添加充电桩' : '编辑充电桩'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<StationModel>(
                      initialValue: _selectedStation,
                      decoration: const InputDecoration(
                        labelText: '所属充电站',
                        border: OutlineInputBorder(),
                      ),
                      items: _stations
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) {
                        // station is fixed for the form
                      },
                      disabledHint:
                          Text(_selectedStation?.name ?? '请先选择充电站'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: '充电桩编号',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: '类型',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'fast', child: Text('快充')),
                        DropdownMenuItem(value: 'slow', child: Text('慢充')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: '状态',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('启用')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('停用')),
                        DropdownMenuItem(
                            value: 'fault', child: Text('故障')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedStatus = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final code = codeController.text.trim();
                    if (_selectedStation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先选择充电站')),
                      );
                      return;
                    }
                    if (code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入充电桩编号')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _saveCharger(
                        existing,
                        _selectedStation!.id,
                        code,
                        selectedType,
                        selectedStatus);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'fast':
        return '快充';
      case 'slow':
        return '慢充';
      default:
        return type;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return '启用';
      case 'inactive':
        return '停用';
      case 'fault':
        return '故障';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'fault':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'fast':
        return Colors.orange;
      case 'slow':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('充电桩管理')),
      floatingActionButton: _selectedStation != null
          ? FloatingActionButton(
              onPressed: () => _showChargerForm(null),
              tooltip: '添加充电桩',
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStations();
          if (_selectedStation != null) {
            await _loadChargers(_selectedStation!.id);
          }
        },
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<StationModel>(
                initialValue: _selectedStation,
                decoration: const InputDecoration(
                  labelText: '选择充电站',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                hint: const Text('请选择充电站'),
                items: _stations
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (station) {
                  if (station != null) {
                    setState(() => _selectedStation = station);
                    _loadChargers(station.id);
                  }
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedStation == null
                      ? ListView(
                          children: const [
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('请先选择充电站'),
                              ),
                            ),
                          ],
                        )
                      : _chargers.isEmpty
                          ? ListView(
                              children: const [
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Text('该充电站暂无充电桩'),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _chargers.length,
                              itemBuilder: (_, i) {
                                final c = _chargers[i];
                                return Dismissible(
                                  key: ValueKey(c.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: Colors.red,
                                    child: const Icon(Icons.delete,
                                        color: Colors.white),
                                  ),
                                  confirmDismiss: (_) async {
                                    await _deleteCharger(c);
                                    return false;
                                  },
                                  child: Card(
                                    child: ListTile(
                                      title: Row(
                                        children: [
                                          Text(c.chargerCode,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _typeColor(c.type)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              _typeLabel(c.type),
                                              style: TextStyle(
                                                color: _typeColor(c.type),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                              _formatTime(c.createdAt)),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _statusColor(c.status)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _statusLabel(c.status),
                                              style: TextStyle(
                                                color: _statusColor(c.status),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          PopupMenuButton<String>(
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
                                                  leading: Icon(Icons.edit,
                                                      size: 20),
                                                  title: Text('编辑'),
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: ListTile(
                                                  leading: Icon(Icons.delete,
                                                      size: 20,
                                                      color: Colors.red),
                                                  title: Text('删除',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.red)),
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      onTap: () => _showChargerForm(c),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}