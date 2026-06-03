class ChargerModel {
  final String id;
  final String stationId;
  final String chargerCode;
  final String type;
  final String status;
  final String? stationName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChargerModel({
    required this.id,
    required this.stationId,
    required this.chargerCode,
    required this.type,
    required this.status,
    this.stationName,
    this.createdAt,
    this.updatedAt,
  });

  factory ChargerModel.fromJson(Map<String, dynamic> json) {
    return ChargerModel(
      id: json['id'] as String? ?? '',
      chargerCode: json['chargerCode'] as String? ??
          json['charger_code'] as String? ??
          '',
      type: json['type'] as String? ?? 'SLOW',
      status: json['status'] as String? ?? 'IDLE',
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'chargerCode': chargerCode,
      'type': type,
      'status': status,
      if (stationName != null) 'stationName': stationName,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}