import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../user_screens/payment_screen.dart';
import '../user_screens/payment_entry_screen.dart';
import '../user_screens/repair_screen.dart';
import '../user_screens/charger_status_screen.dart';
import '../user_screens/login_screen.dart';
import '../user_screens/maintainer_workspace_screen.dart';
import '../admin_screens/admin_dashboard_screen.dart';
import '../../models/user_role.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _refreshBalance() async {
    await context.read<AuthProvider>().refreshBalance();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final role = UserRole.fromString(user?.role ?? 'USER');
    final isAdmin = role.isAdmin;
    final isMaintainer = role.isMaintainer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBalance,
            tooltip: '刷新余额',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBalance,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    child: Icon(Icons.person, size: 32),
                  ),
                  const SizedBox(height: 8),
                  Text(user?.name ?? '',
                      style: const TextStyle(fontSize: 18)),
                  Text(user?.phone ?? ''),
                  Text('余额: ${user?.balance ?? 0.0} 元'),
                  Text('角色: ${user?.role ?? 'user'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isAdmin)
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('管理后台'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminDashboardScreen()),
                  );
                },
              ),
            ),
          if (isMaintainer)
            Card(
              child: ListTile(
                leading: const Icon(Icons.build_circle),
                title: const Text('维修工作台'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MaintainerWorkspaceScreen()),
                  );
                },
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('充值'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('支付记录'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PaymentEntryScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.search),
              title: const Text('充电桩状态查询'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChargerStatusScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.build),
              title: const Text('报修'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RepairScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () {
                context.read<AuthProvider>().logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}