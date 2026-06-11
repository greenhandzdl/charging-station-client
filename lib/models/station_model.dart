class StationModel {
  final String id;
  final String name;
  final String location;
  final int chargerCount;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StationModel({
    required this.id,
    required this.name,
    required this.location,
    required this.chargerCount,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) {
    return StationModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      chargerCount: (json['chargerCount'] as num?)?.toInt() ??
          (json['charger_count'] as num?)?.toInt() ??
          0,
      status: json['status'] as String? ?? 'NORMAL',
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
      'name': name,
      'location': location,
      'chargerCount': chargerCount,
      'status': status,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}