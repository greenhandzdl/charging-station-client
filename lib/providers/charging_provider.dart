import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ChargingProvider extends ChangeNotifier {
  List<StationModel> _stations = [];
  List<ChargerModel> _chargers = [];
  ChargeRecordModel? _currentRecord;

  Timer? _pollTimer;
  bool _isPolling = false;

  List<StationModel> get stations => _stations;
  List<ChargerModel> get chargers => _chargers;
  ChargeRecordModel? get currentRecord => _currentRecord;
  bool get isPolling => _isPolling;

  /// 开始轮询充电状态，每 5 秒查询一次当前记录
  void startPolling() {
    stopPolling(); // 确保不重复启动
    _isPolling = true;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        // 获取所有充电记录，从中找到当前记录的更新状态
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
          // 如果状态变为 COMPLETED，停止轮询
          if (updated.status == 'COMPLETED') {
            stopPolling();
          }
        }
      } catch (_) {
        // 轮询异常静默处理，避免频繁弹窗
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
      _stations = await ApiService.getStations();
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
      _currentRecord = await ApiService.startCharge(chargerId);
      notifyListeners();
      // 启动后开始轮询
      startPolling();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stopCharge(String recordId) async {
    try {
      _currentRecord = await ApiService.stopCharge(recordId);
      notifyListeners();
      // 停止后结束轮询
      stopPolling();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}