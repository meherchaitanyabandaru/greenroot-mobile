class QuotationDocument {
  final int docId;
  final int quotationId;
  final int version;
  final String objectKey;
  final String sha256Hash;
  final String mimeType;
  final int fileSize;
  final int? generatedBy;
  final String? generatedByName;
  final bool isCurrent;
  final DateTime createdAt;

  const QuotationDocument({
    required this.docId,
    required this.quotationId,
    required this.version,
    required this.objectKey,
    required this.sha256Hash,
    required this.mimeType,
    required this.fileSize,
    this.generatedBy,
    this.generatedByName,
    required this.isCurrent,
    required this.createdAt,
  });

  factory QuotationDocument.fromJson(Map<String, dynamic> j) =>
      QuotationDocument(
        docId: (j['doc_id'] as num).toInt(),
        quotationId: (j['quotation_id'] as num).toInt(),
        version: (j['version'] as num).toInt(),
        objectKey: j['object_key'] as String,
        sha256Hash: j['sha256_hash'] as String,
        mimeType: j['mime_type'] as String,
        fileSize: (j['file_size'] as num).toInt(),
        generatedBy: j['generated_by'] != null
            ? (j['generated_by'] as num).toInt()
            : null,
        generatedByName: j['generated_by_name'] as String?,
        isCurrent: j['is_current'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
