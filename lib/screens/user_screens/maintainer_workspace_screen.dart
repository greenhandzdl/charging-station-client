import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repair_provider.dart';
import '../../models/repair_model.dart';

/// 维修工作台 — 专为 MAINTAINER 角色设计
///
/// 功能:
/// 1. 待处理报修列表（PENDING/OPEN 状态的报修单）
/// 2. 报修详情查看
/// 3. 处理报修（确认接收 → 完成维修）
/// 4. 状态更新：PENDING → IN_PROGRESS → COMPLETED
///
/// 页面结构:
/// - AppBar: "维修工作台" + 未处理数量徽标
/// - TabBar: "待处理" / "进行中" / "已完成"
/// - 每个报修卡片显示：用户手机号、充电桩编号、问题描述、上报时间、处理按钮
/// - 空状态视图：没有报修时显示友好提示
/// - 加载状态：CircularProgressIndicator
/// - 错误状态：重试按钮
class MaintainerWorkspaceScreen extends StatefulWidget {
  const MaintainerWorkspaceScreen({super.key});

  @override
  State<MaintainerWorkspaceScreen> createState() =>
      _MaintainerWorkspaceScreenState();
}

class _MaintainerWorkspaceScreenState
    extends State<MaintainerWorkspaceScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRepairs();
  }

  Future<void> _loadRepairs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<RepairProvider>().fetchRepairs();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _claimRepair(String repairId) async {
    try {
      final provider = context.read<RepairProvider>();
      await provider.claimRepair(repairId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('接单成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('接单失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resolveRepair(String repairId) async {
    try {
      final provider = context.read<RepairProvider>();
      await provider.resolveRepair(repairId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('维修已完成，等待管理员审核'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RepairProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';
    final allRepairs = provider.repairs;

    final pendingRepairs = allRepairs
        .where((r) =>
            r.status == 'open' && (r.handledBy == null || r.handledBy!.isEmpty))
        .toList();
    final inProgressRepairs = allRepairs
        .where((r) =>
            r.status == 'in_progress' && r.handledBy == currentUserId)
        .toList();
    final completedRepairs = allRepairs
        .where((r) =>
            (r.status == 'resolved' || r.status == 'closed') &&
            r.handledBy == currentUserId)
        .toList();

    final pendingCount = pendingRepairs.length;
    final inProgressCount = inProgressRepairs.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('维修工作台'),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingCount 待处理',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadRepairs,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(pendingRepairs, inProgressRepairs, completedRepairs,
          pendingCount, inProgressCount),
    );
  }

  Widget _buildBody(
    List<RepairModel> pendingRepairs,
    List<RepairModel> inProgressRepairs,
    List<RepairModel> completedRepairs,
    int pendingCount,
    int inProgressCount,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: _loadRepairs,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('待处理'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('进行中'),
                      if (inProgressCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$inProgressCount',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: '已完成'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingTab(pendingRepairs),
            _buildInProgressTab(inProgressRepairs),
            _buildCompletedTab(completedRepairs),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab(List<RepairModel> repairs) {
    if (repairs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              '暂无待处理的报修',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '所有报修均已分配处理',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRepairs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: repairs.length,
        itemBuilder: (_, i) => _buildRepairCard(repairs[i], isPending: true),
      ),
    );
  }

  Widget _buildInProgressTab(List<RepairModel> repairs) {
    if (repairs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_return,
                size: 72, color: Colors.blue.shade300),
            const SizedBox(height: 16),
            Text(
              '暂无进行中的维修任务',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '前往"待处理"标签页接单',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRepairs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: repairs.length,
        itemBuilder: (_, i) =>
            _buildRepairCard(repairs[i], isInProgress: true),
      ),
    );
  }

  Widget _buildCompletedTab(List<RepairModel> repairs) {
    if (repairs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '暂无完成的维修记录',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRepairs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: repairs.length,
        itemBuilder: (_, i) => _buildRepairCard(repairs[i], isCompleted: true),
      ),
    );
  }

  Widget _buildRepairCard(
    RepairModel repair, {
    bool isPending = false,
    bool isInProgress = false,
    bool isCompleted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isPending
        ? Colors.orange.shade200
        : isInProgress
            ? Colors.blue.shade200
            : Colors.green.shade200;

    final statusLabel = isPending
        ? '待接单'
        : isInProgress
            ? '维修中'
            : '已完成';
    final statusColor = isPending
        ? Colors.orange
        : isInProgress
            ? Colors.blue
            : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isPending ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showRepairDetailDialog(repair),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: charger code + status badge
              Row(
                children: [
                  Icon(Icons.ev_station,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      repair.chargerCode ?? '充电桩 #${repair.chargerId.substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Description
              Text(
                repair.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              // Meta info
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    repair.reporterName ?? '用户',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatTime(repair.reportedAt),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Action button
              if (isPending || isInProgress) ...[
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showDeleteConfirmDialog(repair.id),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('删除'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    isPending
                        ? FilledButton.tonal(
                            onPressed: () => _claimRepair(repair.id),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange.shade50,
                              foregroundColor: Colors.orange.shade800,
                            ),
                            child: const Text('接单'),
                          )
                        : FilledButton.tonal(
                            onPressed: () => _showCompleteConfirmDialog(repair.id),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade800,
                            ),
                            child: const Text('标记完成'),
                          ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  void _showRepairDetailDialog(RepairModel repair) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '报修详情',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _detailRow('充电桩', repair.chargerCode ?? '未知'),
            _detailRow('报修人', repair.reporterName ?? '用户'),
            _detailRow('状态', _statusDisplayText(repair.status)),
            _detailRow('上报时间', repair.reportedAt),
            if (repair.handledAt != null)
              _detailRow('处理时间', repair.handledAt!),
            const Divider(height: 24),
            Text(
              '问题描述',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(repair.description),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(String repairId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定申请删除此报修单？\n管理员审批后将被永久删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<RepairProvider>().softDeleteRepair(repairId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已申请删除，等待管理员审批'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除申请失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  void _showCompleteConfirmDialog(String repairId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认完成维修'),
        content: const Text('标记此报修单为"维修完成"？\n管理员审核后将关闭工单并恢复充电桩。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resolveRepair(repairId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认完成'),
          ),
        ],
      ),
    );
  }

  String _statusDisplayText(String status) {
    switch (status) {
      case 'open':
        return '待处理';
      case 'in_progress':
        return '维修中';
      case 'resolved':
        return '已维修';
      case 'closed':
        return '已关闭';
      case 'rejected':
        return '已退回';
      default:
        return status;
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}