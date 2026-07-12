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
