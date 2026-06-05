import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/charging_provider.dart';
import 'providers/repair_provider.dart';
import 'providers/statistics_provider.dart';
import 'screens/user_screens/login_screen.dart';
import 'screens/user_screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChargingStationApp());
}

class ChargingStationApp extends StatelessWidget {
  const ChargingStationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChargingProvider()),
        ChangeNotifierProvider(create: (_) => RepairProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
      ],
      child: MaterialApp(
        title: '充电站管理系统',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialized = false;
  bool _connectionError = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.tryAutoLogin();
    } catch (e) {
      // Detect connection-refused / network-unreachable errors
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Connection refused') ||
          msg.contains('Connection reset') ||
          msg.contains('Failed host lookup') ||
          msg.contains('HandshakeException') ||
          msg.contains('No address associated') ||
          msg.contains('HostNotFoundException') ||
          msg.contains('TimeoutException') ||
          msg.contains('ClientException')) {
        if (mounted) setState(() => _connectionError = true);
        return;
      }
      // Fall through to login screen for API errors (wrong token, etc.)
    } finally {
      if (mounted) setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connectionError) {
      return _buildConnectionErrorScreen();
    }
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final auth = context.watch<AuthProvider>();
    if (auth.isLoggedIn) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }

  Widget _buildConnectionErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              Text(
                '无法连接服务器',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '请确认后端服务已启动，\n然后点击下方按钮重试。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: () {
                  setState(() {
                    _connectionError = false;
                    _initialized = false;
                  });
                  _checkAuth();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}