class StoreKycRecord {
  const StoreKycRecord({
    required this.id,
    required this.storeId,
    this.propertyType,
    this.panNumber,
    this.aadhaarNumber,
    this.aadhaarDocUrl,
    this.panDocUrl,
    this.agreementDocUrl,
    this.gstDocUrl,
    this.otherDocUrl,
    this.otherDocName,
    this.submittedAt,
  });

  final String id;
  final String storeId;
  final String? propertyType;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? aadhaarDocUrl;
  final String? panDocUrl;
  final String? agreementDocUrl;
  final String? gstDocUrl;
  final String? otherDocUrl;
  final String? otherDocName;
  final DateTime? submittedAt;

  String? docUrl(String key) => switch (key) {
        'aadhaar' => aadhaarDocUrl,
        'pan' => panDocUrl,
        'agreement' => agreementDocUrl,
        'gst' => gstDocUrl,
        'other' => otherDocUrl,
        _ => null,
      };

  bool hasDoc(String key) {
    final url = docUrl(key)?.trim();
    return url != null && url.isNotEmpty;
  }

  factory StoreKycRecord.fromJson(Map<String, dynamic> json) => StoreKycRecord(
        id: json['id'] as String,
        storeId: json['partner_id'] as String,
        propertyType: json['property_type'] as String?,
        panNumber: json['pan_number'] as String?,
        aadhaarNumber: json['aadhaar_number'] as String?,
        aadhaarDocUrl: json['aadhaar_doc_url'] as String?,
        panDocUrl: json['pan_doc_url'] as String?,
        agreementDocUrl: json['agreement_doc_url'] as String?,
        gstDocUrl: json['gst_doc_url'] as String?,
        otherDocUrl: json['other_doc_url'] as String?,
        otherDocName: json['other_doc_name'] as String?,
        submittedAt: json['submitted_at'] != null
            ? DateTime.tryParse(json['submitted_at'] as String)
            : null,
      );
}

class StoreKycSubmitData {
  const StoreKycSubmitData({
    this.propertyType,
    this.panNumber,
    this.aadhaarNumber,
    this.aadhaarDocUrl,
    this.panDocUrl,
    this.agreementDocUrl,
    this.gstDocUrl,
    this.otherDocUrl,
    this.otherDocName,
  });

  final String? propertyType;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? aadhaarDocUrl;
  final String? panDocUrl;
  final String? agreementDocUrl;
  final String? gstDocUrl;
  final String? otherDocUrl;
  final String? otherDocName;

  Map<String, dynamic> toRpcParams({bool markSubmitted = true}) => {
        'p_property_type': propertyType,
        'p_pan_number': panNumber,
        'p_aadhaar_number': aadhaarNumber,
        'p_aadhaar_doc_url': aadhaarDocUrl,
        'p_pan_doc_url': panDocUrl,
        'p_agreement_doc_url': agreementDocUrl,
        'p_gst_doc_url': gstDocUrl,
        'p_other_doc_url': otherDocUrl,
        'p_other_doc_name': otherDocName,
        'p_mark_submitted': markSubmitted,
      };
}

enum KycDocType {
  aadhaar('aadhaar'),
  pan('pan'),
  agreement('agreement'),
  gst('gst'),
  other('other');

  const KycDocType(this.key);
  final String key;
}
