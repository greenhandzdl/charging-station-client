import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// 本地充电模拟引擎 — 支持多车辆同时充电
class LocalChargeSimulation {
  final String recordId;
  final String chargerId;
  final String chargerCode;
  final String type; // FAST or SLOW
  final double ratedPowerKw;
  final DateTime startTime;

  double energyKwh = 0.0;
  double fee = 0.0;
  Duration elapsed = Duration.zero;

  LocalChargeSimulation({
    required this.recordId,
    required this.chargerId,
    required this.chargerCode,
    required this.type,
    required this.ratedPowerKw,
    required this.startTime,
  }) {
    // 初始化时根据已过时间恢复累计值
    final seconds = DateTime.now().difference(startTime).inSeconds;
    if (seconds > 0) {
      energyKwh = (ratedPowerKw / 3600.0) * seconds;
      fee = _calculateFee(energyKwh);
      elapsed = Duration(seconds: seconds);
    }
  }

  double _calculateFee(double energy) {
    final rate = type == 'FAST' ? 1.5 : 0.8;
    final hour = DateTime.now().hour;
    final multiplier = (hour >= 8 && hour < 22) ? 1.2 : 0.8;
    return energy * rate * multiplier;
  }

  void tick() {
    final secondsSinceStart = DateTime.now().difference(startTime).inSeconds;
    if (secondsSinceStart > 0) {
      energyKwh = (ratedPowerKw / 3600.0) * secondsSinceStart;
      fee = _calculateFee(energyKwh);
      elapsed = Duration(seconds: secondsSinceStart);
    }
  }

  String get durationText {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get powerText => '${(ratedPowerKw).toStringAsFixed(1)} kW';
  String get energyText => '${energyKwh.toStringAsFixed(2)} kWh';
  String get feeText => '¥ ${fee.toStringAsFixed(2)}';
}

class ChargingProvider extends ChangeNotifier {
  List<StationModel> _stations = [];
  List<ChargerModel> _chargers = [];
  ChargeRecordModel? _currentRecord;

  /// 本地实时模拟的充电记录（支持多车辆）
  List<LocalChargeSimulation> _activeSimulations = [];

  Timer? _pollTimer;
  bool _isPolling = false;

  List<StationModel> get stations => _stations;
  List<ChargerModel> get chargers => _chargers;
  ChargeRecordModel? get currentRecord => _currentRecord;
  List<LocalChargeSimulation> get activeSimulations => _activeSimulations;
  bool get isPolling => _isPolling;
  bool get isCharging => _activeSimulations.isNotEmpty;
  double get totalFee => _activeSimulations.fold(0.0, (sum, s) => sum + s.fee);
  double get totalEnergy =>
      _activeSimulations.fold(0.0, (sum, s) => sum + s.energyKwh);

  Timer? _simTickTimer;

  /// 立即清空充电桩列表（解决切换站时重复显示问题）
  void clearChargers() {
    _chargers = [];
    notifyListeners();
  }

  /// 清空所有状态（切换账号/退出登录时调用）
  void clear() {
    _currentRecord = null;
    _chargers = [];
    _stations = [];
    _activeSimulations = [];
    _offlineStopInfo = null;
    stopPolling();
    stopLocalSimulation();
    notifyListeners();
  }

  /// 启动本地实时模拟
  void startLocalSimulation(LocalChargeSimulation sim) {
    _activeSimulations.removeWhere((s) => s.chargerId == sim.chargerId);
    _activeSimulations.add(sim);
    _startSimulationTicks();
    notifyListeners();
  }

  /// 停止某条充电记录的本地模拟
  void stopLocalSimulationForRecord(String recordId) {
    _activeSimulations.removeWhere((s) => s.recordId == recordId);
    if (_activeSimulations.isEmpty) {
      stopLocalSimulation();
    }
    notifyListeners();
  }

