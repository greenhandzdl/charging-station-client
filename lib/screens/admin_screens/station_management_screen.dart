import 'package:flutter/material.dart';
import '../../models/station_model.dart';
import '../../services/api_service.dart';

class StationManagementScreen extends StatefulWidget {
  const StationManagementScreen({super.key});

  @override
  State<StationManagementScreen> createState() =>
      _StationManagementScreenState();
}

class _StationManagementScreenState extends State<StationManagementScreen> {
  List<StationModel> _stations = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    try {
      _stations = await ApiService.getStations();
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

  List<StationModel> get _filteredStations {
    if (_searchQuery.isEmpty) return _stations;
    return _stations
        .where((s) => s.name.contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('充电站管理')),
      body: RefreshIndicator(
        onRefresh: _loadStations,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '搜索充电站名称',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredStations.length,
                      itemBuilder: (_, i) {
                        final s = _filteredStations[i];
                        return Card(
                          child: ListTile(
                            title: Text(s.name),
                            subtitle: Text(
                                '${s.location} | ${s.chargerCount}个桩 | ${s.status}'),
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
}