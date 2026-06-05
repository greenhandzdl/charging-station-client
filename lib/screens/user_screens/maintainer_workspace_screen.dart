import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repair_provider.dart';
import '../../models/repair_model.dart';

class MaintainerWorkspaceScreen extends StatefulWidget {
  const MaintainerWorkspaceScreen({super.key});

  @override
  State<MaintainerWorkspaceScreen> createState() =>
      _MaintainerWorkspaceScreenState();
}

class _MaintainerWorkspaceScreenState
    extends State<MaintainerWorkspaceScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RepairProvider>().fetchRepairs();
  }

  Future<void> _claimRepair(String repairId) async {
    try {
      final provider = context.read<RepairProvider>();
      final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';
      await provider.assignRepair(repairId, currentUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('接单成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('接单失败: $e')),
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
          const SnackBar(content: Text('已标记完成')),
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
    final currentUserId = auth.currentUser?.id ?? '';

    final myRepairs = provider.repairs
        .where((r) =>
            r.handledBy == currentUserId && r.status != 'CLOSED')
        .toList();
    final availableRepairs = provider.repairs
        .where((r) =>
            r.status == 'OPEN' && r.handledBy != currentUserId)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('维修工作台'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '我的任务'),
              Tab(text: '待接单'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyRepairsTab(myRepairs, currentUserId),
            _buildAvailableTab(availableRepairs, currentUserId),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRepairsTab(
      List<RepairModel> repairs, String currentUserId) {
    if (repairs.isEmpty) {
      return const Center(child: Text('暂无进行中的维修任务'));
    }
    return RefreshIndicator(
      onRefresh: () =>
          context.read<RepairProvider>().fetchRepairs(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: repairs.length,
        itemBuilder: (_, i) {
          final r = repairs[i];
          return Card(
            child: ExpansionTile(
              title: Text('${r.chargerCode ?? '未知桩'} - ${r.status}'),
              subtitle: Text(r.description),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('报修人: ${r.reporterName}'),
                      Text('时间: ${r.reportedAt}'),
                      const SizedBox(height: 8),
                      if (r.status == 'IN_PROGRESS')
                        ElevatedButton(
                          onPressed: () => _resolveRepair(r.id),
                          child: const Text('标记完成'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvailableTab(
      List<RepairModel> repairs, String currentUserId) {
    if (repairs.isEmpty) {
      return const Center(child: Text('暂无待接单的报修'));
    }
    return RefreshIndicator(
      onRefresh: () =>
          context.read<RepairProvider>().fetchRepairs(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: repairs.length,
        itemBuilder: (_, i) {
          final r = repairs[i];
          return Card(
            child: ExpansionTile(
              title: Text(r.chargerCode ?? '未知桩'),
              subtitle: Text(r.description),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('报修人: ${r.reporterName}'),
                      Text('时间: ${r.reportedAt}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _claimRepair(r.id),
                        child: const Text('接单'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}