  void _startSimulationTicks() {
    _simTickTimer?.cancel();
    _simTickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activeSimulations.isEmpty) {
        stopLocalSimulation();
        return;
      }
      for (final sim in _activeSimulations) {
        sim.tick();
      }
      notifyListeners();
    });
  }

  /// 停止所有本地模拟时钟
  void stopLocalSimulation() {
    _simTickTimer?.cancel();
    _simTickTimer = null;
  }

  /// 登录后从后端恢复活跃充电记录（调用 GET /charges/active）
  Future<void> resumeFromBackend() async {
    try {
      final result = await ApiService.getActiveCharges();
      final activeRecords = result['activeRecords'] as List<dynamic>? ?? [];
      for (final r in activeRecords) {
        if (r is Map<String, dynamic>) {
          final startTimeStr = r['startTime'] as String?;
          if (startTimeStr == null) continue;
          final sim = LocalChargeSimulation(
            recordId: r['recordId']?.toString() ?? '',
            chargerId: r['chargerId']?.toString() ?? '',
            chargerCode: r['chargerCode']?.toString() ?? '',
            type: r['type']?.toString() ?? 'FAST',
            ratedPowerKw: (r['ratedPowerKw'] as num?)?.toDouble() ?? 60.0,
            startTime: DateTime.parse(startTimeStr),
          );
          startLocalSimulation(sim);
        }
      }

      // 检查离线通知
      final offlineStopped = result['offlineStopped'] as bool? ?? false;
      if (offlineStopped) {
        _offlineStopInfo = result['offlineInfo'] as Map<String, dynamic>?;
        notifyListeners();
      }
    } catch (_) {
      // 恢复失败不阻塞 UI
    }
  }

  Map<String, dynamic>? _offlineStopInfo;

  Map<String, dynamic>? get offlineStopInfo => _offlineStopInfo;

  void clearOfflineStopInfo() {
    _offlineStopInfo = null;
    notifyListeners();
  }

  /// 开始轮询充电状态，每 5 秒查询一次当前记录
  void startPolling() {
    stopPolling();
    _isPolling = true;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final records = await ApiService.getChargingRecords();
        if (_currentRecord == null) {
          stopPolling();
          return;
        }
        final updated = records.cast<ChargeRecordModel?>().firstWhere(
              (r) => r!.id == _currentRecord!.id,
              orElse: () => null,
            );
        if (updated != null) {
          _currentRecord = updated;
          notifyListeners();
          if (updated.status == 'COMPLETED') {
            stopPolling();
          }
        }
      } catch (_) {
        // 轮询异常静默处理
      }
    });
  }

  /// 停止轮询
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
  }

  Future<void> fetchStations() async {
    try {
      final allStations = await ApiService.getStations();
      _stations =
          allStations.where((s) => s.status != 'MAINTENANCE').toList();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchChargers(String stationId) async {
    try {
      _chargers = await ApiService.getChargers(stationId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> startCharge(String chargerId) async {
    try {
      final record = await ApiService.startCharge(chargerId);
      _currentRecord = record;
      // 从已加载的充电桩列表中查找充电桩信息
      final chargerInfo = _chargers.cast<ChargerModel?>().firstWhere(
            (c) => c!.id == chargerId,
            orElse: () => null,
          );
      // 启动本地实时模拟
      final sim = LocalChargeSimulation(
        recordId: record.id,
        chargerId: chargerId,
        chargerCode: chargerInfo?.chargerCode ?? record.chargerCode ?? '',
        type: chargerInfo?.type ?? 'FAST',
        ratedPowerKw: chargerInfo?.ratedPowerKw ?? 60.0,
        startTime: DateTime.now(),
      );
      startLocalSimulation(sim);
      notifyListeners();
      startPolling();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stopCharge(String recordId) async {
    try {
      _currentRecord = await ApiService.stopCharge(recordId);
      stopLocalSimulationForRecord(recordId);
      notifyListeners();
      stopPolling();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    stopPolling();
    stopLocalSimulation();
    super.dispose();
  }
}