import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:charging_station_client/services/api_service.dart';
import 'package:charging_station_client/models/models.dart';

/// Create an http.Response with UTF-8 content type for Chinese character support.
http.Response jsonResponse(dynamic body, int status) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  setUp(() {
    ApiService.setAccessToken('test-token');
  });

  tearDown(() {
    ApiService.testClient = null;
    ApiService.setAccessToken(null);
  });

  group('ApiService', () {
    group('login', () {
      test('builds correct URL and body', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.url.toString(), 'https://backend-charging-station.greenhandzdl.moe/api/v1/auth/login');
          expect(request.method, 'POST');

          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['phone'], '13800138000');
          expect(body['password'], 'password123');

          return jsonResponse({
            'accessToken': 'token123',
            'refreshToken': 'refresh123',
            'user': {
              'id': 'user1',
              'name': 'Test User',
              'phone': '13800138000',
              'plateNumber': 'ABC1234',
              'role': 'user',
              'balance': 100.0,
            },
          }, 200);
        });

        final result = await ApiService.login('13800138000', 'password123');
        expect(result.accessToken, 'token123');
        expect(result.refreshToken, 'refresh123');
        expect(result.user.name, 'Test User');
      });

      test('sends captchaId and captchaCode', () async {
        ApiService.testClient = MockClient((request) async {
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['captchaId'], 'captcha1');
          expect(body['captchaCode'], '1234');
          return jsonResponse({
            'accessToken': 'token',
            'refreshToken': 'refresh',
            'user': {
              'id': 'u1', 'name': 't', 'phone': '13800138000',
              'plateNumber': '', 'role': 'user', 'balance': 0,
            },
          }, 200);
        });

        final result = await ApiService.login('13800138000', 'password123',
            captchaId: 'captcha1', captchaCode: '1234');
        expect(result.accessToken, 'token');
      });

      test('throws ApiException on error response', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse({'error': 'invalid credentials'}, 401);
        });

        expect(
          () => ApiService.login('13800138000', 'wrong'),
          throwsA(isA<ApiException>().having(
            (e) => e.message,
            'message',
            'invalid credentials',
          )),
        );
      });
    });

    group('register', () {
      test('sends correct fields', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.url.toString(), 'https://backend-charging-station.greenhandzdl.moe/api/v1/auth/register');
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['name'], 'Test User');
          expect(body['phone'], '13800138000');
          expect(body['password'], 'password123');
          expect(body['plateNumber'], 'ABC1234');
          expect(body['captchaId'], 'captcha1');
          expect(body['captchaCode'], '1234');
          return jsonResponse({'message': 'success'}, 200);
        });

        await ApiService.register(
          'Test User',
          '13800138000',
          'password123',
          'ABC1234',
          captchaId: 'captcha1',
          captchaCode: '1234',
        );
      });
    });

    group('getChargingRecords', () {
      test('parses list response correctly', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse([
            {
              'id': 'r1',
              'startTime': '2026-06-01T10:00:00',
              'endTime': '',
              'energyKwh': 25.5,
              'fee': 35.0,
              'status': 'processing',
              'deductionStatus': 'pending',
              'userName': 'User1',
              'plateNumber': 'ABC1234',
              'chargerCode': 'CC-001',
              'stationName': 'Station A',
            },
          ], 200);
        });

        final records = await ApiService.getChargingRecords();
        expect(records.length, 1);
        expect(records.first.chargerCode, 'CC-001');
        expect(records.first.stationName, 'Station A');
        expect(records.first.energyKwh, 25.5);
      });
    });

    group('error handling', () {
      test('throws ApiException on 400 with error message', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse({'error': 'bad request'}, 400);
        });

        expect(
          () => ApiService.getStations(),
          throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'bad request',
          )),
        );
      });

      test('falls back to default message when no error body', () async {
        ApiService.testClient = MockClient((request) async {
          return http.Response('', 500);
        });

        expect(
          () => ApiService.getStations(),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('station and charger CRUD', () {
      test('getStations returns list', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse([
            {'id': 's1', 'name': 'Station1', 'location': 'Loc1', 'chargerCount': 4, 'status': 'normal'}
          ], 200);
        });

        final stations = await ApiService.getStations();
        expect(stations.length, 1);
        expect(stations.first.name, 'Station1');
      });

      test('getChargers returns list for station', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.url.toString(), contains('stationId=s1'));
          return jsonResponse([
            {'id': 'c1', 'chargerCode': 'CC-001', 'type': 'fast', 'status': 'idle', 'stationName': 'Station1'}
          ], 200);
        });

        final chargers = await ApiService.getChargers('s1');
        expect(chargers.length, 1);
        expect(chargers.first.chargerCode, 'CC-001');
      });
    });

    group('repairs', () {
      test('submitRepair sends correct data', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.url.toString(), 'https://backend-charging-station.greenhandzdl.moe/api/v1/repairs');
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['chargerId'], 'charger1');
          expect(body['description'], 'fault description');
          return jsonResponse({
            'id': 'r1', 'chargerId': 'charger1', 'chargerCode': 'CC-001',
            'description': 'fault description', 'status': 'open',
            'reporterName': 'User', 'reportedAt': '2026-06-01T10:00:00',
          }, 200);
        });

        final repair = await ApiService.submitRepair('charger1', 'fault description');
        expect(repair.id, 'r1');
        expect(repair.description, 'fault description');
      });

      test('getRepairs returns list', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse([
            {'id': 'r1', 'chargerId': 'c1', 'chargerCode': 'CC-001',
             'description': 'fault', 'status': 'open', 'reporterName': 'User',
             'reportedAt': '2026-06-01T10:00:00'}
          ], 200);
        });

        final repairs = await ApiService.getRepairs();
        expect(repairs.length, 1);
      });
    });

    group('analytics', () {
      test('getUserChargeStats returns list', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse([
            {'userName': 'User1', 'count': 5}
          ], 200);
        });

        final stats = await ApiService.getUserChargeStats();
        expect(stats.length, 1);
        expect(stats.first['userName'], 'User1');
      });

      test('getStationAnalysis returns list', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse([
            {'stationName': 'Station A', 'totalKwh': 100}
          ], 200);
        });

        final analysis = await ApiService.getStationAnalysis();
        expect(analysis.length, 1);
        expect(analysis.first['stationName'], 'Station A');
      });

      test('getChargerUtilization returns map', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse({'idle': 50, 'charging': 30, 'fault': 20}, 200);
        });

        final utilization = await ApiService.getChargerUtilization();
        expect(utilization['idle'], 50);
      });

      test('getFaultChargers returns list', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse([
            {'chargerCode': 'CC-001', 'stationName': 'Station A'}
          ], 200);
        });

        final faults = await ApiService.getFaultChargers();
        expect(faults.length, 1);
        expect(faults.first['chargerCode'], 'CC-001');
      });
    });

    group('user management', () {
      test('deleteUser sends DELETE', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.toString(), contains('user1'));
          return jsonResponse({}, 200);
        });

        await ApiService.deleteUser('user1');
      });

      test('updateUser sends PUT with data', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'PUT');
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['name'], 'New Name');
          return jsonResponse({}, 200);
        });

        await ApiService.updateUser('user1', {'name': 'New Name'});
      });
    });

    group('payments', () {
      test('recharge sends POST', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['amount'], 50.0);
          expect(body['method'], 'wechat');
          return jsonResponse({
            'id': 'pay1', 'chargeRecordId': '', 'method': 'wechat',
            'amount': 50.0, 'status': 'completed',
          }, 200);
        });

        final payment = await ApiService.recharge(50.0, 'wechat', 'key1');
        expect(payment.amount, 50.0);
        expect(payment.method, 'wechat');
      });

      test('getPayments returns list', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse([
            {'id': 'pay1', 'chargeRecordId': 'r1', 'method': 'wechat', 'amount': 50.0, 'status': 'completed'}
          ], 200);
        });

        final payments = await ApiService.getPayments();
        expect(payments.length, 1);
        expect(payments.first.amount, 50.0);
      });
    });

    group('balance', () {
      test('getBalance returns double', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse({'balance': 200.0}, 200);
        });

        final balance = await ApiService.getBalance();
        expect(balance, 200.0);
      });
    });

    group('repair actions', () {
      test('assignRepair sends PUT', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.toString(), contains('repair1/assign'));
          return jsonResponse({}, 200);
        });

        await ApiService.assignRepair('repair1', 'maintainer1');
      });

      test('resolveRepair sends PUT', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.toString(), contains('repair1/resolve'));
          return jsonResponse({}, 200);
        });

        await ApiService.resolveRepair('repair1');
      });

      test('closeRepair sends PUT', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.toString(), contains('repair1/close'));
          return jsonResponse({}, 200);
        });

        await ApiService.closeRepair('repair1');
      });

      test('rejectRepair sends PUT with reason', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'PUT');
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['reason'], 'bad repair');
          return jsonResponse({}, 200);
        });

        await ApiService.rejectRepair('repair1', 'bad repair');
      });
    });

    group('password', () {
      test('changePassword sends PUT', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.toString(), contains('/auth/password'));
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['oldPassword'], 'old');
          expect(body['newPassword'], 'new');
          return jsonResponse({}, 200);
        });

        await ApiService.changePassword('old', 'new');
      });

      test('resetPassword sends captcha fields', () async {
        ApiService.testClient = MockClient((request) async {
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['phone'], '13800138000');
          expect(body['captchaId'], 'cid');
          expect(body['captchaCode'], 'cc');
          return jsonResponse({}, 200);
        });

        await ApiService.resetPassword('13800138000', 'cid', 'cc');
      });
    });

    group('getCaptcha', () {
      test('returns captchaId and image map', () async {
        ApiService.testClient = MockClient((request) async {
          return jsonResponse({
            'captchaId': 'abc123',
            'image': 'data:image/png;base64,...',
          }, 200);
        });

        final result = await ApiService.getCaptcha();
        expect(result['captchaId'], 'abc123');
        expect(result['image'], 'data:image/png;base64,...');
      });
    });

    group('refreshToken', () {
      test('sends refresh token and returns LoginResponse', () async {
        ApiService.testClient = MockClient((request) async {
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['refreshToken'], 'old-refresh');
          return jsonResponse({
            'accessToken': 'new-token',
            'refreshToken': 'new-refresh',
            'user': {'id': 'u1', 'name': 'Test User', 'phone': '13800138000', 'plateNumber': '', 'role': 'user', 'balance': 0},
          }, 200);
        });

        final result = await ApiService.refreshToken('old-refresh');
        expect(result.accessToken, 'new-token');
        expect(result.refreshToken, 'new-refresh');
      });
    });

    group('confirmPasswordReset', () {
      test('sends all fields', () async {
        ApiService.testClient = MockClient((request) async {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body!) as Map<String, dynamic>;
          expect(body['token'], 'reset-token');
          expect(body['smsCode'], '123456');
          expect(body['newPassword'], 'newpass');
          expect(body['captchaId'], 'cid');
          expect(body['captchaCode'], 'cc');
          return jsonResponse({}, 200);
        });

        await ApiService.confirmPasswordReset(
          'reset-token', '123456', 'newpass',
          captchaId: 'cid', captchaCode: 'cc',
        );
      });
    });
  });
}