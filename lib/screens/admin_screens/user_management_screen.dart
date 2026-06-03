import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      _users = await ApiService.getUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户列表失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showRoleDialog(UserModel user) async {
    final roles = ['USER', 'ADMIN', 'MAINTAINER'];
    final roleLabels = {
      'USER': '普通用户',
      'ADMIN': '管理员',
      'MAINTAINER': '维护员',
    };

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改 ${user.name} 的角色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles
              .map((role) => RadioListTile<String>(
                    title: Text(roleLabels[role] ?? role),
                    value: role,
                    groupValue: user.role,
                    onChanged: (v) => Navigator.pop(ctx, v),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (confirmed == null || confirmed == user.role) return;

    try {
      await ApiService.changeRole(user.id, confirmed);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${user.name} 的角色已修改为 ${roleLabels[confirmed] ?? confirmed}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改角色失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    if (user.role == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能删除管理员')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除用户 ${user.name} (${user.phone}) 吗？此操作不可恢复。'),
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
      await ApiService.deleteUser(user.id);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户已删除')),
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

  String _roleLabel(String role) {
    switch (role) {
      case 'ADMIN':
        return '管理员';
      case 'MAINTAINER':
        return '维护员';
      case 'USER':
        return '普通用户';
      case 'SUPER_ADMIN':
        return '超级管理员';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return Colors.red;
      case 'MAINTAINER':
        return Colors.orange;
      case 'SUPER_ADMIN':
        return Colors.purple;
      case 'USER':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户管理')),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? ListView(
                    children: const [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('暂无用户数据'),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _users.length,
                    itemBuilder: (_, i) {
                      final u = _users[i];
                      return Dismissible(
                        key: ValueKey(u.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteUser(u);
                          return false;
                        },
                        child: Card(
                          child: ListTile(
                            title: Text(u.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(u.phone),
                                Text('车牌: ${u.plateNumber} | 余额: ${u.balance.toStringAsFixed(2)}元'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _roleColor(u.role)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _roleLabel(u.role),
                                    style: TextStyle(
                                      color: _roleColor(u.role),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'role') {
                                      _showRoleDialog(u);
                                    }
                                    if (v == 'delete') {
                                      _deleteUser(u);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'role',
                                      child: ListTile(
                                        leading: Icon(Icons.admin_panel_settings,
                                            size: 20),
                                        title: Text('修改角色'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        title: Text('删除',
                                            style:
                                                TextStyle(color: Colors.red)),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _showRoleDialog(u),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}