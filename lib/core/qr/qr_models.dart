class QrInviteData {
  final String uuid;
  final String inviteType;
  final String? inviterName;
  final String? nurseryName;
  final bool isPending;

  const QrInviteData({
    required this.uuid,
    required this.inviteType,
    this.inviterName,
    this.nurseryName,
    required this.isPending,
  });
}

class QrVerifyData {
  final String authenticity;
  final String quotationCode;
  final String quotationStatus;
  final String documentIntegrity;
  final DateTime? issuedAt;
  final DateTime? validUntil;

  const QrVerifyData({
    required this.authenticity,
    required this.quotationCode,
    required this.quotationStatus,
    required this.documentIntegrity,
    this.issuedAt,
    this.validUntil,
  });
}

class OrderQrVerifyData {
  final String authenticity;
  final String orderCode;
  final String orderStatus;
  final String documentIntegrity;
  final DateTime? issuedAt;

  const OrderQrVerifyData({
    required this.authenticity,
    required this.orderCode,
    required this.orderStatus,
    required this.documentIntegrity,
    this.issuedAt,
  });
}
