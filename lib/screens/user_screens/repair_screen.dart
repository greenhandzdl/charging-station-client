import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/repair_provider.dart';
import '../../models/charger_model.dart';
import '../../services/api_service.dart';

class RepairScreen extends StatefulWidget {
  const RepairScreen({super.key});

  @override
  State<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends State<RepairScreen> {
  final _descriptionController = TextEditingController();
  List<ChargerModel> _chargers = [];
  ChargerModel? _selectedCharger;

  @override
  void initState() {
    super.initState();
    context.read<RepairProvider>().fetchRepairs();
    _loadChargers();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadChargers() async {
    try {
      // Fetch chargers across stations; for simplicity get all stations then their chargers
      final stations = await ApiService.getStations();
      final allChargers = <ChargerModel>[];
      for (final station in stations) {
        try {
          final chargers = await ApiService.getChargers(station.id);
          allChargers.addAll(chargers);
        } catch (_) {
          // skip stations that fail
        }
      }
      if (mounted) {
        setState(() => _chargers = allChargers);
      }
    } catch (_) {
      // fail silently; user will see an empty dropdown
    }
  }

  Future<void> _submitRepair() async {
    if (_selectedCharger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择充电桩')),
      );
      return;
    }
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写故障描述')),
      );
      return;
    }
    try {
      await context
          .read<RepairProvider>()
          .submitRepair(_selectedCharger!.id, description);
      _selectedCharger = null;
      _descriptionController.clear();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('报修已提交')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RepairProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('报修')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('提交报修',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ChargerModel>(
            decoration: const InputDecoration(
              labelText: '选择充电桩',
              border: OutlineInputBorder(),
            ),
            initialValue: _selectedCharger,
            items: _chargers
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.chargerCode} (${c.stationName ?? ""})'),
                    ))
                .toList(),
            onChanged: (c) => setState(() => _selectedCharger = c),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '故障描述',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitRepair,
            child: const Text('提交报修'),
          ),
          const SizedBox(height: 24),
          const Text('我的报修记录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (provider.repairs.isEmpty)
            const Center(child: Text('暂无报修记录'))
          else
            ...provider.repairs.map((r) => Card(
                  child: ListTile(
                    title: Text(r.chargerCode ?? ''),
                    subtitle: Text(
                        '${r.description}\n${r.status} | ${r.reportedAt}'),
                    isThreeLine: true,
                  ),
                )),
        ],
      ),
    );
  }
}