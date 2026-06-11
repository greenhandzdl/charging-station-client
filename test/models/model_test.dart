import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/models/models.dart';

void main() {
  group('UserModel', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'user1',
        'name': '测试用户',
        'phone': '13800138000',
        'plateNumber': '京A12345',
        'role': 'ADMIN',
        'balance': 200.0,
      };

      final model = UserModel.fromJson(json);
      expect(model.id, 'user1');
      expect(model.name, '测试用户');
      expect(model.phone, '13800138000');
      expect(model.plateNumber, '京A12345');
      expect(model.role, 'ADMIN');
      expect(model.balance, 200.0);
    });

    test('handles null fields gracefully', () {
      final json = <String, dynamic>{};

      final model = UserModel.fromJson(json);
      expect(model.id, '');
      expect(model.name, '');
      expect(model.phone, '');
      expect(model.plateNumber, '');
      expect(model.role, 'USER');
      expect(model.balance, 0.0);
    });

    test('handles snake_case plateNumber key', () {
      final json = {
        'plate_number': '京B67890',
      };

      final model = UserModel.fromJson(json);
      expect(model.plateNumber, '京B67890');
    });
  });

  group('StationModel', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 's1',
        'name': '朝阳充电站',
        'location': '朝阳区',
        'chargerCount': 6,
        'status': 'normal',
      };

      final model = StationModel.fromJson(json);
      expect(model.id, 's1');
      expect(model.name, '朝阳充电站');
      expect(model.location, '朝阳区');
      expect(model.chargerCount, 6);
      expect(model.status, 'normal');
    });

    test('handles null fields', () {
      final model = StationModel.fromJson({});
      expect(model.id, '');
      expect(model.name, '');
      expect(model.location, '');
      expect(model.chargerCount, 0);
      expect(model.status, 'NORMAL');
    });

    test('handles snake_case chargerCount', () {
      final json = {'charger_count': 10};
      expect(StationModel.fromJson(json).chargerCount, 10);
    });
  });

  group('ChargerModel', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'c1',
        'chargerCode': 'CC-001',
        'type': 'FAST',
        'status': 'IDLE',
        'stationName': '朝阳充电站',
        'stationId': 'station1',
        'onlineStatus': 'ONLINE',
      };

      final model = ChargerModel.fromJson(json);
      expect(model.id, 'c1');
      expect(model.chargerCode, 'CC-001');
      expect(model.type, 'FAST');
      expect(model.status, 'IDLE');
      expect(model.stationName, '朝阳充电站');
      expect(model.stationId, 'station1');
      expect(model.onlineStatus, 'ONLINE');
    });

    test('handles null fields', () {
      final model = ChargerModel.fromJson({});
      expect(model.id, '');
      expect(model.chargerCode, '');
      expect(model.type, 'SLOW');
      expect(model.status, 'IDLE');
      expect(model.stationName, isNull);
      expect(model.stationId, '');
      expect(model.onlineStatus, 'ONLINE');
    });

    test('handles snake_case keys', () {
      final json = {
        'charger_code': 'CC-002',
        'station_name': '海淀站',
        'station_id': 's2',
        'online_status': 'OFFLINE',
      };

      final model = ChargerModel.fromJson(json);
      expect(model.chargerCode, 'CC-002');
      expect(model.stationName, '海淀站');
      expect(model.stationId, 's2');
      expect(model.onlineStatus, 'OFFLINE');
    });

    test('type defaults to SLOW', () {
      expect(ChargerModel.fromJson({}).type, 'SLOW');
    });
  });

  group('ChargeRecordModel', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'r1',
        'startTime': '2026-06-01T10:00:00',
        'endTime': '2026-06-01T11:00:00',
        'energyKwh': 25.5,
        'fee': 35.0,
        'status': 'completed',
        'deductionStatus': 'paid',
        'userName': '测试用户',
        'plateNumber': '京A12345',
        'chargerCode': 'CC-001',
        'stationName': '朝阳站',
      };

      final model = ChargeRecordModel.fromJson(json);
      expect(model.id, 'r1');
      expect(model.startTime, '2026-06-01T10:00:00');
      expect(model.endTime, '2026-06-01T11:00:00');
      expect(model.energyKwh, 25.5);
      expect(model.fee, 35.0);
      expect(model.status, 'completed');
      expect(model.deductionStatus, 'paid');
      expect(model.userName, '测试用户');
      expect(model.plateNumber, '京A12345');
      expect(model.chargerCode, 'CC-001');
      expect(model.stationName, '朝阳站');
    });

    test('handles null fields', () {
      final model = ChargeRecordModel.fromJson({});
      expect(model.id, '');
      expect(model.startTime, '');
      expect(model.endTime, '');
      expect(model.energyKwh, 0.0);
      expect(model.fee, 0.0);
      expect(model.status, 'unknown');
      expect(model.deductionStatus, 'pending');
      expect(model.userName, isNull);
      expect(model.plateNumber, isNull);
      expect(model.chargerCode, isNull);
      expect(model.stationName, isNull);
    });

    test('handles snake_case keys', () {
      final json = {
        'start_time': '2026-06-01',
        'energy_kwh': 50.0,
        'deduction_status': 'pending',
        'user_name': '用户1',
        'plate_number': '京B67890',
        'charger_code': 'CC-002',
        'station_name': '海淀站',
      };

      final model = ChargeRecordModel.fromJson(json);
      expect(model.startTime, '2026-06-01');
      expect(model.energyKwh, 50.0);
      expect(model.deductionStatus, 'pending');
      expect(model.userName, '用户1');
      expect(model.plateNumber, '京B67890');
      expect(model.chargerCode, 'CC-002');
      expect(model.stationName, '海淀站');
    });
  });

  group('PaymentModel', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'pay1',
        'chargeRecordId': 'r1',
        'method': 'wechat',
        'amount': 100.0,
        'status': 'completed',
      };

      final model = PaymentModel.fromJson(json);
      expect(model.id, 'pay1');
      expect(model.chargeRecordId, 'r1');
      expect(model.method, 'wechat');
      expect(model.amount, 100.0);
      expect(model.status, 'completed');
    });

    test('handles null fields', () {
      final model = PaymentModel.fromJson({});
      expect(model.id, '');
      expect(model.chargeRecordId, '');
      expect(model.method, 'unknown');
      expect(model.amount, 0.0);
      expect(model.status, 'pending');
    });

    test('handles snake_case chargeRecordId', () {
      final json = {'charge_record_id': 'r2'};
      expect(PaymentModel.fromJson(json).chargeRecordId, 'r2');
    });
  });

  group('RepairModel', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'repair1',
        'chargerId': 'c1',
        'chargerCode': 'CC-001',
        'description': '无法充电',
        'status': 'in_progress',
        'reporterName': '测试用户',
        'reportedAt': '2026-06-01T10:00:00',
      };

      final model = RepairModel.fromJson(json);
      expect(model.id, 'repair1');
      expect(model.chargerId, 'c1');
      expect(model.chargerCode, 'CC-001');
      expect(model.description, '无法充电');
      expect(model.status, 'in_progress');
      expect(model.reporterName, '测试用户');
      expect(model.reportedAt, '2026-06-01T10:00:00');
    });

    test('handles null fields', () {
      final model = RepairModel.fromJson({});
      expect(model.id, '');
      expect(model.chargerId, '');
      expect(model.chargerCode, isNull);
      expect(model.description, '');
      expect(model.status, 'OPEN');
      expect(model.reporterName, isNull);
      expect(model.reportedAt, '');
    });

    test('handles snake_case keys', () {
      final json = {
        'charger_id': 'c2',
        'charger_code': 'CC-002',
        'reporter_name': '管理员',
        'reported_at': '2026-06-02',
      };

      final model = RepairModel.fromJson(json);
      expect(model.chargerId, 'c2');
      expect(model.chargerCode, 'CC-002');
      expect(model.reporterName, '管理员');
      expect(model.reportedAt, '2026-06-02');
    });
  });

  group('LoginResponse', () {
    test('fromJson parses all fields', () {
      final json = {
        'accessToken': 'token123',
        'refreshToken': 'refresh123',
        'user': {
          'id': 'u1',
          'name': '测试用户',
          'phone': '13800138000',
          'plateNumber': '京A12345',
          'role': 'user',
          'balance': 100.0,
        },
      };

      final response = LoginResponse.fromJson(json);
      expect(response.accessToken, 'token123');
      expect(response.refreshToken, 'refresh123');
      expect(response.user.name, '测试用户');
    });

    test('handles null fields', () {
      final response = LoginResponse.fromJson({});
      expect(response.accessToken, '');
      expect(response.refreshToken, '');
      expect(response.user.id, '');
    });

    test('handles snake_case keys', () {
      final json = {
        'access_token': 'token',
        'refresh_token': 'refresh',
      };

      final response = LoginResponse.fromJson(json);
      expect(response.accessToken, 'token');
      expect(response.refreshToken, 'refresh');
    });
  });
}