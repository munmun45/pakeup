class PartnerAccountRecord {
  const PartnerAccountRecord({
    required this.partnerId,
    required this.businessName,
    required this.ownerName,
    this.isActive = true,
    this.accountStatus = 'pending',
    this.bankAccountHolder,
    this.bankName,
    this.ifscCode,
    this.accountNumber,
    this.passbookDocUrl,
    this.kycSubmittedAt,
    this.accountUpdatedAt,
  });

  final String partnerId;
  final String businessName;
  final String ownerName;
  final bool isActive;
  final String accountStatus;
  final String? bankAccountHolder;
  final String? bankName;
  final String? ifscCode;
  final String? accountNumber;
  final String? passbookDocUrl;
  final DateTime? kycSubmittedAt;
  final DateTime? accountUpdatedAt;

  bool get hasBankDetails =>
      bankName?.trim().isNotEmpty == true &&
      ifscCode?.trim().isNotEmpty == true &&
      accountNumber?.trim().isNotEmpty == true;

  bool get hasPassbook => passbookDocUrl?.trim().isNotEmpty == true;

  bool get isComplete => hasBankDetails && hasPassbook;

  String get maskedAccount {
    final ac = accountNumber?.trim();
    if (ac == null || ac.isEmpty) return '—';
    if (ac.length <= 4) return ac;
    return '****${ac.substring(ac.length - 4)}';
  }

  factory PartnerAccountRecord.fromJson(Map<String, dynamic> json) {
    return PartnerAccountRecord(
      partnerId: json['partner_id'] as String,
      businessName: json['business_name'] as String,
      ownerName: json['owner_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      accountStatus: json['account_status'] as String? ?? 'pending',
      bankAccountHolder: json['bank_account_holder'] as String?,
      bankName: json['bank_name'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      accountNumber: json['account_number'] as String?,
      passbookDocUrl: json['passbook_doc_url'] as String?,
      kycSubmittedAt: json['kyc_submitted_at'] != null
          ? DateTime.tryParse(json['kyc_submitted_at'] as String)
          : null,
      accountUpdatedAt: json['account_updated_at'] != null
          ? DateTime.tryParse(json['account_updated_at'] as String)
          : null,
    );
  }
}

class PartnerKycRecord {
  const PartnerKycRecord({
    required this.id,
    required this.partnerId,
    this.propertyType,
    this.panNumber,
    this.aadhaarNumber,
    this.bankAccountHolder,
    this.bankName,
    this.ifscCode,
    this.accountNumber,
    this.aadhaarDocUrl,
    this.panDocUrl,
    this.agreementDocUrl,
    this.gstDocUrl,
    this.passbookDocUrl,
    this.otherDocUrl,
    this.otherDocName,
    this.submittedAt,
  });

  final String id;
  final String partnerId;
  final String? propertyType;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? bankAccountHolder;
  final String? bankName;
  final String? ifscCode;
  final String? accountNumber;
  final String? aadhaarDocUrl;
  final String? panDocUrl;
  final String? agreementDocUrl;
  final String? gstDocUrl;
  final String? passbookDocUrl;
  final String? otherDocUrl;
  final String? otherDocName;
  final DateTime? submittedAt;

  bool get hasSubmission => submittedAt != null;

  factory PartnerKycRecord.fromJson(Map<String, dynamic> json) {
    return PartnerKycRecord(
      id: json['id'] as String,
      partnerId: json['partner_id'] as String,
      propertyType: json['property_type'] as String?,
      panNumber: json['pan_number'] as String?,
      aadhaarNumber: json['aadhaar_number'] as String?,
      bankAccountHolder: json['bank_account_holder'] as String?,
      bankName: json['bank_name'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      accountNumber: json['account_number'] as String?,
      aadhaarDocUrl: json['aadhaar_doc_url'] as String?,
      panDocUrl: json['pan_doc_url'] as String?,
      agreementDocUrl: json['agreement_doc_url'] as String?,
      gstDocUrl: json['gst_doc_url'] as String?,
      passbookDocUrl: json['passbook_doc_url'] as String?,
      otherDocUrl: json['other_doc_url'] as String?,
      otherDocName: json['other_doc_name'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
    );
  }
}

class PartnerKycFormData {
  const PartnerKycFormData({
    this.propertyType,
    this.panNumber,
    this.aadhaarNumber,
    this.bankAccountHolder,
    this.bankName,
    this.ifscCode,
    this.accountNumber,
    this.aadhaarDocUrl,
    this.panDocUrl,
    this.agreementDocUrl,
    this.gstDocUrl,
    this.passbookDocUrl,
    this.otherDocUrl,
    this.otherDocName,
  });

  final String? propertyType;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? bankAccountHolder;
  final String? bankName;
  final String? ifscCode;
  final String? accountNumber;
  final String? aadhaarDocUrl;
  final String? panDocUrl;
  final String? agreementDocUrl;
  final String? gstDocUrl;
  final String? passbookDocUrl;
  final String? otherDocUrl;
  final String? otherDocName;

  Map<String, dynamic> toRpcParams({bool markSubmitted = true}) => {
        'property_type': propertyType,
        'pan_number': panNumber,
        'aadhaar_number': aadhaarNumber,
        'bank_account_holder': bankAccountHolder,
        'bank_name': bankName,
        'ifsc_code': ifscCode,
        'account_number': accountNumber,
        'aadhaar_doc_url': aadhaarDocUrl,
        'pan_doc_url': panDocUrl,
        'agreement_doc_url': agreementDocUrl,
        'gst_doc_url': gstDocUrl,
        'passbook_doc_url': passbookDocUrl,
        'other_doc_url': otherDocUrl,
        'other_doc_name': otherDocName,
        'mark_submitted': markSubmitted,
      };
}

enum KycDocType {
  aadhaar('aadhaar', 'Aadhaar'),
  pan('pan', 'PAN Card'),
  agreement('agreement', 'Agreement'),
  gst('gst', 'GST Certificate'),
  passbook('passbook', 'Bank Passbook'),
  other('other', 'Other Document');

  const KycDocType(this.key, this.label);

  final String key;
  final String label;
}
