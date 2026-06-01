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
  List<PaymentModel> _paymentHistory = [];
  bool _isLoadingArrears = false;
  bool _isLoadingHistory = false;
  bool _isPaying = false;
  String? _payingRecordId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadArrearsRecords(), _loadPaymentHistory()]);
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

  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final payments = await ApiService.getPayments();
      if (mounted) {
        setState(() => _paymentHistory = payments);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载支付记录失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('支付记录')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
            // Payment history section
            const Text('支付历史',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (_paymentHistory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('暂无支付记录',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              ..._paymentHistory.map((payment) => Card(
                    child: ListTile(
                      leading: Icon(
                        payment.status == 'SUCCESS'
                            ? Icons.check_circle
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
                      title: Text('${payment.amount} 元'),
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
          ],
        ),
      ),
    );
  }
}