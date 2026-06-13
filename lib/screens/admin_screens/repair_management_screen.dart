import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repair_provider.dart';
import '../../models/repair_model.dart';

class RepairManagementScreen extends StatefulWidget {
  const RepairManagementScreen({super.key});

  @override
  State<RepairManagementScreen> createState() =>
      _RepairManagementScreenState();
}

class _RepairManagementScreenState extends State<RepairManagementScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<RepairProvider>().fetchRepairs();
  }

  Future<void> _handleAction(
      String repairId, RepairAction action,
      {String? reason, String? maintainerId, String? newDescription}) async {
    try {
      final provider = context.read<RepairProvider>();
      switch (action) {
        case RepairAction.assign:
          await provider.assignRepair(repairId, maintainerId ?? '');
          break;
        case RepairAction.resolve:
          await provider.resolveRepair(repairId);
          break;
        case RepairAction.close:
          await provider.closeRepair(repairId);
          break;
        case RepairAction.reject:
          if (reason != null) {
            await provider.rejectRepair(repairId, reason);
          }
          break;
        case RepairAction.softDelete:
          await provider.softDeleteRepair(repairId);
          break;
        case RepairAction.approveDelete:
          await provider.approveDeleteRepair(repairId);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RepairProvider>();
    final auth = context.watch<AuthProvider>();
    final role = auth.userRole;
    final isMaintainer = role.isMaintainer;
    final isAdmin = role.isAdmin;
    final currentUserId = auth.currentUser?.id ?? '';

    List<RepairModel> displayedRepairs = provider.repairs;
    if (isMaintainer) {
      displayedRepairs = provider.repairs
          .where((r) => r.status == 'open' || r.handledBy == currentUserId)
          .toList();
    }

    // Apply search filter
    final query = _searchQuery.toLowerCase().trim();
    if (query.isNotEmpty) {
      displayedRepairs = displayedRepairs.where((r) {
        return (r.chargerCode?.toLowerCase().contains(query) ?? false) ||
            r.description.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('报修管理')),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchRepairs(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索充电桩编号或描述',
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
              child: displayedRepairs.isEmpty
                  ? const Center(child: Text('暂无报修记录'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: displayedRepairs.length,
                      itemBuilder: (_, i) {
                        final r = displayedRepairs[i];
                        return Card(
                          child: ExpansionTile(
                            title:
                                Text('${r.chargerCode ?? "未知"} - ${r.status}'),
                            subtitle: Text(r.description),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text('报修人: ${r.reporterName ?? "未知"}'),
                                    Text('时间: ${r.reportedAt}'),
                                    const SizedBox(height: 8),
                                    if (isAdmin &&
                                        r.status == 'open') ...[
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showAssignDialog(r.id),
                                        child: const Text('分配维修人员'),
                                      ),
                                      const SizedBox(height: 4),
                                      ElevatedButton(
                                        onPressed: () => _handleAction(
                                            r.id, RepairAction.close),
                                        child: const Text('直接关闭'),
                                      ),
                                    ],
                                    if (isMaintainer &&
                                        r.status == 'open')
                                      ElevatedButton(
                                        onPressed: () => _handleAction(
                                            r.id,
                                            RepairAction.assign,
                                            maintainerId: currentUserId),
                                        child: const Text('接单'),
                                      ),
                                    if (r.status == 'in_progress' &&
                                        (isAdmin ||
                                            r.handledBy == currentUserId))
                                      ElevatedButton(
                                        onPressed: () => _handleAction(
                                            r.id, RepairAction.resolve),
                                        child: const Text('标记维修完成'),
                                      ),
                                    if (isAdmin &&
                                        r.status == 'resolved') ...[
                                      ElevatedButton(
                                        onPressed: () => _handleAction(
                                            r.id, RepairAction.close),
                                        child: const Text('审核通过 (关闭)'),
                                      ),
                                      const SizedBox(height: 4),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                        ),
                                        onPressed: () =>
                                            _showRejectDialog(r.id),
                                        child: const Text('退回'),
                                      ),
                                    ],
                                    if (isAdmin && r.status == 'deleted')
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _handleAction(r.id,
                                                RepairAction.approveDelete),
                                        child: const Text('审批删除 (永久删除)'),
                                      ),
                                    // Admin close (打回) for in_progress
                                    if (isAdmin && r.status == 'in_progress') ...[
                                      const SizedBox(height: 4),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade100,
                                          foregroundColor: Colors.red.shade800,
                                        ),
                                        onPressed: () => _handleAction(
                                            r.id, RepairAction.close),
                                        child: const Text('打回'),
                                      ),
                                    ],
                                    // Admin delete button (any non-DELETED)
                                    if (isAdmin && r.status != 'deleted') ...[
                                      const SizedBox(height: 4),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade50,
                                          foregroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _showDeleteConfirmDialog(r.id),
                                        child: const Text('删除'),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ],
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

  void _showAssignDialog(String repairId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('分配维修人员'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '维修人员ID',
            hintText: '请输入维修人员ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = controller.text.trim();
              Navigator.pop(ctx);
              if (id.isNotEmpty) {
                _handleAction(repairId, RepairAction.assign,
                    maintainerId: id);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入维修人员ID')),
                );
              }
            },
            child: const Text('确认分配'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String repairId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退回报修'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '退回原因',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleAction(repairId, RepairAction.reject,
                  reason: controller.text);
            },
            child: const Text('确认退回'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(String repairId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除此报修记录吗？将进入待审批状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handleAction(repairId, RepairAction.softDelete);
            },
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }
}

enum RepairAction { assign, resolve, close, reject, softDelete, approveDelete }