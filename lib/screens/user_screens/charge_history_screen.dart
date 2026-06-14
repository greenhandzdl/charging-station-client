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
  
  // 搜索和筛选状态
  String _searchKeyword = '';
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minFee;
  double? _maxFee;

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
    var filtered = _records;
    
    // 状态筛选
    if (_statusFilter.isNotEmpty) {
      filtered = filtered.where((r) => r.status == _statusFilter).toList();
    }
    
    // 搜索关键词
    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase().trim();
      filtered = filtered.where((r) {
        final searchTexts = <String>[
          r.userName?.toLowerCase() ?? '',
          r.plateNumber?.toLowerCase() ?? '',
          r.chargerCode?.toLowerCase() ?? '',
          r.stationName?.toLowerCase() ?? '',
          r.status.toLowerCase(),
          r.deductionStatus.toLowerCase(),
          r.energyKwh.toString(),
          r.fee.toString(),
          r.fee.toStringAsFixed(2),
        ];
        
        // 添加日期相关搜索
        try {
          final startTime = DateTime.parse(r.startTime);
          searchTexts.addAll([
            '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}',
            '${startTime.year}/${startTime.month}/${startTime.day}',
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
          ]);
          
          if (r.endTime.isNotEmpty) {
            final endTime = DateTime.parse(r.endTime);
            searchTexts.addAll([
              '${endTime.year}-${endTime.month.toString().padLeft(2, '0')}-${endTime.day.toString().padLeft(2, '0')}',
              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
            ]);
          }
        } catch (e) {
          // 忽略日期解析错误
        }
        
        return searchTexts.any((text) => text.contains(keyword));
      }).toList();
    }
    
    // 时间范围筛选
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((r) {
        try {
          final startTime = DateTime.parse(r.startTime);
          if (_startDate != null && startTime.isBefore(_startDate!)) return false;
          if (_endDate != null && startTime.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    // 费用范围筛选
    if (_minFee != null || _maxFee != null) {
      filtered = filtered.where((r) {
        if (_minFee != null && r.fee < _minFee!) return false;
        if (_maxFee != null && r.fee > _maxFee!) return false;
        return true;
      }).toList();
    }
    
    return filtered;
  }

  /// Latest 5 records for quick view
  List<ChargeRecordModel> get _quickViewRecords {
    final completed = _records
        .where((r) => r.status.toUpperCase() == 'COMPLETED')
        .take(5)
        .toList();
    return completed;
  }

  // 显示筛选对话框
  Future<void> _showFilterDialog() async {
    var tempStartDate = _startDate;
    var tempEndDate = _endDate;
    var tempMinFee = _minFee;
    var tempMaxFee = _maxFee;
    var tempStatusFilter = _statusFilter;
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('筛选条件'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 状态筛选
                const Text('充电状态:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tempStatusFilter.isEmpty ? '' : tempStatusFilter,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('全部')),
                    DropdownMenuItem(value: 'completed', child: Text('已完成')),
                    DropdownMenuItem(value: 'processing', child: Text('充电中')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      tempStatusFilter = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // 时间范围
                const Text('时间范围:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: tempStartDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setDialogState(() {
                              tempStartDate = date;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(tempStartDate != null
                            ? '${tempStartDate!.year}-${tempStartDate!.month.toString().padLeft(2, '0')}-${tempStartDate!.day.toString().padLeft(2, '0')}'
                            : '开始日期'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('至'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: tempEndDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setDialogState(() {
                              tempEndDate = date;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(tempEndDate != null
                            ? '${tempEndDate!.year}-${tempEndDate!.month.toString().padLeft(2, '0')}-${tempEndDate!.day.toString().padLeft(2, '0')}'
                            : '结束日期'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 费用范围
                const Text('费用范围:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: tempMinFee?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: '最小费用',
                          border: OutlineInputBorder(),
                          prefixText: '¥',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          tempMinFee = value.isEmpty ? null : double.tryParse(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('至'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: tempMaxFee?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: '最大费用',
                          border: OutlineInputBorder(),
                          prefixText: '¥',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          tempMaxFee = value.isEmpty ? null : double.tryParse(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _minFee = null;
                  _maxFee = null;
                  _statusFilter = '';
                  _searchKeyword = '';
                });
                Navigator.pop(ctx);
              },
              child: const Text('清除筛选'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _startDate = tempStartDate;
                  _endDate = tempEndDate;
                  _minFee = tempMinFee;
                  _maxFee = tempMaxFee;
                  _statusFilter = tempStatusFilter;
                });
                Navigator.pop(ctx);
              },
              child: const Text('应用'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _filteredRecords;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('充电记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: '筛选',
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
                      // 搜索框
                      TextField(
                        decoration: InputDecoration(
                          hintText: '搜索用户、车牌、充电桩...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchKeyword.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() => _searchKeyword = '');
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() => _searchKeyword = value);
                        },
                      ),
                      
                      // 显示当前筛选条件
                      if (_startDate != null || _endDate != null || _minFee != null || _maxFee != null || _statusFilter.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (_statusFilter.isNotEmpty)
                                Chip(
                                  label: Text(_statusFilter == 'completed' ? '已完成' : '充电中'),
                                  onDeleted: () => setState(() => _statusFilter = ''),
                                ),
                              if (_startDate != null && _endDate != null)
                                Chip(
                                  label: Text('${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')} 至 ${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'),
                                  onDeleted: () {
                                    setState(() {
                                      _startDate = null;
                                      _endDate = null;
                                    });
                                  },
                                ),
                              if (_minFee != null || _maxFee != null)
                                Chip(
                                  label: Text('¥${_minFee ?? 0} - ¥${_maxFee ?? '∞'}'),
                                  onDeleted: () {
                                    setState(() {
                                      _minFee = null;
                                      _maxFee = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
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
                                  // 滚动到全部记录区域
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已显示最近5条完成记录，向下滚动查看全部'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
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
                      if (filteredRecords.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text('没有符合条件的记录',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        )
                      else
                        ...filteredRecords.map((record) {
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



