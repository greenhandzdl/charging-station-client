import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class StatisticsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _chargeStats = [];
  List<Map<String, dynamic>> _stationAnalysis = [];
  Map<String, dynamic> _chargerUtilization = {};
  List<Map<String, dynamic>> _faultChargers = [];

  bool _loadingChargeStats = false;
  bool _loadingStationAnalysis = false;
  bool _loadingUtilization = false;
  bool _loadingFaultChargers = false;

  String? _chargeStatsError;
  String? _stationAnalysisError;
  String? _utilizationError;
  String? _faultChargersError;

  List<Map<String, dynamic>> get chargeStats => _chargeStats;
  List<Map<String, dynamic>> get stationAnalysis => _stationAnalysis;
  Map<String, dynamic> get chargerUtilization => _chargerUtilization;
  List<Map<String, dynamic>> get faultChargers => _faultChargers;

  bool get loadingChargeStats => _loadingChargeStats;
  bool get loadingStationAnalysis => _loadingStationAnalysis;
  bool get loadingUtilization => _loadingUtilization;
  bool get loadingFaultChargers => _loadingFaultChargers;

  String? get chargeStatsError => _chargeStatsError;
  String? get stationAnalysisError => _stationAnalysisError;
  String? get utilizationError => _utilizationError;
  String? get faultChargersError => _faultChargersError;

  /// Parse utilization map — the backend returns a top-level map,
  /// but the current provider stores it directly from the API response.
  /// Helper getters for convenience.
  int get idleCount =>
      (_chargerUtilization['idleCount'] as num?)?.toInt() ?? 0;
  int get chargingCount =>
      (_chargerUtilization['chargingCount'] as num?)?.toInt() ?? 0;
  int get faultCount =>
      (_chargerUtilization['faultCount'] as num?)?.toInt() ?? 0;
  double get idlePercent =>
      (_chargerUtilization['idlePercent'] as num?)?.toDouble() ?? 0.0;
  double get chargingPercent =>
      (_chargerUtilization['chargingPercent'] as num?)?.toDouble() ?? 0.0;
  double get faultPercent =>
      (_chargerUtilization['faultPercent'] as num?)?.toDouble() ?? 0.0;

  Future<void> fetchUserChargeStats() async {
    _loadingChargeStats = true;
    _chargeStatsError = null;
    notifyListeners();
    try {
      _chargeStats = await ApiService.getUserChargeStats();
    } catch (e) {
      _chargeStatsError = e.toString();
    } finally {
      _loadingChargeStats = false;
      notifyListeners();
    }
  }

  Future<void> fetchStationAnalysis() async {
    _loadingStationAnalysis = true;
    _stationAnalysisError = null;
    notifyListeners();
    try {
      _stationAnalysis = await ApiService.getStationAnalysis();
    } catch (e) {
      _stationAnalysisError = e.toString();
    } finally {
      _loadingStationAnalysis = false;
      notifyListeners();
    }
  }

  Future<void> fetchChargerUtilization() async {
    _loadingUtilization = true;
    _utilizationError = null;
    notifyListeners();
    try {
      _chargerUtilization = await ApiService.getChargerUtilization();
    } catch (e) {
      _utilizationError = e.toString();
    } finally {
      _loadingUtilization = false;
      notifyListeners();
    }
  }

  Future<void> fetchFaultChargers() async {
    _loadingFaultChargers = true;
    _faultChargersError = null;
    notifyListeners();
    try {
      _faultChargers = await ApiService.getFaultChargers();
    } catch (e) {
      _faultChargersError = e.toString();
    } finally {
      _loadingFaultChargers = false;
      notifyListeners();
    }
  }
}