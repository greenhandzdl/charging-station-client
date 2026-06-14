import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class PaymentEntryScreen extends StatefulWidget {
  const PaymentEntryScreen({super.key});

  @override
  State<PaymentEntryScreen> createState() => _PaymentEntryScreenState();
}

class _PaymentEntryScreenState extends State<PaymentEntryScreen> {
  List<ChargeRecordModel> _arrearsRecords = [];
  List<PaymentModel> _rechargeHistory = []; // 充值历史（微信/支付宝等）
  List<PaymentModel> _deductionHistory = []; // 扣费记录（自动扣费）
  
  // 搜索和筛选状态
  String _searchKeyword = '';
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  String _filterType = 'all'; // all, recharge, deduction
  
  bool _isLoadingArrears = false;
  bool _isLoadingRecharge = false;
  bool _isLoadingDeduction = false;
  bool _isPaying = false;
  String? _payingRecordId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadArrearsRecords(),
      _loadRechargeHistory(),
      _loadDeductionHistory(),
    ]);
  }

  Future<void> _loadArrearsRecords() async {
    setState(() => _isLoadingArrears = true);
    try {
      final allRecords = await ApiService.getChargingRecords();
      if (mounted) {
        setState(() {
          _arrearsRecords = allRecords
              .where((r) =>
                  r.status.toUpperCase() == 'COMPLETED' &&
                  r.deductionStatus.toUpperCase() == 'ARREARS')
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载欠费记录失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingArrears = false);
    }
  }

  Future<void> _loadRechargeHistory() async {
    setState(() => _isLoadingRecharge = true);
    try {
      final payments = await ApiService.getPayments();
      if (mounted) {
        setState(() => _rechargeHistory = payments);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载充值记录失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingRecharge = false);
    }
  }

  Future<void> _loadDeductionHistory() async {
    setState(() => _isLoadingDeduction = true);
    try {
      final deductions = await ApiService.getDeductions();
      if (mounted) {
        setState(() => _deductionHistory = deductions);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载扣费记录失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDeduction = false);
    }
  }

  Future<void> _showPaymentDialog(ChargeRecordModel record) async {
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择支付方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wechat, color: Colors.green),
              title: const Text('微信支付'),
              onTap: () => Navigator.pop(ctx, 'wechat'),
            ),
            ListTile(
              leading: const Icon(Icons.payments, color: Colors.blue),
              title: const Text('支付宝'),
              onTap: () => Navigator.pop(ctx, 'alipay'),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.orange),
              title: const Text('余额支付'),
              onTap: () => Navigator.pop(ctx, 'balance'),
            ),
          ],
        ),
      ),
    );

    if (method == null || !mounted) return;

    setState(() {
      _isPaying = true;
      _payingRecordId = record.id;
    });

    try {
      await ApiService.payArrears(record.id, method);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支付成功')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('支付失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() {
        _isPaying = false;
        _payingRecordId = null;
      });
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'wechat':
        return '微信支付';
      case 'alipay':
        return '支付宝';
      case 'balance':
        return '余额支付';
      case 'auto_deduct':
        return '自动扣费';
      default:
        return method;
    }
  }

  // 筛选充值记录
  List<PaymentModel> _filterRechargeHistory() {
    return _rechargeHistory.where((payment) {
      // 类型筛选
      if (_filterType == 'deduction') return false;
      
      // 搜索关键词
      if (_searchKeyword.isNotEmpty) {
        final keyword = _searchKeyword.toLowerCase().trim();
        
        // 构建可搜索的文本集合
        final searchTexts = <String>[
          payment.method.toLowerCase(),                          // 原始方法名: wechat, alipay, balance
          _methodLabel(payment.method).toLowerCase(),           // 中文标签: 微信支付, 支付宝, 余额支付
          payment.amount.toString(),                             // 金额: 100.0
          payment.amount.toStringAsFixed(2),                     // 金额格式化: 100.00
          payment.status.toLowerCase(),                          // 状态: success, failed, pending
          payment.status == 'SUCCESS' ? '成功' : 
          payment.status == 'FAILED' ? '失败' : '处理中',       // 状态中文
        ];
        
        // 添加日期相关搜索
        if (payment.createdAt != null) {
          final date = payment.createdAt!;
          searchTexts.addAll([
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',  // 2024-06-14
            '${date.year}/${date.month}/${date.day}',              // 2024/6/14
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',  // 10:30
            date.toString().substring(0, 19),                      // 2024-06-14 10:30:00
          ]);
        }
        
        // 检查是否有任何文本匹配关键词
        final isMatch = searchTexts.any((text) => text.contains(keyword));
        if (!isMatch) return false;
      }
      
      // 时间范围筛选
      if (_startDate != null && payment.createdAt != null) {
        if (payment.createdAt!.isBefore(_startDate!)) return false;
      }
      if (_endDate != null && payment.createdAt != null) {
        if (payment.createdAt!.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
      }
      
      // 金额范围筛选
      if (_minAmount != null && payment.amount < _minAmount!) return false;
      if (_maxAmount != null && payment.amount > _maxAmount!) return false;
      
      return true;
    }).toList();
  }

  // 筛选扣费记录
  List<PaymentModel> _filterDeductionHistory() {
    return _deductionHistory.where((payment) {
      // 类型筛选
      if (_filterType == 'recharge') return false;
      
      // 搜索关键词
      if (_searchKeyword.isNotEmpty) {
        final keyword = _searchKeyword.toLowerCase().trim();
        
        // 构建可搜索的文本集合
        final searchTexts = <String>[
          '自动扣费',                                              // 固定标签
          'auto_deduct',                                          // 方法名
          payment.amount.toString(),                               // 金额: 50.0
          payment.amount.toStringAsFixed(2),                       // 金额格式化: 50.00
          payment.status.toLowerCase(),                            // 状态: success, failed, pending
          payment.status == 'SUCCESS' ? '成功' : 
          payment.status == 'FAILED' ? '失败' : '处理中',         // 状态中文
        ];
        
        // 添加日期相关搜索
        if (payment.createdAt != null) {
          final date = payment.createdAt!;
          searchTexts.addAll([
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',  // 2024-06-14
            '${date.year}/${date.month}/${date.day}',              // 2024/6/14
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',  // 09:15
            date.toString().substring(0, 19),                      // 2024-06-14 09:15:00
          ]);
        }
        
        // 检查是否有任何文本匹配关键词
        final isMatch = searchTexts.any((text) => text.contains(keyword));
        if (!isMatch) return false;
      }
      
      // 时间范围筛选
      if (_startDate != null && payment.createdAt != null) {
        if (payment.createdAt!.isBefore(_startDate!)) return false;
      }
      if (_endDate != null && payment.createdAt != null) {
        if (payment.createdAt!.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
      }
      
      // 金额范围筛选
      if (_minAmount != null && payment.amount < _minAmount!) return false;
      if (_maxAmount != null && payment.amount > _maxAmount!) return false;
      
      return true;
    }).toList();
  }

  // 显示筛选对话框
  Future<void> _showFilterDialog() async {
    var tempStartDate = _startDate;
    var tempEndDate = _endDate;
    var tempMinAmount = _minAmount;
    var tempMaxAmount = _maxAmount;
    var tempFilterType = _filterType;
    
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
                // 类型筛选
                const Text('记录类型:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tempFilterType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(value: 'recharge', child: Text('充值记录')),
                    DropdownMenuItem(value: 'deduction', child: Text('扣费记录')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      tempFilterType = value ?? 'all';
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
                
                // 金额范围
                const Text('金额范围:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: tempMinAmount?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: '最小金额',
                          border: OutlineInputBorder(),
                          prefixText: '¥',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          tempMinAmount = value.isEmpty ? null : double.tryParse(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('至'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: tempMaxAmount?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: '最大金额',
                          border: OutlineInputBorder(),
                          prefixText: '¥',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          tempMaxAmount = value.isEmpty ? null : double.tryParse(value);
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
                  _minAmount = null;
                  _maxAmount = null;
                  _filterType = 'all';
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
                  _minAmount = tempMinAmount;
                  _maxAmount = tempMaxAmount;
                  _filterType = tempFilterType;
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
    final filteredRecharge = _filterRechargeHistory();
    final filteredDeduction = _filterDeductionHistory();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('支付记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: '筛选',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 搜索框
            TextField(
              decoration: InputDecoration(
                hintText: '搜索支付方式、金额...',
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
            if (_startDate != null || _endDate != null || _minAmount != null || _maxAmount != null || _filterType != 'all')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_filterType != 'all')
                      Chip(
                        label: Text(_filterType == 'recharge' ? '充值记录' : '扣费记录'),
                        onDeleted: () => setState(() => _filterType = 'all'),
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
                    if (_minAmount != null || _maxAmount != null)
                      Chip(
                        label: Text('¥${_minAmount ?? 0} - ¥${_maxAmount ?? '∞'}'),
                        onDeleted: () {
                          setState(() {
                            _minAmount = null;
                            _maxAmount = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),

            // Arrears section
            const Text('待支付欠费',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoadingArrears)
              const Center(child: CircularProgressIndicator())
            else if (_arrearsRecords.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('暂无欠费记录',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              ..._arrearsRecords.map((record) => Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber,
                          color: Colors.red, size: 32),
                      title: Text('充电桩: ${record.chargerCode ?? "未知"}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('费用: ${record.fee} 元'),
                          Text('结束时间: ${record.endTime}'),
                        ],
                      ),
                      trailing: _isPaying && _payingRecordId == record.id
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _showPaymentDialog(record),
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('支付'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                      isThreeLine: true,
                    ),
                  )),
            const SizedBox(height: 24),
            // Recharge history section (WeChat/Alipay/Balance)
            const Text('充值历史',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoadingRecharge)
              const Center(child: CircularProgressIndicator())
            else if (filteredRecharge.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('暂无充值记录',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              ...filteredRecharge.map((payment) => Card(
                    child: ListTile(
                      leading: Icon(
                        payment.status == 'SUCCESS'
                            ? Icons.add_circle
                            : payment.status == 'FAILED'
                                ? Icons.cancel
                                : Icons.pending,
                        color: payment.status == 'SUCCESS'
                            ? Colors.green
                            : payment.status == 'FAILED'
                                ? Colors.red
                                : Colors.orange,
                        size: 32,
                      ),
                      title: Text('+${payment.amount} 元'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_methodLabel(payment.method)),
                          if (payment.createdAt != null)
                            Text(
                              payment.createdAt!
                                  .toString()
                                  .substring(0, 19),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: Text(
                        payment.status == 'SUCCESS'
                            ? '成功'
                            : payment.status == 'FAILED'
                                ? '失败'
                                : '处理中',
                        style: TextStyle(
                          color: payment.status == 'SUCCESS'
                              ? Colors.green
                              : payment.status == 'FAILED'
                                  ? Colors.red
                                  : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  )),
            const SizedBox(height: 24),
            // Deduction history section (Auto-deduct)
            const Text('扣费记录',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoadingDeduction)
              const Center(child: CircularProgressIndicator())
            else if (filteredDeduction.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('暂无扣费记录',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              ...filteredDeduction.map((payment) => Card(
                    child: ListTile(
                      leading: Icon(
                        payment.status == 'SUCCESS'
                            ? Icons.remove_circle
                            : payment.status == 'FAILED'
                                ? Icons.cancel
                                : Icons.pending,
                        color: payment.status == 'SUCCESS'
                            ? Colors.blue
                            : payment.status == 'FAILED'
                                ? Colors.red
                                : Colors.orange,
                        size: 32,
                      ),
                      title: Text('-${payment.amount} 元'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('自动扣费'),
                          if (payment.createdAt != null)
                            Text(
                              payment.createdAt!
                                  .toString()
                                  .substring(0, 19),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: Text(
                        payment.status == 'SUCCESS'
                            ? '成功'
                            : payment.status == 'FAILED'
                                ? '失败'
                                : '处理中',
                        style: TextStyle(
                          color: payment.status == 'SUCCESS'
                              ? Colors.blue
                              : payment.status == 'FAILED'
                                  ? Colors.red
                                  : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}










