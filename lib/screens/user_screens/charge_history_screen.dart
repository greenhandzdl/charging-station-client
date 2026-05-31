import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class ChargeHistoryScreen extends StatefulWidget {
  const ChargeHistoryScreen({super.key});

  @override
  State<ChargeHistoryScreen> createState() => _ChargeHistoryScreenState();
}

class _ChargeHistoryScreenState extends State<ChargeHistoryScreen> {
  List<ChargeRecordModel> _records = [];
  bool _isLoading = false;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      _records = await ApiService.getChargingRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载记录失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ChargeRecordModel> get _filteredRecords {
    if (_statusFilter.isEmpty) return _records;
    return _records.where((r) => r.status == _statusFilter).toList();
  }

  /// Latest 5 records for quick view
  List<ChargeRecordModel> get _quickViewRecords {
    final completed = _records
        .where((r) => r.status.toUpperCase() == 'COMPLETED')
        .take(5)
        .toList();
    return completed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('充电记录'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('全部')),
              const PopupMenuItem(value: 'completed', child: Text('已完成')),
              const PopupMenuItem(value: 'processing', child: Text('充电中')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecords,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
                ? const Center(child: Text('暂无充电记录'))
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      // Quick view section
                      if (_quickViewRecords.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
                          child: Row(
                            children: [
                              const Text('充电记录快捷视图',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  // Scroll to full list or navigate to full screen
                                },
                                icon: const Icon(Icons.visibility, size: 18),
                                label: const Text('最近5条'),
                              ),
                            ],
                          ),
                        ),
                        Card(
                          elevation: 2,
                          child: DataTable(
                            columnSpacing: 12,
                            headingRowHeight: 36,
                            dataRowMinHeight: 32,
                            dataRowMaxHeight: 40,
                            columns: const [
                              DataColumn(
                                  label: Text('用户姓名',
                                      style: TextStyle(fontSize: 12))),
                              DataColumn(
                                  label: Text('车牌号',
                                      style: TextStyle(fontSize: 12))),
                              DataColumn(
                                  label: Text('充电桩',
                                      style: TextStyle(fontSize: 12))),
                              DataColumn(
                                  label: Text('电量(kWh)',
                                      style: TextStyle(fontSize: 12))),
                              DataColumn(
                                  label: Text('费用(元)',
                                      style: TextStyle(fontSize: 12))),
                            ],
                            rows: _quickViewRecords.map((r) => DataRow(
                              cells: [
                                DataCell(Text(r.userName ?? '-',
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(r.plateNumber ?? '-',
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(r.chargerCode ?? '-',
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(r.energyKwh.toStringAsFixed(2),
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(r.fee.toStringAsFixed(2),
                                    style: const TextStyle(fontSize: 12))),
                              ],
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Full list header
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 4),
                        child: Text('全部记录',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      ..._filteredRecords.map((record) {
                        final stationName =
                            record.stationName ?? '未知站点';
                        final chargerCode =
                            record.chargerCode ?? '未知桩';
                        return Card(
                          child: ListTile(
                            title: Text('$stationName - $chargerCode'),
                            subtitle: Text(
                              '${record.startTime}\n'
                              '${record.energyKwh}kWh | ${record.fee}元 | ${record.status}',
                            ),
                            trailing: Text(record.deductionStatus),
                            isThreeLine: true,
                          ),
                        );
                      }),
                    ],
                  ),
      ),
    );
  }
}