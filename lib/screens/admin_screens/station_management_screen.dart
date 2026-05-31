import 'package:flutter/material.dart';
import '../../models/station_model.dart';
import '../../services/api_service.dart';

class StationManagementScreen extends StatefulWidget {
  const StationManagementScreen({super.key});

  @override
  State<StationManagementScreen> createState() =>
      _StationManagementScreenState();
}

class _StationManagementScreenState extends State<StationManagementScreen> {
  List<StationModel> _stations = [];
  bool _isLoading = false;

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

  Future<void> _saveStation(StationModel? existing, String name,
      String location, String status) async {
    final data = {
      'name': name,
      'location': location,
      'status': status,
    };
    try {
      if (existing == null) {
        await ApiService.createStation(data);
      } else {
        await ApiService.updateStation(existing.id, data);
      }
      await _loadStations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? '充电站已添加' : '充电站已更新')),
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

  Future<void> _deleteStation(StationModel station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除充电站 "${station.name}" 吗？此操作不可恢复。'),
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

  void _showStationForm(StationModel? existing) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final locationController =
        TextEditingController(text: existing?.location ?? '');
    String selectedStatus = existing?.status ?? 'active';
    final isEditing = existing != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(isEditing ? '编辑充电站' : '添加充电站'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: '位置',
                        border: OutlineInputBorder(),
                      ),
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
                            value: 'maintenance', child: Text('维护中')),
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
                    final name = nameController.text.trim();
                    final location = locationController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入名称')),
                      );
                      return;
                    }
                    if (location.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入位置')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _saveStation(existing, name, location, selectedStatus);
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

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return '启用';
      case 'inactive':
        return '停用';
      case 'maintenance':
        return '维护中';
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
      case 'maintenance':
        return Colors.orange;
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
      appBar: AppBar(title: const Text('充电站管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStationForm(null),
        tooltip: '添加充电站',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStations,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _stations.isEmpty
                ? ListView(
                    children: const [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('暂无充电站数据'),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _stations.length,
                    itemBuilder: (_, i) {
                      final s = _stations[i];
                      return Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteStation(s);
                          return false;
                        },
                        child: Card(
                          child: ListTile(
                            title: Text(s.name,
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(s.location),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    '充电桩: ${s.chargerCount}个 | ${_formatTime(s.updatedAt ?? s.createdAt)}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(s.status)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _statusLabel(s.status),
                                    style: TextStyle(
                                      color: _statusColor(s.status),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') _showStationForm(s);
                                    if (v == 'delete') _deleteStation(s);
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
                                        )),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        title: Text('删除',
                                            style: TextStyle(color: Colors.red)),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _showStationForm(s),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}