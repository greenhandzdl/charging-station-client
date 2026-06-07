import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';
import '../user_screens/maintainer_workspace_screen.dart';
import '../user_screens/login_screen.dart';

/// 维修工作台入口页面
///
/// 用于 admin_screens 目录下的维修工作台入口，
/// 根据当前用户角色决定跳转行为：
/// - MAINTAINER → 直接进入维修工作台
/// - ADMIN/SUPER_ADMIN → 可查看所有报修单的概览
/// - 其他 → 跳转到登录页
class RepairWorkspaceScreen extends StatelessWidget {
  const RepairWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = UserRole.fromString(auth.currentUser?.role ?? 'USER');

    if (role.isMaintainer) {
      return const MaintainerWorkspaceScreen();
    }

    if (role.isAdmin) {
      // 管理员可以查看维修工作台，但以只读模式
      return const _AdminRepairOverviewScreen();
    }

    // 普通用户无权访问，重定向到登录页
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
    return const SizedBox.shrink();
  }
}

/// 管理员的维修工作台只读概览
class _AdminRepairOverviewScreen extends StatelessWidget {
  const _AdminRepairOverviewScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('维修工作台 (只读)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const MaintainerWorkspaceScreen(),
    );
  }
}