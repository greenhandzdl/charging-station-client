import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:charging_station_client/models/models.dart';
import 'package:charging_station_client/providers/auth_provider.dart';
import 'package:charging_station_client/providers/charging_provider.dart';
import 'package:charging_station_client/providers/repair_provider.dart';
import 'package:charging_station_client/providers/statistics_provider.dart';
import 'package:charging_station_client/services/api_service.dart';

/// Creates a mock user model for testing.
UserModel createMockUser({
  String id = 'user1',
  String name = '测试用户',
  String phone = '13800138000',
  String plateNumber = '京A12345',
  String role = 'user',
  double balance = 100.0,
}) {
  return UserModel(
    id: id,
    name: name,
    phone: phone,
    plateNumber: plateNumber,
    role: role,
    balance: balance,
  );
}

/// Creates a mock station model for testing.
StationModel createMockStation({
  String id = 'station1',
  String name = '测试充电站',
  String location = '北京市朝阳区',
  int chargerCount = 4,
  String status = 'normal',
}) {
  return StationModel(
    id: id,
    name: name,
    location: location,
    chargerCount: chargerCount,
    status: status,
  );
}

/// Creates a mock charger model for testing.
ChargerModel createMockCharger({
  String id = 'charger1',
  String chargerCode = 'CC-001',
  String type = 'fast',
  String status = 'idle',
  String stationName = '测试充电站',
  String stationId = 'station1',
  String onlineStatus = 'ONLINE',
}) {
  return ChargerModel(
    id: id,
    chargerCode: chargerCode,
    type: type,
    status: status,
    stationName: stationName,
    stationId: stationId,
    onlineStatus: onlineStatus,
  );
}

/// Creates a mock charge record model for testing.
ChargeRecordModel createMockChargeRecord({
  String id = 'record1',
  String chargerCode = 'CC-001',
  String stationName = '测试充电站',
  double energyKwh = 25.5,
  double fee = 35.0,
  String status = 'processing',
  String deductionStatus = 'pending',
  String startTime = '2026-06-01 10:00:00',
  String endTime = '',
  String userName = '测试用户',
  String plateNumber = '京A12345',
}) {
  return ChargeRecordModel(
    id: id,
    startTime: startTime,
    endTime: endTime,
    energyKwh: energyKwh,
    fee: fee,
    status: status,
    deductionStatus: deductionStatus,
    userName: userName,
    plateNumber: plateNumber,
    chargerCode: chargerCode,
    stationName: stationName,
  );
}

/// Creates a mock payment model for testing.
PaymentModel createMockPayment({
  String id = 'pay1',
  String userId = 'user1',
  String chargeRecordId = 'record1',
  String method = 'wechat',
  double amount = 50.0,
  String status = 'completed',
}) {
  return PaymentModel(
    id: id,
    userId: userId,
    chargeRecordId: chargeRecordId,
    method: method,
    amount: amount,
    status: status,
  );
}

/// Creates a mock repair model for testing.
RepairModel createMockRepair({
  String id = 'repair1',
  String chargerId = 'charger1',
  String chargerCode = 'CC-001',
  String description = '充电桩故障，无法启动',
  String status = 'open',
  String reporterName = '测试用户',
  String reporterId = 'user1',
  String reportedAt = '2026-06-01T10:00:00',
}) {
  return RepairModel(
    id: id,
    chargerId: chargerId,
    chargerCode: chargerCode,
    description: description,
    status: status,
    reporterName: reporterName,
    reporterId: reporterId,
    reportedAt: reportedAt,
  );
}

/// Mock AuthProvider that does not contact any real service.
class MockAuthProvider extends AuthProvider {
  bool _isLoggedIn;
  UserModel? _user;
  bool _loginCalled = false;
  String? _lastLoginPhone;
  String? _lastLoginPassword;
  ApiException? _loginError;
  bool _registerCalled = false;

