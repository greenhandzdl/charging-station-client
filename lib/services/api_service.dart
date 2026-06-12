import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api/v1';

  /// Test hook: set a mock HTTP client. When non-null, all HTTP calls go
  /// through this client instead of the default top-level http functions.
  static http.Client? testClient;

  static String? _accessToken;

  static void setAccessToken(String? token) {
    _accessToken = token;
  }

  static Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (withAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  /// Send an HTTP GET request, using [testClient] if set.
  static Future<http.Response> _get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    if (testClient != null) {
      return testClient!.get(url, headers: headers);
    }
    return http.get(url, headers: headers);
  }

  /// Send an HTTP POST request, using [testClient] if set.
  static Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    if (testClient != null) {
      return testClient!.post(url, headers: headers, body: body);
    }
    return http.post(url, headers: headers, body: body);
  }

  /// Send an HTTP PUT request, using [testClient] if set.
  static Future<http.Response> _put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    if (testClient != null) {
      return testClient!.put(url, headers: headers, body: body);
    }
    return http.put(url, headers: headers, body: body);
  }

  /// Send an HTTP DELETE request, using [testClient] if set.
  static Future<http.Response> _delete(
    Uri url, {
    Map<String, String>? headers,
  }) {
    if (testClient != null) {
      return testClient!.delete(url, headers: headers);
    }
    return http.delete(url, headers: headers);
  }

  /// Extract error message from backend response.
  static String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      final msg = error['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    if (error is String && error.isNotEmpty) return error;
    final msg = body['message'] as String?;
    if (msg != null && msg.isNotEmpty) return msg;
    return '请求失败 ($statusCode)';
  }

  static Future<Map<String, dynamic>> _handleResponse(
      http.Response response) async {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(body, response.statusCode),
    );
  }

  /// Helper: parse error from the response body for GET-list endpoints.
  /// Returns the parsed JSON body if successful.
  static Map<String, dynamic> _checkForError(http.Response response, String fallbackMsg) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    return {};
  }

  // ---- Auth ----
  static Future<LoginResponse> login(String phone, String password,
      {String? captchaId, String? captchaCode}) async {
    final body = <String, dynamic>{
      'phone': phone,
      'password': password,
    };
    if (captchaId != null) body['captchaId'] = captchaId;
    if (captchaCode != null) body['captchaCode'] = captchaCode;

    final response = await _post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(withAuth: false),
      body: jsonEncode(body),
    );
    final data = await _handleResponse(response);
    return LoginResponse.fromJson(data);
  }

  static Future<void> register(
    String name,
    String phone,
    String password,
    String plateNumber, {
    required String captchaId,
    required String captchaCode,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
        'plateNumber': plateNumber,
        'captchaId': captchaId,
        'captchaCode': captchaCode,
      }),
    );
    await _handleResponse(response);
  }

  static Future<LoginResponse> refreshToken(String refreshToken) async {
    final response = await _post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: _headers(withAuth: false),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final data = await _handleResponse(response);
    return LoginResponse.fromJson(data);
  }

  static Future<Map<String, String>> getCaptcha() async {
    final response = await _get(
      Uri.parse('$baseUrl/captcha'),
      headers: _headers(withAuth: false),
    );
    final data = await _handleResponse(response);
    return {
      'captchaId': data['captchaId'] as String? ?? '',
      'image': data['image'] as String? ?? '',
      'captchaCode': data['captchaCode'] as String? ?? '',
    };
  }

  // ---- Password ----
  static Future<void> changePassword(
      String oldPwd, String newPwd) async {
    final response = await _put(
      Uri.parse('$baseUrl/auth/password'),
      headers: _headers(),
      body: jsonEncode({'oldPassword': oldPwd, 'newPassword': newPwd}),
    );
    await _handleResponse(response);
  }

  static Future<void> resetPassword(
    String phone,
    String captchaId,
    String captchaCode,
  ) async {
    final response = await _post(
      Uri.parse('$baseUrl/auth/password-reset'),
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'phone': phone,
        'captchaId': captchaId,
        'captchaCode': captchaCode,
      }),
    );
    await _handleResponse(response);
  }

  static Future<void> confirmPasswordReset(
    String token,
    String smsCode,
    String newPassword, {
    required String captchaId,
    required String captchaCode,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/auth/password-reset/confirm'),
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'token': token,
        'smsCode': smsCode,
        'newPassword': newPassword,
        'captchaId': captchaId,
        'captchaCode': captchaCode,
      }),
    );
    await _handleResponse(response);
  }

  // ---- Charging ----
  static Future<ChargeRecordModel> startCharge(String chargerId) async {
    final response = await _post(
      Uri.parse('$baseUrl/charges/start'),
      headers: _headers(),
      body: jsonEncode({'chargerId': chargerId}),
    );
    final data = await _handleResponse(response);
    return ChargeRecordModel.fromJson(data);
  }

  static Future<ChargeRecordModel> stopCharge(String recordId) async {
    final response = await _post(
      Uri.parse('$baseUrl/charges/stop'),
      headers: _headers(),
      body: jsonEncode({'recordId': recordId}),
    );
    final data = await _handleResponse(response);
    return ChargeRecordModel.fromJson(data);
  }

  static Future<Map<String, dynamic>> forceStop(
      String recordId, String reason) async {
    final response = await _post(
      Uri.parse('$baseUrl/charges/$recordId/force-stop'),
      headers: _headers(),
      body: jsonEncode({'reason': reason}),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> selectCharger(
      String chargerId, String sessionId) async {
    final response = await _post(
      Uri.parse('$baseUrl/chargers/$chargerId/select'),
      headers: _headers(),
      body: jsonEncode({'sessionId': sessionId}),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getCurrentCharge() async {
    final response = await _get(
      Uri.parse('$baseUrl/charges?status=PROCESSING'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: '获取当前充电信息失败',
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    if (list.isEmpty) return {};
    return list[0] as Map<String, dynamic>;
  }

  static Future<List<ChargeRecordModel>> getChargingRecords() async {
    final response = await _get(
      Uri.parse('$baseUrl/charges'),
      headers: _headers(),
    );
    _checkForError(response, '获取充电记录失败');
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list
        .map((e) =>
            ChargeRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Stations search ----
  static Future<List<StationModel>> searchStations(String name) async {
    final response = await _get(
      Uri.parse('$baseUrl/stations/search?name=${Uri.encodeComponent(name)}'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list
        .map((e) => StationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Pay arrears ----
  static Future<void> payArrears(String recordId, String method) async {
    final response = await _post(
      Uri.parse('$baseUrl/payments/pay-arrears'),
      headers: _headers(),
      body: jsonEncode({'recordId': recordId, 'method': method}),
    );
    await _handleResponse(response);
  }

  // ---- Station CRUD ----
  static Future<Map<String, dynamic>> getChargerByCode(String code) async {
    final response = await _get(
      Uri.parse('$baseUrl/chargers/by-code/$code'),
      headers: _headers(),
    );
    return await _handleResponse(response);
  }

  static Future<List<StationModel>> getStations() async {
    final response = await _get(
      Uri.parse('$baseUrl/stations'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list
        .map((e) => StationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<StationModel> createStation(
      Map<String, dynamic> data) async {
    final response = await _post(
      Uri.parse('$baseUrl/stations'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    final result = await _handleResponse(response);
    return StationModel.fromJson(result);
  }

  static Future<StationModel> updateStation(
      String id, Map<String, dynamic> data) async {
    final response = await _put(
      Uri.parse('$baseUrl/stations/$id'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    final result = await _handleResponse(response);
    return StationModel.fromJson(result);
  }

  static Future<void> deleteStation(String id) async {
    final response = await _delete(
      Uri.parse('$baseUrl/stations/$id'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  // ---- Charger CRUD ----
  static Future<List<ChargerModel>> getChargers(String stationId) async {
    final response = await _get(
      Uri.parse('$baseUrl/chargers?stationId=$stationId'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list
        .map((e) => ChargerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ChargerModel> createCharger(
      Map<String, dynamic> data) async {
    final response = await _post(
      Uri.parse('$baseUrl/chargers'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    final result = await _handleResponse(response);
    return ChargerModel.fromJson(result);
  }

  static Future<ChargerModel> updateCharger(
      String id, Map<String, dynamic> data) async {
    final response = await _put(
      Uri.parse('$baseUrl/chargers/$id'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    final result = await _handleResponse(response);
    return ChargerModel.fromJson(result);
  }

  static Future<void> deleteCharger(String id) async {
    final response = await _delete(
      Uri.parse('$baseUrl/chargers/$id'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  // ---- Balance ----
  static Future<double> getBalance() async {
    final response = await _get(
      Uri.parse('$baseUrl/users/balance'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    return (data['balance'] as num?)?.toDouble() ?? 0.0;
  }

  // ---- Payments (Recharge) ----
  static Future<PaymentModel> recharge(
    double amount,
    String method,
    String idempotencyKey,
  ) async {
    final response = await _post(
      Uri.parse('$baseUrl/payments/recharge'),
      headers: _headers(),
      body: jsonEncode({
        'amount': amount,
        'method': method,
        'idempotencyKey': idempotencyKey,
      }),
    );
    final data = await _handleResponse(response);
    return PaymentModel.fromJson(data);
  }

  static Future<List<PaymentModel>> getPayments() async {
    final response = await _get(
      Uri.parse('$baseUrl/payments'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Repairs ----
  static Future<RepairModel> submitRepair(
      String chargerId, String description) async {
    final response = await _post(
      Uri.parse('$baseUrl/repairs'),
      headers: _headers(),
      body: jsonEncode({'chargerId': chargerId, 'description': description}),
    );
    final data = await _handleResponse(response);
    return RepairModel.fromJson(data);
  }

  static Future<List<RepairModel>> getRepairs() async {
    final response = await _get(
      Uri.parse('$baseUrl/repairs'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list
        .map((e) => RepairModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> assignRepair(
      String repairId, String maintainerId) async {
    final response = await _put(
      Uri.parse('$baseUrl/repairs/$repairId/assign'),
      headers: _headers(),
      body: jsonEncode({'handledBy': maintainerId}),
    );
    await _handleResponse(response);
  }

  static Future<void> claimRepair(String repairId) async {
    final response = await _put(
      Uri.parse('$baseUrl/repairs/$repairId/claim'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  static Future<void> resolveRepair(String repairId) async {
    final response = await _put(
      Uri.parse('$baseUrl/repairs/$repairId/resolve'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  static Future<void> closeRepair(String repairId) async {
    final response = await _put(
      Uri.parse('$baseUrl/repairs/$repairId/close'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  static Future<void> rejectRepair(
      String repairId, String reason) async {
    final response = await _put(
      Uri.parse('$baseUrl/repairs/$repairId/reject'),
      headers: _headers(),
      body: jsonEncode({'reason': reason}),
    );
    await _handleResponse(response);
  }

  // ---- Analytics ----
  static Future<List<Map<String, dynamic>>> getUserChargeStats() async {
    final response = await _get(
      Uri.parse('$baseUrl/analytics/user-charges'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getStationAnalysis() async {
    final response = await _get(
      Uri.parse('$baseUrl/analytics/stations'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getChargerUtilization() async {
    final response = await _get(
      Uri.parse('$baseUrl/analytics/utilization'),
      headers: _headers(),
    );
    return await _handleResponse(response);
  }

  static Future<List<Map<String, dynamic>>> getFaultChargers() async {
    final response = await _get(
      Uri.parse('$baseUrl/analytics/fault-chargers'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> exportCsv(
      String type, Map<String, String> params) async {
    final uri = Uri.parse('$baseUrl/analytics/export')
        .replace(queryParameters: {'type': type, ...params});
    final response = await _get(uri, headers: _headers());
    if (response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: '导出失败',
      );
    }
  }

  // ---- Payment Approval (Admin) ----
  static Future<List<PaymentModel>> getPendingPayments() async {
    final response = await _get(
      Uri.parse('$baseUrl/payments/pending'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> approvePayment(String paymentId) async {
    final response = await _put(
      Uri.parse('$baseUrl/payments/$paymentId/approve'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  static Future<void> rejectPayment(String paymentId, {String reason = '管理员拒绝'}) async {
    final response = await _put(
      Uri.parse('$baseUrl/payments/$paymentId/reject'),
      headers: _headers(),
      body: jsonEncode({'reason': reason}),
    );
    await _handleResponse(response);
  }

  // ---- User Profile (self-service) ----
  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final response = await _put(
      Uri.parse('$baseUrl/users/profile'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    await _handleResponse(response);
  }

  // ---- User Management (Admin) ----
  static Future<void> changeRole(
      String userId, String newRole) async {
    final response = await _put(
      Uri.parse('$baseUrl/users/$userId/role'),
      headers: _headers(),
      body: jsonEncode({'role': newRole}),
    );
    await _handleResponse(response);
  }

  static Future<void> deleteUser(String userId) async {
    final response = await _delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  static Future<void> updateUser(
      String userId, Map<String, dynamic> data) async {
    final response = await _put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    await _handleResponse(response);
  }

  static Future<List<UserModel>> getUsers() async {
    final response = await _get(
      Uri.parse('$baseUrl/users'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body, response.statusCode),
      );
    }
    final list = response.body.isNotEmpty
        ? jsonDecode(response.body) as List<dynamic>
        : <dynamic>[];
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}