class RepairModel {
  final String id;
  final String chargerId;
  final String? chargerCode;
  final String description;
  final String status;
  final String? reporterName;
  final String reporterId;
  final String? handledBy;
  final String reportedAt;
  final String? handledAt;
  final String? rejectReason;

  RepairModel({
    required this.id,
    required this.chargerId,
    this.chargerCode,
    required this.description,
    required this.status,
    this.reporterName,
    required this.reporterId,
    this.handledBy,
    required this.reportedAt,
    this.handledAt,
    this.rejectReason,
  });

  factory RepairModel.fromJson(Map<String, dynamic> json) {
    return RepairModel(
      id: json['id'] as String? ?? '',
      chargerId: json['chargerId'] as String? ??
          json['charger_id'] as String? ??
          '',
      chargerCode: json['chargerCode'] as String? ??
          json['charger_code'] as String?,
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      reporterName: json['reporterName'] as String? ??
          json['reporter_name'] as String?,
      reporterId: json['reporterId'] as String? ??
          json['reporter_id'] as String? ??
          '',
      handledBy: json['handledBy'] as String? ??
          json['handled_by'] as String?,
      reportedAt: json['reportedAt'] as String? ??
          json['reported_at'] as String? ??
          '',
      handledAt: json['handledAt'] as String? ??
          json['handled_at'] as String?,
      rejectReason: json['rejectReason'] as String? ??
          json['reject_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chargerId': chargerId,
      if (chargerCode != null) 'chargerCode': chargerCode,
      'description': description,
      'status': status,
      if (reporterName != null) 'reporterName': reporterName,
      'reporterId': reporterId,
      if (handledBy != null) 'handledBy': handledBy,
      'reportedAt': reportedAt,
      if (handledAt != null) 'handledAt': handledAt,
      if (rejectReason != null) 'rejectReason': rejectReason,
    };
  }
}