  MockAuthProvider({
    bool isLoggedIn = false,
    UserModel? user,
  })  : _isLoggedIn = isLoggedIn,
        _user = user;

  @override
  bool get isLoggedIn => _isLoggedIn;

  @override
  UserModel? get currentUser => _user;

  bool get loginCalled => _loginCalled;
  String? get lastLoginPhone => _lastLoginPhone;
  String? get lastLoginPassword => _lastLoginPassword;
  bool get registerCalled => _registerCalled;

  void setIsLoggedIn(bool value) {
    _isLoggedIn = value;
    notifyListeners();
  }

  void setCurrentUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  void setLoginError(ApiException? error) {
    _loginError = error;
  }

  @override
  Future<void> login(String phone, String password,
      {String? captchaId, String? captchaCode}) async {
    _loginCalled = true;
    _lastLoginPhone = phone;
    _lastLoginPassword = password;
    if (_loginError != null) throw _loginError!;
    _isLoggedIn = true;
    notifyListeners();
  }

  @override
  Future<void> register(
    String name,
    String phone,
    String password,
    String plateNumber, {
    required String captchaId,
    required String captchaCode,
  }) async {
    _registerCalled = true;
    if (_loginError != null) throw _loginError!;
  }

  @override
  void logout() {
    _isLoggedIn = false;
    _user = null;
    notifyListeners();
  }

  @override
  Future<bool> tryAutoLogin() async => _isLoggedIn;
}

/// Mock ChargingProvider that does not contact any real service.
class MockChargingProvider extends ChargingProvider {
  List<StationModel> _mockStations = [];
  List<ChargerModel> _mockChargers = [];
  ChargeRecordModel? _mockCurrentRecord;
  bool _fetchStationsCalled = false;
  bool _fetchChargersCalled = false;
  bool _startChargeCalled = false;
  bool _stopChargeCalled = false;
  String? _lastChargerId;
  String? _lastRecordId;
  Exception? _chargeError;

  void setStations(List<StationModel> stations) {
    _mockStations = stations;
    notifyListeners();
  }

  void setChargers(List<ChargerModel> chargers) {
    _mockChargers = chargers;
    notifyListeners();
  }

  void setCurrentRecord(ChargeRecordModel? record) {
    _mockCurrentRecord = record;
    notifyListeners();
  }

  void setChargeError(Exception? error) {
    _chargeError = error;
  }

  bool get fetchStationsCalled => _fetchStationsCalled;
  bool get fetchChargersCalled => _fetchChargersCalled;
  bool get startChargeCalled => _startChargeCalled;
  bool get stopChargeCalled => _stopChargeCalled;
  String? get lastChargerId => _lastChargerId;
  String? get lastRecordId => _lastRecordId;

  @override
  List<StationModel> get stations => _mockStations;

  @override
  List<ChargerModel> get chargers => _mockChargers;

  @override
  ChargeRecordModel? get currentRecord => _mockCurrentRecord;

  @override
  bool get isCharging => _mockCurrentRecord != null;

  @override
  Future<void> fetchStations() async {
    _fetchStationsCalled = true;
  }

  @override
  Future<void> fetchChargers(String stationId) async {
    _fetchChargersCalled = true;
  }

  @override
  Future<void> startCharge(String chargerId) async {
    _startChargeCalled = true;
    _lastChargerId = chargerId;
    if (_chargeError != null) throw _chargeError!;
  }

  @override
  Future<void> stopCharge(String recordId) async {
    _stopChargeCalled = true;
    _lastRecordId = recordId;
    if (_chargeError != null) throw _chargeError!;
  }

  @override
  Future<void> resumeFromBackend() async {
    // No-op in tests; rely on setCurrentRecord instead
  }
}

