import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:charging_station_client/models/models.dart';
import 'package:charging_station_client/providers/auth_provider.dart';
import 'package:charging_station_client/providers/charging_provider.dart';
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
  String status = 'active',
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
  String stationId = 'station1',
  String chargerCode = 'CC-001',
  String type = 'fast',
  String status = 'idle',
}) {
  return ChargerModel(
    id: id,
    stationId: stationId,
    chargerCode: chargerCode,
    type: type,
    status: status,
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
}) {
  return ChargeRecordModel(
    id: id,
    startTime: startTime,
    endTime: endTime,
    energyKwh: energyKwh,
    fee: fee,
    status: status,
    deductionStatus: deductionStatus,
    chargerCode: chargerCode,
    stationName: stationName,
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
}

/// Wraps a [child] widget with [MultiProvider] using the given mock providers.
/// Defaults to an unauthenticated state.
Widget wrapWithProviders({
  required Widget child,
  MockAuthProvider? authProvider,
  MockChargingProvider? chargingProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? MockAuthProvider(),
      ),
      ChangeNotifierProvider<ChargingProvider>.value(
        value: chargingProvider ?? MockChargingProvider(),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}