class PaymentModel {
  final String id;
  final String userId;
  final String chargeRecordId;
  final String method;
  final double amount;
  final String status;
  final String? gatewayTxId;
  final String? gatewayCallbackPayload;
  final DateTime? createdAt;

  PaymentModel({
    required this.id,
    required this.userId,
    required this.chargeRecordId,
    required this.method,
    required this.amount,
    required this.status,
    this.gatewayTxId,
    this.gatewayCallbackPayload,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      chargeRecordId: json['chargeRecordId'] as String? ??
          json['charge_record_id'] as String? ??
          '',
      userId: json['userId'] as String? ??
          json['user_id'] as String? ??
          '',
      method: json['method'] as String? ?? 'unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      gatewayTxId: json['gatewayTxId'] as String? ??
          json['gateway_tx_id'] as String?,
      gatewayCallbackPayload: json['gatewayCallbackPayload'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'chargeRecordId': chargeRecordId,
      'method': method,
      'amount': amount,
      'status': status,
      if (gatewayTxId != null) 'gatewayTxId': gatewayTxId,
      if (gatewayCallbackPayload != null) 'gatewayCallbackPayload': gatewayCallbackPayload,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}