/// Mock RepairProvider that does not contact any real service.
class MockRepairProvider extends RepairProvider {
  List<RepairModel> _mockRepairs = [];
  bool _fetchRepairsCalled = false;
  bool _submitRepairCalled = false;
  bool _claimRepairCalled = false;
  bool _resolveRepairCalled = false;
  String? _lastChargerCode;
  String? _lastDescription;
  String? _lastRepairId;
  Exception? _repairError;
  Exception? _submitError;

  void setRepairs(List<RepairModel> repairs) {
    _mockRepairs = repairs;
    notifyListeners();
  }

  void setRepairError(Exception? error) {
    _repairError = error;
  }

  void setSubmitError(Exception? error) {
    _submitError = error;
  }

  bool get fetchRepairsCalled => _fetchRepairsCalled;
  bool get submitRepairCalled => _submitRepairCalled;
  bool get claimRepairCalled => _claimRepairCalled;
  bool get resolveRepairCalled => _resolveRepairCalled;
  String? get lastChargerCode => _lastChargerCode;
  String? get lastDescription => _lastDescription;
  String? get lastRepairId => _lastRepairId;

  @override
  List<RepairModel> get repairs => _mockRepairs;

  @override
  Future<void> fetchRepairs() async {
    _fetchRepairsCalled = true;
    if (_repairError != null) throw _repairError!;
  }

  @override
  Future<void> submitRepair(String chargerId, String description) async {
    _submitRepairCalled = true;
    _lastChargerCode = chargerId;
    _lastDescription = description;
    if (_submitError != null) throw _submitError!;
    if (_repairError != null) throw _repairError!;
    _mockRepairs.add(createMockRepair(
      id: 'new-repair',
      chargerCode: chargerId,
      description: description,
    ));
    notifyListeners();
  }
}

/// Mock StatisticsProvider that does not contact any real service.
class MockStatisticsProvider extends StatisticsProvider {
  List<Map<String, dynamic>> _mockChargeStats = [];
  List<Map<String, dynamic>> _mockStationAnalysis = [];
  Map<String, dynamic> _mockUtilization = {};
  List<Map<String, dynamic>> _mockFaultChargers = [];

  void setChargeStats(List<Map<String, dynamic>> stats) {
    _mockChargeStats = stats;
    notifyListeners();
  }

  void setStationAnalysis(List<Map<String, dynamic>> analysis) {
    _mockStationAnalysis = analysis;
    notifyListeners();
  }

  void setUtilization(Map<String, dynamic> utilization) {
    _mockUtilization = utilization;
    notifyListeners();
  }

  void setFaultChargers(List<Map<String, dynamic>> chargers) {
    _mockFaultChargers = chargers;
    notifyListeners();
  }

  @override
  List<Map<String, dynamic>> get chargeStats => _mockChargeStats;

  @override
  List<Map<String, dynamic>> get stationAnalysis => _mockStationAnalysis;

  @override
  Map<String, dynamic> get chargerUtilization => _mockUtilization;

  @override
  List<Map<String, dynamic>> get faultChargers => _mockFaultChargers;

  @override
  Future<void> fetchUserChargeStats() async {}

  @override
  Future<void> fetchStationAnalysis() async {}

  @override
  Future<void> fetchChargerUtilization() async {}

  @override
  Future<void> fetchFaultChargers() async {}
}

/// Wraps a [child] widget with [MultiProvider] using the given mock providers.
/// Defaults to an unauthenticated state.
Widget wrapWithProviders({
  required Widget child,
  MockAuthProvider? authProvider,
  MockChargingProvider? chargingProvider,
  MockRepairProvider? repairProvider,
  MockStatisticsProvider? statisticsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? MockAuthProvider(),
      ),
      ChangeNotifierProvider<ChargingProvider>.value(
        value: chargingProvider ?? MockChargingProvider(),
      ),
      if (repairProvider != null)
        ChangeNotifierProvider<RepairProvider>.value(value: repairProvider),
      if (statisticsProvider != null)
        ChangeNotifierProvider<StatisticsProvider>.value(
            value: statisticsProvider),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}