import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/payment_model.dart';
import '../../services/api_service.dart';

class RechargeApprovalScreen extends StatefulWidget {
  const RechargeApprovalScreen({super.key});

  @override
  State<RechargeApprovalScreen> createState() => _RechargeApprovalScreenState();
}

class _RechargeApprovalScreenState extends State<RechargeApprovalScreen> {
  List<PaymentModel> _pendingPayments = [];
  bool _isLoading = true;
  Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      _pendingPayments = await ApiService.getPendingPayments();
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

  Future<void> _approve(String paymentId) async {
    setState(() => _processingIds.add(paymentId));
    try {
      await ApiService.approvePayment(paymentId);
      if (mounted) {
        context.read<AuthProvider>().refreshBalance();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('充值已批准，余额已更新'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPending();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批准失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(paymentId));
    }
  }

  Future<void> _reject(String paymentId) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拒绝理由'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: '输入拒绝原因（可选）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text('确认拒绝'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    setState(() => _processingIds.add(paymentId));
    try {
      await ApiService.rejectPayment(paymentId, reason: reason);
      if (mounted) {
        context.read<AuthProvider>().refreshBalance();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('充值已拒绝')),
        );
        _loadPending();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(paymentId));
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('充值审核')),
      body: RefreshIndicator(
        onRefresh: _loadPending,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pendingPayments.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.check_circle,
                                size: 64, color: Colors.green),
                            SizedBox(height: 16),
                            Text('暂无待审核充值',
                                style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _pendingPayments.length,
                    itemBuilder: (_, i) {
                      final p = _pendingPayments[i];
                      final isProcessing = _processingIds.contains(p.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text('${p.amount}',
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('¥${p.amount}',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        Text('用户ID: ${p.userId}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                        Text('方式: ${p.method}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  if (p.createdAt != null)
                                    Text(
                                      _formatDateTime(p.createdAt),
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _approve(p.id),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: Text(isProcessing
                                          ? '处理中...'
                                          : '批准'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _reject(p.id),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('拒绝'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}