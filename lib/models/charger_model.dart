class ChargerModel {
  final String id;
  final String stationId;
  final String chargerCode;
  final String type;
  final String status;
  final String onlineStatus;
  final String? stationName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String deviceType;
  final double? ratedPowerKw;
  final String? manufacturer;
  final String? model;

  ChargerModel({
    required this.id,
    required this.stationId,
    required this.chargerCode,
    required this.type,
    required this.status,
    required this.onlineStatus,
    this.stationName,
    this.createdAt,
    this.updatedAt,
    this.deviceType = 'SIMULATED',
    this.ratedPowerKw,
    this.manufacturer,
    this.model,
  });

  factory ChargerModel.fromJson(Map<String, dynamic> json) {
    return ChargerModel(
      id: json['id'] as String? ?? '',
      chargerCode: json['chargerCode'] as String? ??
          json['charger_code'] as String? ??
          '',
      type: json['type'] as String? ?? 'SLOW',
      status: json['status'] as String? ?? 'IDLE',
      onlineStatus: json['onlineStatus'] as String? ??
          json['online_status'] as String? ??
          'OFFLINE',
      stationName: json['stationName'] as String? ??
          json['station_name'] as String?,
      stationId: json['stationId'] as String? ??
          json['station_id'] as String? ??
          '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      deviceType: json['deviceType'] as String? ??
          json['device_type'] as String? ??
          'SIMULATED',
      ratedPowerKw: (json['ratedPowerKw'] as num?)?.toDouble() ??
          (json['rated_power_kw'] as num?)?.toDouble(),
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'chargerCode': chargerCode,
      'type': type,
      'status': status,
      'onlineStatus': onlineStatus,
      if (stationName != null) 'stationName': stationName,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'deviceType': deviceType,
      if (ratedPowerKw != null) 'ratedPowerKw': ratedPowerKw,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
    };
  }
}